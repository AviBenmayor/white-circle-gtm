"""whitecircle CLI: load -> build -> dq -> segments -> top50."""
from __future__ import annotations

import duckdb
import typer
from dotenv import load_dotenv

from .obs import record_api_call, track_run
from .paths import DB, HC_SEED, RAW, REVIEW_SEED, ROOT, SQL_DIR, TOP50_CSV, VERIFY

load_dotenv(ROOT / ".env")
app = typer.Typer(add_completion=False, help="White Circle GTM take-home pipeline.")

# Every column is read as VARCHAR on purpose: raw is a faithful copy and nothing
# is silently coerced. Typing happens in staging with try_cast, where failures
# are visible and counted.
TABLES = ["organizations", "funding_rounds", "contacts"]


@app.command()
def load() -> None:
    """Load data/raw/*.csv into raw.* (all VARCHAR, blanks kept as NULL)."""
    with track_run("load") as run:
        DB.parent.mkdir(parents=True, exist_ok=True)
        con = duckdb.connect(str(DB))
        try:
            con.execute("CREATE SCHEMA IF NOT EXISTS raw")
            for t in TABLES:
                src = RAW / f"{t}.csv"
                con.execute(
                    f"CREATE OR REPLACE TABLE raw.{t} AS SELECT * FROM read_csv("
                    f"'{src}', all_varchar=true, header=true, sample_size=-1)")
                n = con.execute(f"SELECT count(*) FROM raw.{t}").fetchone()[0]
                run.add_rows(n)
                typer.echo(f"raw.{t}: {n:,} rows")
        finally:
            con.close()


@app.command()
def build() -> None:
    """Run src/white_circle/sql/*.sql in numeric order (stg.*, mart.*, dq.*)."""
    with track_run("build") as run:
        con = duckdb.connect(str(DB))
        try:
            for f in sorted(SQL_DIR.glob("*.sql")):
                text = f.read_text()
                # '-- @requires-seed' / '-- @requires-hc-seed' split a file in two: the part after
                # the marker runs only when that committed seed exists (see 52_ and 56_).
                marker, seed, key = (("-- @requires-hc-seed\n", HC_SEED, "{{hc_seed}}")
                                     if "-- @requires-hc-seed\n" in text
                                     else ("-- @requires-seed\n", REVIEW_SEED, "{{review_seed}}"))
                head, _, tail = text.partition(marker)
                con.execute(head)
                if tail:
                    if seed.exists():
                        con.execute(tail.replace(key, str(seed)))
                    else:
                        typer.echo(f"  (no {seed.name}: table left empty)")
                typer.echo(f"ran {f.name}")
            for sch in ("stg", "mart", "dq"):
                for (t,) in con.execute(
                        "SELECT table_name FROM information_schema.tables WHERE table_schema=? "
                        "AND table_type='BASE TABLE' ORDER BY 1", [sch]).fetchall():
                    n = con.execute(f"SELECT count(*) FROM {sch}.{t}").fetchone()[0]
                    run.add_rows(n)
                    typer.echo(f"  {sch}.{t}: {n:,}")
        finally:
            con.close()


REVIEW_COLS = ["org_uuid", "organization_name", "url_checked", "page_ok", "ships_customer_facing_llm",
               "llm_use", "is_agentic", "true_vertical", "is_regulated", "customer_type",
               "evidence_quote", "source_url", "confidence", "notes"]


