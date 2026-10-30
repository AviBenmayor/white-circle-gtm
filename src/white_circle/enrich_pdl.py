"""Headcount enrichment from People Data Labs (PDL) Company Enrichment.

Future path: headcount growth is NOT scored in the current version (no enrichment data); this fills
stg.headcount_history, which nothing in the score reads. Pipeline:
  gate-passers, best pre-growth score first -> skip orgs already fetched -> one GET each
  -> raw JSON to data/enrich/pdl/<org_uuid>.json -> parsed row appended to
  src/white_circle/seeds/headcount_history.csv (committed provenance, read by 56_).

WHAT THE PDL DOCS CONFIRMED (read 2026-10-30 on docs.peopledatalabs.com):
  * Endpoint: GET https://api.peopledatalabs.com/v5/company/enrich, key in header X-Api-Key.
  * Match inputs: at least one of pdl_id, name, ticker, website, profile; website wins for
    us (a clean domain). min_likelihood 1-10 (default 2); we send 5 to avoid wrong-company
    matches. required, titlecase also exist.
  * Response: company fields are TOP LEVEL (not under "data"), plus status and likelihood
    (1-10). Fields without data are null.
  * employee_count (int, current), employee_count_by_month (object, "YYYY-MM" -> int, end of
    month, from the first employee or 2010-01), employee_growth_rate (object with keys
    "3_month", "6_month", "12_month", "24_month"; each a float FRACTION, 0.0595 = +5.95%,
    can be negative, null if the company had zero employees at the window start).
  * Billing is "per match" (a 404 no-match is not a match, so presumably not billed).
  * Free plan: 10 requests per minute (paid 1,000/min); the pricing page says "up to 100
    monthly records" on the free plan.
ASSUMED / NOT CONFIRMED (verify with the first real call before trusting):
  * 1 credit per matched record. The docs pages I could reach do not state the credit
    amount, and the billing page was a 404. --max-credits therefore counts one credit per
    request that returns 200 and refuses to start a request that could exceed the cap.
  * That a 404 is free (inferred from "per match").
  * That the growth keys are present on the free tier and that employee_count_by_month
    reaches back 12 months for small companies.
  * The exact 404 body (not shown in the docs); we only rely on the HTTP status.
  * Parsing from the fixture below is tested; no real response has been seen (no key yet).

Every call is logged with obs.record_api_call. --dry-run (the default) prints the plan and
the request count and calls nothing. Needs env PDL_API_KEY only for a real run.
"""
from __future__ import annotations

import csv
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import duckdb
import typer

from .obs import record_api_call, track_run
from .paths import DB, ENRICH, HC_SEED

URL = "https://api.peopledatalabs.com/v5/company/enrich"
MIN_LIKELIHOOD = 5
SEED_COLS = ["org_uuid", "pdl_id", "likelihood", "hc_current", "hc_3m_ago", "hc_6m_ago", "hc_12m_ago",
             "growth_3m_pct", "growth_6m_pct", "growth_12m_pct", "hc_source", "hc_fetched_at"]
FREE_RPM = 10  # free-plan rate limit: 10 requests / minute


def _month_back(ym: str, n: int) -> str:
    y, m = int(ym[:4]), int(ym[5:7])
    t = y * 12 + (m - 1) - n
    return f"{t // 12:04d}-{t % 12 + 1:02d}"


def parse_response(org_uuid: str, body: dict, fetched_at: datetime) -> dict | None:
    """One parsed seed row from a PDL company response, or None if it is not a match."""
    if not body or body.get("status") not in (None, 200) or not body.get("employee_count_by_month") \
            and body.get("employee_count") is None:
        return None
    by_month = body.get("employee_count_by_month") or {}
    cur_month = fetched_at.strftime("%Y-%m")

    def count_ago(n: int):
        v = by_month.get(_month_back(cur_month, n))
        return int(v) if v is not None else None

    cur = body.get("employee_count")
    cur = int(cur) if cur is not None else None
    rate = body.get("employee_growth_rate") or {}

    def pct(key: str):
        v = rate.get(key)
        return round(float(v) * 100, 2) if v is not None else None

    return {
        "org_uuid": org_uuid, "pdl_id": body.get("id"), "likelihood": body.get("likelihood"),
        "hc_current": cur, "hc_3m_ago": count_ago(3), "hc_6m_ago": count_ago(6), "hc_12m_ago": count_ago(12),
        "growth_3m_pct": pct("3_month"), "growth_6m_pct": pct("6_month"), "growth_12m_pct": pct("12_month"),
        "hc_source": "peopledatalabs", "hc_fetched_at": fetched_at.strftime("%Y-%m-%d %H:%M:%S"),
    }


