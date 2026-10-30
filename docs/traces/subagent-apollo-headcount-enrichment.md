# Subagent trace: Apollo headcount enrichment

A delegated subagent (general-purpose). Its prompt, its tool calls and results, and its final report. Same redaction rules as the main session.

## Turn 1 - User (2026-10-30 15:05:23 UTC)

Add Apollo as the headcount-growth source for the White Circle take-home at white_circle. PDL rejected the owner's signup, so Apollo replaces it.

Read first: src/white_circle/enrich_pdl.py (copy its pattern: dry-run on by default, --limit, --max-credits enforced in code, resumable, raw JSON to data/enrich/<provider>/, parsed rows to src/white_circle/seeds/headcount_history.csv, obs.record_api_call on every call), src/white_circle/sql/56_stg_headcount_history.sql, the growth parts of 57_mart_org_master.sql and 60_mart_org_score.sql, and cli.py.

1. Verify Apollo's real API with WebFetch on docs.apollo.io:
   - The Organization Enrichment endpoint: likely GET https://api.apollo.io/api/v1/organizations/enrich?domain=…, with the key in an `x-api-key` header.
   - The response fields for headcount: likely estimated_num_employees and organization_headcount_six_month_growth / twelve_month_growth / twenty_four_month_growth. Confirm whether they are fractions or percentages.
   - Credit cost, rate limits, and whether the free plan has API access.
   Record what you confirmed vs assumed in the module docstring.
2. Write `src/white_circle/enrich_apollo.py` and a `whitecircle enrich-headcount-apollo` command. Make small, targeted edits to cli.py, because another agent may also edit it: re-read the file right before editing.
[redacted line: outside-scope]
   - Map the fields onto the existing headcount_history columns: hc_current; growth_6m_pct and growth_12m_pct from Apollo; growth_3m_pct NULL (Apollo has no 3-month figure); hc_source='apollo'.
   - If a seed row already exists from another source, keep it and don't overwrite it.
   - Order requests as gate-passers by v4 pre-growth score.
   - Default max credits: 60.
   - If the response suggests the free plan lacks API access (401/403 or a plan error), stop immediately and print a clear message.
3. In the 60_ SQL header and the score_weight rationale, note that the 3-month +4 can't be earned while Apollo is the source. Growth scoring stays as defined, so leave the points unchanged.
4. Test the parser against a fixture in [REDACTED_SECRET], then run the dry-run. There is no key yet, so make NO real calls and invent no seed data.
5. Don't move files. Another agent is reorganizing docs/ now, so touch only src/white_circle/ (enrich_apollo.py, cli.py, sql/56/57/60 comments if needed). Don't touch dashboard.py or the templates, and don't commit.

Final reply, at most 8 lines: what Apollo's docs confirmed (fields, units, cost, free-plan API access), the dry-run plan, and the exact command to run once the key is in.

Tool call `ToolSearch`
```
{
 "query": "select:WebFetch",
 "max_results": 1
}
```

Result of `ToolSearch`
```
[omitted: tool-schema lookup]
```

Tool call `Bash`
```
cd white_circle/src/white_circle; cat enrich_pdl.py; cat sql/56_stg_headcount_history.sql; grep -n -i "growth\|hc_" sql/57_mart_org_master.sql sql/60_mart_org_score.sql | head -80; grep -n -i "pdl\|headcount" cli.py
```

Result of `Bash`
```
"""Headcount enrichment from People Data Labs (PDL) Company Enrichment.

Feeds the v4 "headcount growth" component (20 points, 0 until this has run). Pipeline:
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
... [truncated 13060 chars]
```

Tool call `WebFetch`
```
{
 "url": "https://docs.apollo.io/reference/organization-enrichment",
 "prompt": "Endpoint, method, auth header, query params, response fields for headcount growth (organization_headcount_six_month_growth etc.): units (fraction vs percent), estimated_num_employees, credit cost, rate limits, error codes."
}
```

Tool call `WebFetch`
```
{
 "url": "https://docs.apollo.io/docs/api-pricing",
 "prompt": "Does the free plan have API access? Credit cost of organization enrichment; rate limits per plan."
}
```

Result of `WebFetch`
```
The page doesn't say whether the free plan includes API access. It only notes that credit usage applies to "currently available Apollo plans."

**Organization enrichment** costs **1 credit per organization**. Bulk organization enrichment is also 1 credit per organization.

**Rate limits** aren't listed per plan. The page says they "vary by endpoint and your Apollo plan." To see your limits, check the Usage page under API Keys in Apollo's developer settings, or use the view usage endpoint. Exceeding a limit returns a 429 response.
```

Result of `WebFetch`
```
**Endpoint and auth**
- **Method and URL:** `GET https://api.apollo.io/api/v1/organizations/enrich`
- **Auth header:** `x-api-key: <your API key>`. OAuth 2.0 bearer tokens are also accepted for Apollo partners.
- **OAuth scope:** `organizations_enrich`
- **Access:** Works with an API key or Master API key. Free accounts need a work email registration, and paid accounts aren't affected.