@app.command("merge-reviews")
def merge_reviews() -> None:
    """Merge data/verify/review_part*.csv into the committed seed, and load the Tavily call logs into ops.api_call."""
    import csv
    import json
    from datetime import datetime

    import duckdb as _duck

    with track_run("merge-reviews") as run:
        parts = sorted(VERIFY.glob("review_part*.csv"))
        if not parts:
            raise typer.BadParameter(f"no review_part*.csv in {VERIFY}")
        rows: dict[str, dict] = {}
        n_in = 0
        for p in parts:
            with p.open(newline="", encoding="utf-8") as f:
                rd = csv.DictReader(f)
                missing = [c for c in REVIEW_COLS if c not in (rd.fieldnames or [])]
                if missing:
                    raise typer.BadParameter(f"{p.name} is missing columns {missing}")
                for r in rd:
                    n_in += 1
                    rows[r["org_uuid"].strip()] = {c: (r.get(c) or "").strip() for c in REVIEW_COLS}
        REVIEW_SEED.parent.mkdir(parents=True, exist_ok=True)
        with REVIEW_SEED.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=REVIEW_COLS, lineterminator="\n")
            w.writeheader()
            w.writerows(sorted(rows.values(), key=lambda r: (r["organization_name"].lower(), r["org_uuid"])))
        run.add_rows(len(rows))
        typer.echo(f"{len(parts)} parts, {n_in} rows -> {len(rows)} unique orgs -> {REVIEW_SEED}")
        for col, ok in (("ships_customer_facing_llm", {"yes", "no", "unclear"}),
                        ("confidence", {"high", "medium", "low"})):
            bad = sorted({r[col] for r in rows.values() if r[col].lower() not in ok})
            if bad:
                typer.echo(f"WARN {col}: unexpected values {bad}")

        # Tavily call logs -> ops.api_call. Exact duplicate lines (a script re-ran) are dropped.
        seen: set[str] = set()
        dup = already = loaded = est_n = 0
        credits = 0.0
        con = _duck.connect(str(DB))
        try:
            con.execute("CREATE SCHEMA IF NOT EXISTS ops")
            have = {r[0] for r in con.execute(
                "SELECT response_ref FROM ops.api_call WHERE response_ref LIKE 'verify:%'").fetchall()} \
                if con.execute("SELECT count(*) FROM information_schema.tables WHERE table_schema='ops' "
                               "AND table_name='api_call'").fetchone()[0] else set()
        finally:
            con.close()
        for p in sorted(VERIFY.glob("tavily_calls_part*.jsonl")):
            for line in p.read_text().splitlines():
                if not line.strip():
                    continue
                if line in seen:
                    dup += 1
                    continue
                seen.add(line)
                c = json.loads(line)
                ref = f"verify:{c.get('batch')}:{c.get('ts')}"
                if ref in have:
                    already += 1
                    continue
                ts = datetime.fromisoformat(c["ts"]).replace(tzinfo=None) if c.get("ts") else None
                cr = c.get("credits")
                est = cr is None and c.get("endpoint") == "search"
                if est:
                    cr = 1  # a basic Tavily search costs 1 credit; the early logs left it blank
                    est_n += 1
                summ = (f"{c.get('request_summary')} [{c.get('batch')}; n_results={c.get('n_results')}, "
                        f"n_failed={c.get('n_failed')}; made via the Tavily MCP connector in-session]"
                        + (" (credits estimated)" if est else ""))
                record_api_call(run.run_id, c.get("provider") or "tavily", c.get("endpoint") or "", summ,
                                200 if c.get("status") == "ok" else None, None,
                                cr, None, ref, ts)
                credits += cr or 0
                loaded += 1
        typer.echo(f"api calls: loaded {loaded} ({credits:g} credits, {est_n} search calls estimated at 1 each), dropped {dup} exact duplicate lines, "
                   f"skipped {already} already loaded")
        run.add_rows(loaded)


@app.command()
def dq() -> None:
    """Print the data-quality checks (dq.checks) and the score sanity checks (dq.score_checks)."""
    with track_run("dq"):
        con = duckdb.connect(str(DB), read_only=True)
        try:
            rows = con.execute(
                "SELECT check_name, rows_affected, action_taken, description FROM ("
                "SELECT * FROM dq.checks UNION ALL SELECT * FROM dq.score_checks) ORDER BY ord").fetchall()
        finally:
            con.close()
        w = max(len(r[0]) for r in rows)
        typer.echo(f"{'check':<{w}}  {'rows':>6}  action / description")
        for name, n, action, desc in rows:
            typer.echo(f"{name:<{w}}  {n:>6,}  {action}")
            typer.echo(f"{'':<{w}}  {'':>6}    ({desc})")


