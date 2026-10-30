"""Export the pipeline results from DuckDB and render docs/dashboard/index.html.

Read-only: one short connection, closed before the page is written. The page is a
single self-contained HTML file with the data embedded as JSON. It embeds the
v4 mart tables (gate funnel, rubric, fit-bonus rules, verify queue), the optional
account dossiers (docs/part1-segmentation/accounts/*.json), the CRM model JSON and the
approach-evolution markdown. Free text from JSON is rendered by the page as text only.
"""
from __future__ import annotations

import ast
import html
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path

import duckdb

from .paths import (ACCOUNTS_DIR, CRM_MODEL_JSON, DASHBOARD_HTML, DB, DOCS, EVOLUTION_MD, PUBLISH_HTML, README, ROOT,
                    SEGMENTATION, SQL_DIR, SRC_PKG, TRACES_DIR)

TEMPLATE = Path(__file__).resolve().parent / "templates" / "dashboard.html"
OUT = DASHBOARD_HTML
REPO_URL = "https://github.com/AviBenmayor/white-circle-gtm"   # private; access is granted on request
PART2_DIR = DOCS / "part2-systems-design"

TIERS = ["Tier 1", "Tier 2", "Tier 3", "Nurture"]
CORE_SEGMENTS = ["Regulated GenAI", "AI-native builders", "Marketed verticals"]
OTHER_SEGMENTS = ["Enterprise", "Competitor", "Out: is_closed", "Out: is_acquired", "Out: is_nonprofit",
                  "Out: is_services_firm", "Out: dead_or_hijacked_site", "Out: not_ai", "Out: industry_not_matched"]
CRM_MODEL = CRM_MODEL_JSON
EVOLUTION = EVOLUTION_MD


def _rows(con, sql: str, params: list | None = None) -> list[dict]:
    cur = con.execute(sql, params or [])
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def _exists(con, table: str) -> bool:
    s, t = table.split(".")
    return con.execute("SELECT count(*) FROM information_schema.tables WHERE table_schema=? AND table_name=?",
                       [s, t]).fetchone()[0] > 0


def _safe(con, sql: str, params: list | None = None) -> list[dict]:
    try:
        return _rows(con, sql, params)
    except Exception:  # a missing table must not break the page
        return []


def _load_json(path: Path):
    try:
        return json.loads(path.read_text())
    except Exception:  # missing or half-written file: the page shows "pending"
        return None


def _accounts() -> dict:
    """Dossiers written by other agents: docs/part1-segmentation/accounts/<org_uuid>.json. Whatever exists is embedded."""
    out = {}
    if ACCOUNTS_DIR.exists():
        for p in sorted(ACCOUNTS_DIR.glob("*.json")):
            d = _load_json(p)
            if isinstance(d, dict):
                out[p.stem] = d
    return out


def _repo_path(path: Path) -> str:
    return path.resolve().relative_to(ROOT).as_posix()


def repo_link(rel: str) -> str:
    kind = "tree" if (ROOT / rel).is_dir() else "blob"
    return f"{REPO_URL}/{kind}/main/{rel}"


# Files that are already shown on the dashboard link to their tab or section, not to the repo.
IN_PAGE = {
    "docs/dashboard/index.html": "#segments", "docs/part1-segmentation/top50.csv": "#top50",
    "docs/part1-segmentation/memo.md": "#memo", "docs/part1-segmentation/approach-evolution.md": "#evo",
    "docs/part1-segmentation/accounts": "#deep-dives", "docs/part1-crm-model/crm-data-model.md": "#crm",
    "docs/part1-crm-model/crm_model.json": "#crm", "docs/part2-systems-design": "#system-design",
    "docs/part2-systems-design/system-design.md": "#system-design", "docs/traces/index.md": "#traces-md",
}


def _a(url: str, label: str) -> str:
    ext = "" if url.startswith("#") else ' target="_blank" rel="noopener noreferrer"'
    return f'<a href="{html.escape(url, quote=True)}"{ext}>{label}</a>'


