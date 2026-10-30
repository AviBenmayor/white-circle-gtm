"""Headcount enrichment from Apollo.io Organization Enrichment (replaces People Data Labs, whose
signup was rejected). Future path: headcount growth is NOT scored in the current version (no enrichment data); this fills
the enriched attribute, which nothing in the score reads.
Same pipeline as enrich_pdl.py: gate-passers, best pre-growth score first -> skip orgs that already
have a seed row (from ANY source) or a saved Apollo response -> one GET each -> raw JSON to
data/enrich/apollo/<org_uuid>.json -> parsed row appended to seeds/headcount_history.csv.

WHAT THE APOLLO DOCS CONFIRMED (read 2026-10-30 on docs.apollo.io):
  * Endpoint: GET https://api.apollo.io/api/v1/organizations/enrich, key in header x-api-key.
    Identifier params: domain (no www., no @), linkedin_url, website; name only helps alongside
    another identifier (the page contradicts itself on name alone), so we send domain and use
    name only when an org has no domain.
  * Fields: estimated_num_employees (int), organization_headcount_six_month_growth,
    organization_headcount_twelve_month_growth, organization_headcount_twenty_four_month_growth
    (numbers, null when unavailable). There is NO 3-month figure, so growth_3m_pct is always NULL.
  * Cost: 1 credit per organization (bulk endpoint is also 1 per org, up to 10 per call).
  * Rate limit: depends on plan; the doc's sample 429 cites 600 calls/hour for this endpoint.
  * Errors: 401 invalid key; 403 API_INACCESSIBLE / ENDPOINT_ACCESS_DENIED; 422 identifier
    required; 429 rate limited.
ASSUMED / NOT CONFIRMED (verify on the first real call, use --limit 1):
  * UNITS: the docs call the growth fields "percentage change" with example 12.3, which suggests
    PERCENT (12.3 = +12.3%) but never say so outright. We store the value as-is
    (GROWTH_SCALE = 1.0). If the first response shows fractions (0.123), set GROWTH_SCALE = 100
    and re-parse from the saved raw JSON; nothing is lost.
  * The response wraps the company under a top-level "organization" key (we also accept a bare
    object). A no-match is assumed to be 200 with no organization, or 404; we rely on the body,
    not the status, and count 1 credit only when an organization came back (credit billing on
    no-match is unconfirmed, so the cap is conservative: it counts every 200).
  * Whether the FREE plan has API access: the docs do not say ("free accounts need a work email
    registration"). The run therefore stops at the first 401/403 with a clear message.
No real response has been seen (no key yet); the parser is tested on a fixture only.

Every call is logged with obs.record_api_call. --dry-run (default) calls nothing. Needs env
APOLLO_API_KEY (loaded from .env) only for a real run.
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

import typer

from .enrich_pdl import SEED_COLS, plan_orgs as _plan_all
from .obs import record_api_call, track_run
from .paths import DATA, HC_SEED

URL = "https://api.apollo.io/api/v1/organizations/enrich"
APOLLO_DIR = DATA / "enrich" / "apollo"
GROWTH_SCALE = 1.0  # see ASSUMED: docs example 12.3 reads as percent
SLEEP_S = 6.1       # 600/hour sample limit -> stay at ~590/hour


def parse_response(org_uuid: str, body: dict, fetched_at: datetime) -> dict | None:
    """One seed row from an Apollo response, or None when there is no usable match."""
    org = (body or {}).get("organization") if isinstance(body, dict) and "organization" in body else body
    if not isinstance(org, dict) or not org:
        return None
    cur = org.get("estimated_num_employees")
    g6 = org.get("organization_headcount_six_month_growth")
    g12 = org.get("organization_headcount_twelve_month_growth")
    if cur is None and g6 is None and g12 is None:
        return None

    def pct(v):
        return round(float(v) * GROWTH_SCALE, 2) if v is not None else None

    return {
        "org_uuid": org_uuid, "pdl_id": None, "likelihood": None,
        "hc_current": int(cur) if cur is not None else None,
        "hc_3m_ago": None, "hc_6m_ago": None, "hc_12m_ago": None,
        "growth_3m_pct": None, "growth_6m_pct": pct(g6), "growth_12m_pct": pct(g12),
        "hc_source": "apollo", "hc_fetched_at": fetched_at.strftime("%Y-%m-%d %H:%M:%S"),
    }


def plan_orgs() -> list[dict]:
    """Gate-passers by pre-growth score, minus orgs with a seed row from any source or a saved Apollo response."""
    done = {p.stem for p in APOLLO_DIR.glob("*.json")} if APOLLO_DIR.exists() else set()
    if HC_SEED.exists():
        with HC_SEED.open(newline="", encoding="utf-8") as f:
            done |= {r["org_uuid"] for r in csv.DictReader(f)}
    # enrich_pdl.plan_orgs also drops PDL raw files, which is right: those orgs were fetched elsewhere.
    return [r for r in _plan_all() if r["org_uuid"] not in done]


def call_apollo(key: str, org: dict) -> tuple[int, dict, float]:
    q = {"domain": org["domain"]} if org["domain"] else {"name": org["organization_name"]}
    req = urllib.request.Request(f"{URL}?{urllib.parse.urlencode(q)}",
                                 headers={"x-api-key": key, "accept": "application/json",
                                          "Cache-Control": "no-cache"})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return r.status, json.loads(r.read().decode()), (time.time() - t0) * 1000
    except urllib.error.HTTPError as e:
        raw = e.read().decode(errors="replace")
        try:
            body = json.loads(raw)
        except Exception:
            body = {"status": e.code, "text": raw[:300]}
        return e.code, body, (time.time() - t0) * 1000


def enrich(limit: int | None = None, max_credits: int = 60, dry_run: bool = True) -> None:
    with track_run("enrich-headcount-apollo", {"limit": limit, "max_credits": max_credits, "dry_run": dry_run}) as run:
        todo = plan_orgs()
        n = min(len(todo), max_credits, limit if limit is not None else len(todo))
        batch = todo[:n]
        typer.echo(f"Apollo org enrich: {len(todo)} gate-passers without headcount data; this run would make {n} "
                   f"requests (cap: --max-credits {max_credits}, --limit {limit}); worst case {n} credits (1 each).")
        typer.echo(f"pacing {SLEEP_S}s/request (600/hour sample limit): about {n * SLEEP_S / 60:.1f} minutes. "
                   "growth_3m_pct stays NULL (Apollo has no 3-month figure).")
        for o in batch[:10]:
            typer.echo(f"  {o['pre_growth']:>3}  {o['organization_name'][:36]:<36} {o['domain'] or '(name only)'}")
        if n > 10:
            typer.echo(f"  ... and {n - 10} more")
        if dry_run:
            typer.echo("dry run: no API calls made, nothing written. Re-run with --no-dry-run and APOLLO_API_KEY set.")
            return
        key = os.environ.get("APOLLO_API_KEY")
        if not key:
            raise typer.BadParameter("APOLLO_API_KEY is not set (put it in .env)")
        APOLLO_DIR.mkdir(parents=True, exist_ok=True)
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
                status, body, ms = call_apollo(key, o)
                fetched = datetime.now(timezone.utc).replace(tzinfo=None)
                record_api_call(run.run_id, "apollo", "organizations/enrich",
                                o["domain"] or o["organization_name"], status, ms,
                                1 if status == 200 else 0, None, f"apollo:{o['org_uuid']}", fetched)
                if status in (401, 403):
                    typer.echo(f"STOP: Apollo returned HTTP {status} ({json.dumps(body)[:200]}). The key is invalid or "
                               "this plan has no API access to organizations/enrich (the free plan may not). "
                               "No more requests made.")
                    raise typer.Exit(1)
                if status == 429:
                    typer.echo("STOP: Apollo rate limit (429). Wait and re-run; the run is resumable.")
                    raise typer.Exit(1)
                (APOLLO_DIR / f"{o['org_uuid']}.json").write_text(json.dumps(body, indent=1))
                spent += 1 if status == 200 else 0
                row = parse_response(o["org_uuid"], body, fetched) if status == 200 else None
                if row:
                    w.writerow(row)
                    f.flush()
                    run.add_rows(1)
                typer.echo(f"{i}/{len(batch)} {o['organization_name'][:30]:<30} HTTP {status} "
                           f"{'matched' if row else 'no data'}  credits {spent}/{max_credits}")
                time.sleep(SLEEP_S)