@app.command()
def segments() -> None:
    """Print the segment x tier count matrix (mart.org_segment)."""
    with track_run("segments"):
        con = duckdb.connect(str(DB), read_only=True)
        try:
            tiers = ["Tier 1", "Tier 2", "Tier 3", "Nurture"]
            rows = con.execute(
                "SELECT g.segment, coalesce(g.tier, '-') AS tier, count(*) FROM mart.org_segment g "
                "GROUP BY 1, 2").fetchall()
            cuts = con.execute("SELECT tier, min_score FROM mart.tier_cutoff ORDER BY ord").fetchall()
        finally:
            con.close()
        cells = {(s, t): n for s, t, n in rows}
        order = ["Regulated GenAI", "AI-native builders", "Marketed verticals", "Enterprise", "Competitor",
                 "Out: is_closed", "Out: is_acquired", "Out: is_nonprofit", "Out: is_services_firm",
                 "Out: dead_or_hijacked_site", "Out: not_ai", "Out: industry_not_matched"]
        w = max(len(s) for s in order)
        typer.echo("tier cutoffs (total >=): " + ", ".join(f"{t} {m}" for t, m in cuts))
        typer.echo(f"{'segment':<{w}}" + "".join(f"{t:>9}" for t in tiers) + f"{'n/a':>9}{'total':>9}")
        tot = {t: 0 for t in tiers + ["-"]}
        for s in order:
            vals = [cells.get((s, t), 0) for t in tiers + ["-"]]
            for t, v in zip(tiers + ["-"], vals):
                tot[t] += v
            typer.echo(f"{s:<{w}}" + "".join(f"{v:>9,}" for v in vals) + f"{sum(vals):>9,}")
        vals = [tot[t] for t in tiers + ["-"]]
        typer.echo(f"{'TOTAL':<{w}}" + "".join(f"{v:>9,}" for v in vals) + f"{sum(vals):>9,}")


@app.command()
def top50() -> None:
    """Print the ranked top-50 AE list and write docs/part1-segmentation/top50.csv."""
    with track_run("top50") as run:
        con = duckdb.connect(str(DB), read_only=True)
        try:
            out = TOP50_CSV
            out.parent.mkdir(parents=True, exist_ok=True)
            con.execute(
                "COPY (SELECT rank, name, domain, country, segment, tier, total, rubric_total, "
                "pts_recency AS funding_recency_pts, pts_revenue AS revenue_pts, pts_headcount AS headcount_pts, "
                "pts_bonus AS fit_bonus_pts, "
                "region_bucket, round(data_confidence, 2) AS data_confidence, reason_1, reason_2, reason_3, "
                "llm_level_source, verified_llm_use, evidence_quote, "
                "best_contact_name, best_contact_title FROM mart.top50 ORDER BY rank) "
                f"TO '{out}' (HEADER, DELIMITER ',')")
            rows = con.execute(
                "SELECT rank, name, country, segment, tier, total, reason_1 "
                "FROM mart.top50 ORDER BY rank").fetchall()
        finally:
            con.close()
        run.add_rows(len(rows))
        for r, name, country, seg, tier, score, r1 in rows:
            typer.echo(f"{r:>2}. {name[:34]:<34} {country or '?':<14} {seg:<22} {tier:<7} {score:>3}  {r1}")
        typer.echo(f"wrote {out}")


@app.command("export-traces")
def export_traces(
    session: list[str] = typer.Option(None, help="Claude Code session id; repeatable (default: the take-home sessions)."),
) -> None:
    """Export the redacted AI traces to docs/traces/ (re-runnable; overwrites)."""
    from . import traces
    with track_run("export-traces", {"sessions": session or traces.DEFAULT_SESSIONS}) as run:
        res = traces.export(session or None)
        run.add_rows(res["events"])
        typer.echo(f"wrote docs/traces/ ({res['files']} files, {res['events']} events); "
                   f"entries kept {res['kept']}, redacted {res['redacted']}, dropped {res['dropped']}")
        typer.echo(f"report: {traces.REPORT.relative_to(traces.ROOT)}")
        if res["hits"]:
            for h in res["hits"][:20]:
                typer.echo(f"LEAK {h}")
            raise typer.Exit(1)
        typer.echo("final scan: 0 hits")