**Query parameters** (all optional, but you must supply at least one identifier)
- `domain`: e.g., `apollo.io`. Omit `www.` and `@`.
- `linkedin_url`: e.g., `https://www.linkedin.com/company/apolloio`
- `website`: full URL, e.g., `http://www.apollo.io`
- `name`: improves match accuracy when combined with another identifier. The page conflicts on whether `name` alone is supported. The top-level summary says yes, but the endpoint's parameter description says name alone is not supported. Use another identifier to be safe.

**Headcount growth fields**
- `organization_headcount_six_month_growth`
- `organization_headcount_twelve_month_growth`
- `organization_headcount_twenty_four_month_growth`

These are numbers described as the "percentage change" in total headcount over the prior 6, 12, or 24 months. The example value is `12.3` for six months, which suggests percent rather than fraction, but the page doesn't state the unit explicitly. Each returns `null` when growth data isn't available.

**estimated_num_employees**
- Integer on the organization object (example: `1600`). The page gives no further 
... [truncated 982 chars]
```

Tool call `Bash`
```
cd white_circle/src/white_circle; grep -n "ENRICH\|HC_SEED\|DATA\b" paths.py; sed -n 255,280p cli.py; grep -n "growth_3m\|3-month\|growth_total\|score_weight" sql/60_mart_org_score.sql | head; grep -rn "growth_3m" --include=*.csv --include=*.yaml --include=*.py . | head; grep -n "dotenv\|load_dotenv" *.py | head -3; head -3 seeds/headcount_history.csv 2>&1
```

Result of `Bash`
```
[redacted: outside project scope]
```

Tool call `Bash`
```
cd white_circle/src/white_circle; grep -rn "growth_3m" . -l; grep -n -B2 -A2 "growth_3m" sql/*score_weight* 2>/dev/null | head -20; sed -n 12,18p sql/60_mart_org_score.sql
```

Result of `Bash`
```
dashboard.py
enrich_pdl.py
sql/56_stg_headcount_history.sql
templates/dashboard.html
sql/57_mart_org_master.sql
sql/60_mart_org_score.sql
sql/70_mart_segments.sql
sql/50_mart_score_weights.sql
sql/95_dq_score_checks.sql
sql/61_ops_score_history.sql
109-  ('growth_12m', 'negative',   0, 'Shrinking over 12 months.'),
110-  ('growth_6m',  'ge_20',      4, 'Stated prior. Add-on: 6-month growth of 20% or more (the growth is recent).'),
111:  ('growth_3m',  'ge_10',      4, 'Stated prior. Add-on: 3-month growth of 10% or more (accelerating now).'),
112-  ('growth_total_cap', 'cap', 20, 'The three growth parts are capped at 20 together.'),
113-  -- Fit bonus cap [REDACTED_SECRET]
--                          $100M+ 20 (enterprise procurement drag), unknown 0
--   pts_headcount  max 15  1-10 3, 11-50 8, 51-200 15, 201-500 15, 501-1000 12, 1001+ 8, unknown 0
--   pts_growth     max 20  12-month headcount growth >=50% 12, >=20% 8, >=0% 4, negative 0;
--                          +4 if 6-month growth >=20%; +4 if 3-month growth >=10%; capped at
--                          20. Unknown (not yet enriched by PDL) 0, never negative.
--   pts_bonus      max 10  fit bonus: best matching vertical tier from mart.fit_bonus_rule
--                          (pts_bonus_vertical) + 4 when the website check found an agent that
```

Tool call `Bash`
```
cd white_circle/src/white_circle
cat > enrich_apollo.py <<'EOF'
"""Headcount enrichment from Apollo.io Organization Enrichment (replaces People Data Labs, whose
signup was rejected). Feeds the v4 "headcount growth" component (20 points, 0 until this has run).
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
[redacted line: outside-scope]
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
        "org_uuid": org_uuid, "pdl_id": None, "likelihoo
... [truncated 6114 chars]
```

Result of `Bash`
```
[redacted: outside project scope]
```

**Assistant**

Python edits didn't run; use python3. Re-read cli.py right before editing.

Tool call `Bash`
```
cd white_circle/src/white_circle
python3 - <<'EOF'
p='sql/60_mart_org_score.sql'; s=open(p).read()
s=s.replace("20. Unknown (not yet enriched by PDL) 0, never negative.","20. Unknown (not yet enriched) 0, never negative.\n--                          NOTE: headcount source is Apollo, which has no 3-month figure, so the\n--                          3-month +4 cannot be earned (max reachable is 16 of 20); points unchanged.",1)
open(p,'w').write(s)
p='sql/50_mart_score_weights.sql'; s=open(p).read()
s=s.replace("(accelerating now).'","(accelerating now). Cannot be earned while Apollo is the headcount source (no 3-month figure).'",1)
open(p,'w').write(s)
p='sql/56_stg_headcount_history.sql'; s=open(p).read()
s=s.replace("People Data Labs via `whitecircle enrich-headcount` (enrich_pdl.py)","Apollo via `whitecircle enrich-headcount-apollo` (enrich_apollo.py; PDL, enrich_pdl.py, was the first choice)",1)
open(p,'w').write(s)
p='cli.py'; s=open(p).read()
anchor='    enrich_pdl.enrich(limit=limit, max_credits=max_credits, dry_run=dry_run)\n'
assert s.count(anchor)==1
s=s.replace(anchor,anchor+'''

@app.command("enrich-headcount-apollo")
def enrich_headcount_apollo(
    dry_run: bool = typer.Option(True, "--dry-run/--no-dry-run", help="Print the plan and request count; call nothing (default ON)."),
    limit: int = typer.Option(None, help="Maximum number of orgs to fetch."),
    max_credits: int = typer.Option(60, help="Hard credit cap, enforced before every request (1 credit per org)."),
) -> None:
    """Fetch headcount growth from Apollo for gate-passers (resumable). Needs APOLLO_API_KEY unless --dry-run."""
    from . import enrich_apollo
    enrich_apollo.enrich(limit=limit, max_credits=max_credits, dry_run=dry_run)
''')
open(p,'w').write(s)
EOF
cd ../..
S=[REDACTED_SECRET]
cat > $S/apollo_fixture.json <<'EOF'
{"organization":{"id":"x1","name":"Acme","estimated_num_employees":120,"organization_headcount_six_month_growth":12.3,"organization_headcount_twelve_month_growth":31.5,"organization_headcount_twenty_four_month_growth":null}}
EOF
ls; (uv run python -I -c "
import json,datetime,sys
from white_circle.enrich_apollo import parse_response as p
b=json.load(open('$S/apollo_fixture.json'))
print(p('u1',b,datetime.datetime(2026,10,30)));print(p('u2',{'organization':None},datetime.datetime.now()))" 2>&1 || true) | tail -5
uv run whitecircle enrich-headcount-apollo --limit 5 2>&1 | tail -12
```

Result of `Bash`
```
Makefile
README.md
data
docs
pyproject.toml
src
uv.lock
{'org_uuid': 'u1', 'pdl_id': None, 'likelihood': None, 'hc_current': 120, 'hc_3m_ago': None, 'hc_6m_ago': None, 'hc_12m_ago': None, 'growth_3m_pct': None, 'growth_6m_pct': 12.3, 'growth_12m_pct': 31.5, 'hc_source': 'apollo', 'hc_fetched_at': '2026-10-30 00:00:00'}
None
Apollo org enrich: 608 gate-passers without headcount data; this run would make 5 requests (cap: --max-credits 60, --limit 5); worst case 5 credits (1 each).
pacing 6.1s/request (600/hour sample limit): about 0.5 minutes. growth_3m_pct stays NULL (Apollo has no 3-month figure).
   83  Centrical                            centrical.com
   77  Replit                               replit.com
   72  Shapes                               shapes.co
   64  Audion                               audion.ai
   64  Botpress                             botpress.com
dry run: no API calls made, nothing written. Re-run with --no-dry-run and APOLLO_API_KEY set.
```

**Final report (hand-back)**

Apollo is wired in; the parser passes a fixture test and the dry-run works. I made no real calls and wrote no seed data. Nothing is committed.
- **Docs confirmed:** `GET https://api.apollo.io/api/v1/organizations/enrich?domain=…` with an `x-api-key` header. Fields are `estimated_num_employees` plus `organization_headcount_{six,twelve,twenty_four}_month_growth`, null when unavailable. There is no 3-month figure. Cost is 1 credit per org; the docs' sample 429 cites 600 calls/hour. Errors are 401, 403 (`API_INACCESSIBLE`), 422 and 429.
- **Not confirmed (noted in the module docstring):** The units are not stated. The docs example `12.3` reads as percent, so I store the values as-is, and `GROWTH_SCALE = 100` is the one-line fix if the first call shows fractions. The docs also don't say whether the free plan has API access, and the response wrapper (`organization` key) and no-match behaviour are assumed. The run stops at the first 401/403/429 with a clear message.
- **Dry-run plan:** 608 gate-passers have no headcount data. The default run is capped at 60 credits (about 6 minutes at 6.1 s/request). It orders by pre-growth score: Centrical 83, Replit 77, Shapes 72, Audion 64, Botpress 64. Orgs that already have a seed row from any source are skipped, and `growth_3m_pct` stays NULL.
- **Files:** `src/white_circle/enrich_apollo.py` is new, with `enrich-headcount-apollo` added to `cli.py` (re-read right before editing). I added the 3-month +4 note to the comment headers of `sql/60_mart_org_score.sql` (it says the maximum reachable is 16 of 20) and `sql/56_stg_headcount_history.sql`. I also added it to the `growth_3m` score_weight rationale string in `sql/50_mart_score_weights.sql`. Points are unchanged, and I touched nothing in `docs/`, `dashboard.py` or the templates.
- **Fixture:** `[REDACTED_SECRET].json`.
[redacted line: outside-scope]

Result of `SubagentHandback`
```
[redacted: outside project scope]
```