def md_to_html(md: str, base: Path | None = None, autolink_dir: Path | None = None) -> str:
    """Safe markdown subset: headings, code fences, tables, bullet/numbered lists, quotes, links, code spans,
    bold, italic. Everything is HTML-escaped first; link targets are http(s) or repo-relative paths only.
    `base` is the folder the markdown file lives in (relative links resolve against it into REPO_URL)."""
    base = base or ROOT

    def href(url: str) -> str | None:
        url = url.strip()
        if re.match(r"^https?://", url, re.I):
            return url
        if url.startswith("#") or re.match(r"^[a-z][a-z0-9+.-]*:", url, re.I):
            return None
        rel = os.path.normpath(os.path.join(base.relative_to(ROOT).as_posix() if base != ROOT else "", url.split("#")[0]))
        if rel.startswith("..") or os.path.isabs(rel):
            return None
        return IN_PAGE.get(rel) or repo_link(rel)

    def inline(t: str) -> str:
        codes: list[str] = []

        def keep(m):
            codes.append("<code>" + html.escape(m.group(1), quote=True) + "</code>")
            return f"\x00{len(codes) - 1}\x00"
        t = re.sub(r"`([^`]+)`", keep, t)
        t = re.sub(r"!\[([^\]]*)\]\([^)]*\)", r"\1", t)          # images: alt text only
        links: list[str] = []

        def link(m):
            u = href(m.group(2))
            label = html.escape(m.group(1), quote=True)
            if u is None:
                return label
            links.append(_a(u, label))
            return f"\x01{len(links) - 1}\x01"
        t = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", link, t)
        t = html.escape(t, quote=True)
        t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
        t = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<em>\1</em>", t)
        t = re.sub(r"\x01(\d+)\x01", lambda m: links[int(m.group(1))], t)
        return re.sub(r"\x00(\d+)\x00", lambda m: codes[int(m.group(1))], t)

    def cell(t: str) -> str:
        t = t.strip()
        if autolink_dir is not None and re.fullmatch(r"[\w.-]+\.(md|jsonl)", t) and (autolink_dir / t).exists():
            return f'<a href="{html.escape(repo_link(_repo_path(autolink_dir / t)), quote=True)}" target="_blank" rel="noopener noreferrer">{html.escape(t)}</a>'
        return inline(t)

    def split_row(line: str) -> list[str]:
        return [c for c in re.split(r"(?<!\\)\|", line.strip().strip("|"))]

    lines = md.splitlines()
    out: list[str] = []
    para: list[str] = []
    items: list[list[str]] = []
    kind = "ol"
    i = 0

    def flush_para():
        if para:
            out.append("<p>" + inline(" ".join(para)) + "</p>")
            para.clear()

    def flush_list():
        if items:
            out.append(f"<{kind}>" + "".join(f"<li>{inline(' '.join(x))}</li>" for x in items) + f"</{kind}>")
            items.clear()

    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if s.startswith("```"):
            flush_para(); flush_list()
            buf = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                buf.append(lines[i]); i += 1
            out.append("<pre><code>" + html.escape("\n".join(buf)) + "</code></pre>")
            i += 1
            continue
        if s.startswith("<!--"):
            while i < len(lines) and "-->" not in lines[i]:
                i += 1
            i += 1
            continue
        if s.startswith("|") and i + 1 < len(lines) and re.match(r"^\s*\|?\s*:?-{2,}", lines[i + 1]):
            flush_para(); flush_list()
            head = split_row(s)
            i += 2
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(split_row(lines[i])); i += 1
            out.append('<div class="scroll"><table><thead><tr>' + "".join(f"<th>{inline(c.strip())}</th>" for c in head)
                       + "</tr></thead><tbody>"
                       + "".join("<tr>" + "".join(f"<td>{cell(c)}</td>" for c in r) + "</tr>" for r in rows)
                       + "</tbody></table></div>")
            continue
        m_h = re.match(r"^(#{1,6})\s+(.*)$", line)
        m_n = re.match(r"^\s*\d+\.\s+(.*)$", line)
        m_b = re.match(r"^\s*[-*]\s+(.*)$", line)
        if m_h:
            flush_para(); flush_list()
            lvl = min(len(m_h.group(1)) + 1, 4)
            out.append(f"<h{lvl}>{inline(m_h.group(2))}</h{lvl}>")
        elif m_n or m_b:
            flush_para()
            k = "ol" if m_n else "ul"
            if items and k != kind:
                flush_list()
            kind = k
            items.append([(m_n or m_b).group(1)])
        elif not s:
            flush_para(); flush_list()
        elif s.startswith(">"):
            flush_para(); flush_list()
            out.append("<blockquote>" + inline(s.lstrip("> ")) + "</blockquote>")
        elif s == "---":
            flush_para(); flush_list()
            out.append("<hr>")
        elif items and line.startswith((" ", "\t")):
            items[-1].append(s)
        else:
            flush_list()
            para.append(s)
        i += 1
    flush_para(); flush_list()
    return "\n".join(out)