def _already_fetched() -> set[str]:
    done = {p.stem for p in ENRICH.glob("*.json")} if ENRICH.exists() else set()
    if HC_SEED.exists():
        with HC_SEED.open(newline="", encoding="utf-8") as f:
            done |= {r["org_uuid"] for r in csv.DictReader(f)}
    return done


def plan_orgs() -> list[dict]:
    """Gate-passers, best score first."""
    con = duckdb.connect(str(DB), read_only=True)
    try:
        cur = con.execute(
            "SELECT s.org_uuid, m.organization_name, m.domain, s.total AS pre_growth "
            "FROM mart.org_score s JOIN mart.org_master m ON m.uuid = s.org_uuid "
            "ORDER BY pre_growth DESC, s.ord")
        cols = [d[0] for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
    finally:
        con.close()
    done = _already_fetched()
    return [r for r in rows if r["org_uuid"] not in done]


def call_pdl(key: str, org: dict) -> tuple[int, dict, float]:
    q = {"min_likelihood": MIN_LIKELIHOOD}
    if org["domain"]:
        q["website"] = org["domain"]
    else:
        q["name"] = org["organization_name"]
    req = urllib.request.Request(f"{URL}?{urllib.parse.urlencode(q)}", headers={"X-Api-Key": key})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode()), (time.time() - t0) * 1000
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read().decode())
        except Exception:
            body = {"status": e.code}
        return e.code, body, (time.time() - t0) * 1000


def enrich(limit: int | None = None, max_credits: int = 25, dry_run: bool = True) -> None:
    with track_run("enrich-headcount", {"limit": limit, "max_credits": max_credits, "dry_run": dry_run}) as run:
        todo = plan_orgs()
        n = min(len(todo), max_credits, limit if limit is not None else len(todo))
        batch = todo[:n]
        typer.echo(f"PDL company enrich: {len(todo)} gate-passers not yet fetched; this run would make {n} requests "
                   f"(cap: --max-credits {max_credits}, --limit {limit}); worst case {n} credits (1 per match assumed).")
        typer.echo(f"free plan: ~{FREE_RPM} requests/minute, so about {n / FREE_RPM:.1f} minutes of waiting.")
        for o in batch[:10]:
            typer.echo(f"  {o['pre_growth']:>3}  {o['organization_name'][:36]:<36} {o['domain'] or '(name match)'}")
        if n > 10:
            typer.echo(f"  ... and {n - 10} more")
        if dry_run:
            typer.echo("dry run: no API calls made, nothing written. Re-run with --no-dry-run and PDL_API_KEY set.")
            return
        key = os.environ.get("PDL_API_KEY")
        if not key:
            raise typer.BadParameter("PDL_API_KEY is not set")
        ENRICH.mkdir(parents=True, exist_ok=True)
        HC_SEED.parent.mkdir(parents=True, exist_ok=True)
        new = not HC_SEED.exists()
        spent = 0
        with HC_SEED.open("a", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(f, fieldnames=SEED_COLS, lineterminator="\n")
            if new:
                w.writeheader()
            for i, o in enumerate(batch, 1):
                if spent + 1 > max_credits:  # enforced in code, before the request
                    typer.echo(f"credit cap {max_credits} reached")
                    break
                status, body, ms = call_pdl(key, o)
                fetched = datetime.now(timezone.utc).replace(tzinfo=None)
                (ENRICH / f"{o['org_uuid']}.json").write_text(json.dumps(body, indent=1))
                credit = 1 if status == 200 else 0
                spent += credit
                record_api_call(run.run_id, "peopledatalabs", "company/enrich",
                                f"{o['domain'] or o['organization_name']} (min_likelihood={MIN_LIKELIHOOD})",
                                status, ms, credit, None, f"pdl:{o['org_uuid']}", fetched)
                row = parse_response(o["org_uuid"], body, fetched) if status == 200 else None
                if row:
                    w.writerow(row)
                    f.flush()
                    run.add_rows(1)
                typer.echo(f"{i}/{len(batch)} {o['organization_name'][:30]:<30} HTTP {status} "
                           f"{'matched' if row else 'no match'}  credits {spent}/{max_credits}")
                time.sleep(60 / FREE_RPM + 0.1)