FUNNEL_LABELS = {  # memo funnel row label -> mart.gate_funnel.gate
    "Closed": "is_closed", "Acquired": "is_acquired", "Non-profit": "is_nonprofit",
    "Public (kept as an Enterprise segment)": "is_public", "Competitor": "is_competitor",
    "Services firm": "is_services_firm", "Dead or hijacked site": "dead_or_hijacked_site",
    "No language-AI product": "not_ai", "Industry not matched": "industry_not_matched"}


@app.command("check-docs")
def check_docs() -> None:
    """Fail if memo.md / approach-evolution.md disagree with the warehouse (pass, Tier 1, verified, funnel rows)."""
    import re

    from .paths import EVOLUTION_MD, SEGMENTATION

    with track_run("check-docs"):
        con = duckdb.connect(str(DB), read_only=True)
        try:
            n_pass = con.execute("SELECT count(*) FROM mart.org_segment WHERE passes_all").fetchone()[0]
            n_t1 = con.execute("SELECT count(*) FROM mart.org_segment WHERE tier='Tier 1'").fetchone()[0]
            n_ver = con.execute("SELECT count(*) FROM mart.org_score WHERE has_verified_review "
                                "AND verified_ships_llm='yes'").fetchone()[0]
            removed = dict(con.execute("SELECT gate, removed_here FROM mart.gate_funnel WHERE step > 0").fetchall())
        finally:
            con.close()
        memo = (SEGMENTATION / "memo.md").read_text()
        evo = EVOLUTION_MD.read_text()
        want = [(memo, f"{n_pass:,} are real candidates and {n_t1:,} are Tier 1"),
                (memo, f"| **Pass** | **{n_pass:,}** |"),
                (memo, f"Only {n_ver:,} of the {n_pass:,} are verified"),
                (evo, f"{n_pass:,} of 3,000 companies")]
        want += [(memo, f"| {label} | {removed[g]:,} |") for label, g in FUNNEL_LABELS.items()]
        bad = [t for doc, t in want if t not in doc]
        for t in bad:
            typer.echo(f"DRIFT: docs do not contain {t!r}")
        if bad:
            raise typer.Exit(1)
        typer.echo(f"docs match the warehouse: pass {n_pass}, tier1 {n_t1}, verified {n_ver}, {len(removed)} funnel rows")


@app.command()
def dashboard() -> None:
    """Render the analytics dashboard to docs/dashboard/index.html."""
    from . import dashboard as dash
    with track_run("dashboard") as run:
        out = dash.render()
        run.add_rows(1)
        typer.echo(f"wrote {out} ({out.stat().st_size / 1024:.0f} KB)")


@app.command("enrich-headcount")
def enrich_headcount(
    dry_run: bool = typer.Option(True, "--dry-run/--no-dry-run", help="Print the plan and request count; call nothing (default ON)."),
    limit: int = typer.Option(None, help="Maximum number of orgs to fetch."),
    max_credits: int = typer.Option(25, help="Hard credit cap, enforced before every request (1 credit per match assumed)."),
) -> None:
    """Fetch headcount history from People Data Labs for gate-passers (resumable). Needs PDL_API_KEY unless --dry-run."""
    from . import enrich_pdl
    enrich_pdl.enrich(limit=limit, max_credits=max_credits, dry_run=dry_run)


@app.command("enrich-headcount-apollo")
def enrich_headcount_apollo(
    dry_run: bool = typer.Option(True, "--dry-run/--no-dry-run", help="Print the plan and request count; call nothing (default ON)."),
    limit: int = typer.Option(None, help="Maximum number of orgs to fetch."),
    max_credits: int = typer.Option(60, help="Hard credit cap, enforced before every request (1 credit per org)."),
) -> None:
    """Fetch headcount growth from Apollo for gate-passers (resumable). Needs APOLLO_API_KEY unless --dry-run."""
    from . import enrich_apollo
    enrich_apollo.enrich(limit=limit, max_credits=max_credits, dry_run=dry_run)