def _md_file(path: Path, **kw) -> str:
    return md_to_html(path.read_text(), base=path.parent, **kw) if path.exists() else ""


def _first_comment(path: Path) -> str:
    """First comment line of a SQL file; a leading 'file.sql  ->  tables' header becomes 'Creates tables'."""
    for ln in path.read_text().splitlines():
        t = ln.strip()
        if not t.startswith("--"):
            continue
        t = t.lstrip("-").strip()
        if t.startswith(path.name):
            rest = t[len(path.name):].strip()
            t = ("Creates " + rest.lstrip("->").strip()) if rest.startswith("->") and rest.lstrip("->").strip() else ""
        if t:
            return t
    return ""


def _py_doc(path: Path) -> str:
    try:
        doc = ast.get_docstring(ast.parse(path.read_text())) or ""
    except SyntaxError:
        doc = ""
    return doc.strip().splitlines()[0] if doc.strip() else ""


def _md_title(path: Path) -> str:
    for ln in path.read_text().splitlines():
        if ln.startswith("#"):
            return ln.lstrip("# ").strip()
    return ""


def _cli_commands() -> list[dict]:
    import typer
    from .cli import app
    group = typer.main.get_command(app)
    cmds = []
    for name, c in group.commands.items():
        opts = [dict(flags=" / ".join(p.opts + p.secondary_opts), help=(p.help or ""))
                for p in c.params if hasattr(p, "opts") and p.param_type_name == "option"]
        cmds.append(dict(name=name, usage=f"uv run whitecircle {name}", help=(c.help or "").strip().splitlines()[0] if c.help else "",
                         options=opts))
    return cmds


def _schema(con) -> list[dict]:
    rows = _rows(con, """SELECT table_schema AS s, table_name AS t, column_name AS c, data_type AS ty
        FROM information_schema.columns WHERE table_schema NOT IN ('information_schema','main','pg_catalog')
        ORDER BY 1, 2, ordinal_position""")
    sch: dict = {}
    for r in rows:
        sch.setdefault(r["s"], {}).setdefault(r["t"], []).append(f"{r['c']} {r['ty']}")
    return [dict(schema=s, tables=[dict(name=t, columns=c) for t, c in ts.items()]) for s, ts in sch.items()]


def _code_tab(con) -> dict:
    sqls = [dict(path=_repo_path(p), name=p.name, desc=_first_comment(p)) for p in sorted(SQL_DIR.glob("*.sql"))]
    mods = [dict(path=_repo_path(p), name=p.name, desc=_py_doc(p))
            for p in sorted(SRC_PKG.glob("*.py")) if p.name != "__init__.py"]
    mods.append(dict(path=_repo_path(TEMPLATE), name=TEMPLATE.name, desc="This dashboard page (HTML template)"))
    notes = [dict(path=_repo_path(p), name=_repo_path(p), desc=_md_title(p))
             for p in sorted(DOCS.rglob("*.md")) if TRACES_DIR not in p.parents and "accounts" not in p.parts]
    notes.insert(0, dict(path="README.md", name="README.md", desc=_md_title(README)))
    arts = [dict(path=_repo_path(p), name=_repo_path(p), desc="")
            for g in ("part1-segmentation/*.csv", "part1-crm-model/*.json", "part1-segmentation/accounts/*.json", "part1-segmentation/accounts/*.md")
            for p in sorted(DOCS.glob(g))]
    arts += [dict(path=n, name=n, desc="") for n in ("Makefile", "pyproject.toml") if (ROOT / n).exists()]
    return dict(sql=sqls, modules=mods, cli=_cli_commands(), schema=_schema(con), notes=notes, artifacts=arts)


def export(con) -> dict:
    top = _rows(con, """
        SELECT t.rank, t.org_uuid, t.name, t.domain, t.country, t.short_description, t.segment, t.tier, t.total, t.rubric_total,
          t.pts_recency, t.pts_revenue, t.pts_headcount, t.pts_bonus, t.pts_bonus_vertical, t.pts_bonus_agentic,
          t.region_bucket, t.vertical, t.llm_level, t.last_equity_date, t.months_since_last_equity, t.revenue_label, t.employees_label,
          t.growth_3m_pct, t.growth_6m_pct, t.growth_12m_pct, round(t.data_confidence, 2) AS data_confidence,
          t.reason_1, t.reason_2, t.reason_3, t.best_contact_name, t.best_contact_title,
          t.llm_level_source, t.verified_ships_llm, t.verified_llm_use, t.is_agentic, t.evidence_quote,
          r.source_url AS evidence_url, r.url_checked
        FROM mart.top50 t LEFT JOIN stg.company_review r USING (org_uuid) ORDER BY t.rank""")
    seg = _rows(con, "SELECT segment, coalesce(tier,'-') AS tier, count(*) AS n FROM mart.org_segment GROUP BY 1,2")
    universe = con.execute("SELECT count(*) FROM mart.org_segment").fetchone()[0]
    core = con.execute("SELECT count(*) FROM mart.org_segment WHERE passes_all").fetchone()[0]
    tier1 = con.execute("SELECT count(*) FROM mart.org_segment WHERE tier='Tier 1'").fetchone()[0]
    verified = con.execute("SELECT count(*) FROM mart.org_score WHERE has_verified_review AND verified_ships_llm='yes'").fetchone()[0]
    score = _rows(con, "SELECT score_version, count(*) n FROM mart.org_score GROUP BY 1 ORDER BY 2 DESC")
    as_of = con.execute("SELECT as_of FROM mart.params").fetchone()[0]

    vert = _rows(con, """SELECT m.vertical, g.segment, count(*) AS n FROM mart.org_master m
        JOIN mart.org_segment g ON g.org_uuid = m.uuid WHERE g.passes_all GROUP BY 1,2""")
    reg = _rows(con, """SELECT m.region_bucket AS region, g.segment, count(*) AS n FROM mart.org_master m
        JOIN mart.org_segment g ON g.org_uuid = m.uuid WHERE g.passes_all GROUP BY 1,2""")

    dq = _rows(con, """SELECT ord, check_name, description, rows_affected, action_taken, 'data' AS src FROM dq.checks
        UNION ALL SELECT ord, check_name, description, rows_affected, action_taken, 'score' FROM dq.score_checks
        ORDER BY ord""")
    for d in dq:
        a = (d["action_taken"] or "")
        assertion = a.startswith("None needed") or a.startswith("0 = pass") or "kept as an assertion" in a \
            or d["check_name"] in ("org_round_count_mismatch",)
        d["kind"] = "pass" if d["rows_affected"] == 0 else ("fail" if assertion else "info")

    runs = _safe(con, """SELECT command, status, started_at, ended_at, rows_written, git_sha, error,
        date_diff('millisecond', started_at, ended_at) AS ms FROM ops.run ORDER BY started_at""")
    calls = _safe(con, """SELECT provider, endpoint, request_summary, status_code, latency_ms, credits_or_tokens,
        cost_usd, called_at FROM ops.api_call ORDER BY called_at""")
    tavily = sum((c["credits_or_tokens"] or 0) for c in calls if (c["provider"] or "").lower() == "tavily")
    pdl_calls = sum(1 for c in calls if (c["provider"] or "").lower() == "peopledatalabs")
    enriched = con.execute("SELECT count(*) FROM stg.headcount_history").fetchone()[0]
    accounts = _accounts()

    return dict(
        meta=dict(as_of=as_of, score_version=score[0]["score_version"] if score else None,
                  generated_at=datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
                  universe=universe, core=core, tier1=tier1, verified=verified, top50_n=len(top),
                  enriched=enriched, pdl_calls=pdl_calls),
        tiers=TIERS, core_segments=CORE_SEGMENTS, other_segments=OTHER_SEGMENTS,
        cutoffs=_rows(con, "SELECT tier, min_score FROM mart.tier_cutoff ORDER BY ord"),
        funnel=_rows(con, "SELECT step, gate, remaining, removed_here FROM mart.gate_funnel ORDER BY step"),
        weights=_rows(con, "SELECT component, level, points, rationale FROM mart.score_weight"),
        fit_rules=_rows(con, "SELECT kind, key, points, tier, evidence FROM mart.fit_bonus_rule ORDER BY points DESC, key"),
        vertical_gate=_rows(con, "SELECT vertical, grp, passes, rationale FROM mart.vertical_gate"),
        verify_next=_rows(con, """SELECT queue_rank, name, domain, country, segment, tier, total, llm_level, vertical, reason_1,
            best_contact_name, best_contact_title FROM mart.verify_next ORDER BY queue_rank LIMIT 40"""),
        verify_next_total=con.execute("SELECT count(*) FROM mart.verify_next").fetchone()[0],
        matrix=seg, top50=top, vertical=vert, region=reg, dq=dq, runs=runs, calls=calls,
        tavily_credits=tavily, accounts=accounts, crm_model=_load_json(CRM_MODEL),
        repo_url=REPO_URL,
        memo_html=_md_file(SEGMENTATION / "memo.md"),
        evolution_html=_md_file(EVOLUTION),
        profile_html=_md_file(SEGMENTATION / "data-profile.md"),
        traces_html=_md_file(TRACES_DIR / "index.md", autolink_dir=TRACES_DIR),
        **_part2_sections(),
        code=_code_tab(con))


def _part2_sections() -> dict:
    """Part 2 tab: the diagram is drawn in the template, so section (a) (the mermaid source) is skipped;
    the note (b) is shown open and the appendix (c) collapsed."""
    p = PART2_DIR / "system-design.md"
    if not p.exists():
        return dict(system_html="", system_appx_html="")
    md = p.read_text()
    parts = re.split(r"(?m)^## \(([abc])\)[^\n]*\n", md)
    sec = {parts[i]: parts[i + 1] for i in range(1, len(parts) - 1, 2)}
    head = re.search(r"(?m)^## \(b\)[^\n]*$", md)
    note = (head.group(0) + "\n" + sec["b"]) if head and "b" in sec else md
    return dict(system_html=md_to_html(note, base=PART2_DIR), system_appx_html=md_to_html(sec.get("c", ""), base=PART2_DIR))


_WRAP = re.compile(r"(?is)<!doctype[^>]*>[ \t]*\n?|</?html(?:\s[^>]*)?>[ \t]*\n?|</?head(?:\s[^>]*)?>[ \t]*\n?|</?body(?:\s[^>]*)?>[ \t]*\n?")


def _inline_svg(svg: str) -> str:
    svg = svg[svg.find("<svg"):]
    return svg.replace("var(--wf-human,#d97706)", "var(--warn)")   # tokens only, no literal colour


def render() -> Path:
    con = duckdb.connect(str(DB), read_only=True)
    try:
        data = export(con)
    finally:
        con.close()
    blob = json.dumps(data, default=str, separators=(",", ":")).replace("</", "<\\/")
    svg_path = OUT.parent / "workflow.svg"
    svg = _inline_svg(svg_path.read_text()) if svg_path.exists() else ""
    tpl = TEMPLATE.read_text()
    outs = {OUT: tpl, PUBLISH_HTML: _WRAP.sub("", tpl)}   # publisher supplies the skeleton for the second copy
    for path, text in outs.items():
        text = text.replace("/*__DATA__*/null", blob).replace("<!-- WORKFLOW_SVG -->", svg)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
    return OUT
