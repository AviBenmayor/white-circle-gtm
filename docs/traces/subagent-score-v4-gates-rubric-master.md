# Subagent trace: Score v4: gates + rubric + master

A delegated subagent (general-purpose). Its prompt, its tool calls and results, and its final report. Same redaction rules as the main session.

## Turn 1 - User (2026-10-30 14:35:53 UTC)

Restructure the White Circle take-home scoring into score v4 at white_circle. The owner redesigned the model: exclusion gates first, then a fixed points rubric. Read first: all of src/white_circle/sql/ (00–95), cli.py, obs.py, paths.py, dashboard.py, docs/whitecircle-research.md (product, landing pages, named customers), docs/data-profile.md. Keep the style: numbered SQL files whose header comments explain every rule and WHY in plain words. Reviewers read the SQL, and the owner wants it "deterministic and defensible".

0. Before changing anything, copy docs/deliverables/top50.csv to docs/deliverables/archive/top50_v3.1.csv so the memo can show how the list changed between versions.

1. MASTER TABLE `mart.org_master`, one row per org (3,000), the single source for gates and rubric:
   - all stg.organizations columns
   - funding joined on org uuid (LEFT JOIN, never drop orgs):
     - `rounds`: a LIST of STRUCT(announced_on, investment_type, is_equity, money_raised_usd, investor_count, lead_investor_names), ordered by date
     - all-round totals and equity-only totals
     - last equity round date, type and amount; first round date
     - months_since_last_equity relative to as_of 2026-10-29
   - verified review fields (llm_level and source, true vertical, is_agentic, site_status, evidence_quote)
   - best buyer contact, flags (services, competitor), region
   - headcount growth columns, left-joined from `stg.headcount_history` (created empty if no data): hc_current, hc_3m_ago, hc_6m_ago, hc_12m_ago, growth_3m_pct, growth_6m_pct, growth_12m_pct, hc_source, hc_fetched_at
   - add dq checks: one master row per org, and round counts reconcile with stg.funding_rounds

2. GATES `mart.org_gate`: one boolean column per gate, plus `first_failed_gate`, evaluated in this order:
   - is_closed
   - is_acquired
   - is_nonprofit
   - is_public (keep the separate Enterprise segment)
   - is_competitor
   - is_services_firm
   - dead_or_hijacked_site
   - not_ai: fails unless llm_level is 'strong' or 'nlp_only'. ML/analytics-only AI fails, because White Circle guards LLM inputs, outputs and actions. A verified 'no' fails.
   - industry_not_matched: passes only for these owner-chosen groups:
     - regulated core: fintech_banking, insurance, health, legal_compliance
     - AI-native builders: generic_tech / ai_platform whose product is an LLM or agent
     - verticals White Circle markets to: public_sector, education, hr_recruiting, ecommerce, gaming, creative_tools (and real estate if it exists in the map)
     - everything else fails: crypto_web3, consumer_wellness, finance_ops, security, media, other, etc. List every vertical and which side it lands on in the SQL header.
   Also create `mart.gate_funnel`: rows remaining after each gate, in order.

3. RUBRIC `mart.org_score` (v4), only for orgs that pass all gates. Fixed points, owner weights 40/25/15/20 = 100:
   - Funding recency (40), from the last EQUITY round: ≤6 months 40, ≤12 32, ≤18 24, ≤24 16, ≤36 8, older 2, none or unknown 0.
   - Revenue range (25), using the decoded bands: <$1M 5, $1–10M 15, $10–50M 25, $50–100M 25, $100M+ 20 (enterprise procurement drag), unknown 0.
   - Headcount (15): 1–10 3, 11–50 8, 51–200 15, 201–500 15, 501–1000 12, 1001+ 8, unknown 0.
   - Headcount growth (20): 12-month growth ≥50% 12, 20–50% 8, 0–20% 4, negative 0; plus +4 if 6-month growth ≥20%; plus +4 if 3-month growth ≥10%; capped at 20; unknown 0.
   - Fit bonus (0–10, the owner's words: "small fit bonus to have white circle have already signaled by their landing pages and public messaging. we want to use what they have already done as baseline for how we shape our response"):
     - Derive it ONLY from docs/whitecircle-research.md, and cite the section for each mapping in a `mart.fit_bonus_rule` VALUES table (vertical/feature, points, evidence).
     - Proposed tiers: the category of a named customer or case study (AI-native app builders → Lovable; digital banks/fintech → the unnamed neobanks in their press) 6; homepage tab verticals 5; dedicated landing-page verticals 3; press-only mentions (e.g. legal) 3; plus +4 for verified is_agentic (they position on agents taking actions).
     - Cap the bonus at 10. If the research doesn't support a mapping, give it 0 and say so.
   - Total = rubric + bonus, out of 110. Keep every component as its own column, and keep reason_1..3 in plain words (for verified orgs, reason_1 stays "Ships: <llm_use>").
   - Ordering and ties: total desc, then region_priority (eu_uk and us_ca = 1, others = 2; the owner says White Circle sells in Europe and North America, so region is a TIE-BREAKER only and earns no points), then data_confidence desc, then name.
   - score_version = 'v4'. Replace the old weight table with `mart.score_weight` v4 rows (component, level, points, rationale).

4. SEGMENTS AND TIERS:
   - Keep the named segments (Regulated GenAI, AI-native builders, Marketed verticals, Enterprise, Competitor, Out: <first_failed_gate>).
   - Re-pick tier cutoffs on the v4 distribution and document why.
   - mart.top50: gate-passers only, keeping the rule that every top-50 org needs a verified ships='yes' (medium/high confidence) and a live site.
   - mart.verify_next: gate-passers that aren't verified, by score.

5. HEADCOUNT ENRICHMENT `whitecircle enrich-headcount` (src/white_circle/enrich_pdl.py):
   - People Data Labs Company Enrichment API, key from env PDL_API_KEY.
   - Check the real API with WebFetch on docs.peopledatalabs.com: the company enrich endpoint, the params (website/name), the response fields for headcount history (e.g. employee_count_by_month, employee_growth_rate with 3/6/12-month keys, or whatever actually exists), credit cost, and the free-tier limit. Write down what you confirmed vs assumed in the module docstring.
   - Flags: --dry-run (default ON; prints the plan and request count without calling), --limit N, --max-credits enforced in code (default 25).
   - Order: gate-passers by pre-growth score, skipping already-fetched orgs (resumable).
   - Raw JSON responses go to data/enrich/pdl/<org_uuid>.json.
   - Parsed rows go to src/white_circle/seeds/headcount_history.csv (committed provenance).
   - Every call is logged via obs.record_api_call.
   - There is NO key yet, so test only the dry-run path and the parser, using a hand-written fixture shaped like the documented response, placed in the scratchpad [REDACTED_SECRET]. Do not invent data into the seed file.

6. DASHBOARD (dashboard.py and the template, minimal edits):
   - a gate funnel chart
   - the v4 rubric table, plus the fit-bonus rule table with evidence
   - the verify_next queue
   - top-50 components shown as v4 columns
   - growth columns showing "not yet enriched" when blank
   Then regenerate docs/dashboard/index.html.

7. DQ: assertions for "every top-50 org passes all gates", "component sum = total", "bonus ≤ 10", "rubric max = 100", and "funnel is monotonic". Run from scratch (delete only data/white_circle.duckdb): load, merge-reviews, build, dq, segments, top50, dashboard, then `enrich-headcount --dry-run`. Everything must be clean.

Don't commit, and touch nothing outside white_circle/. Final reply, at most 20 lines:
- the gate funnel with counts at each step
- how many pass all gates, by segment
- the tier cutoffs
- the top 15 (name, total, rubric/bonus split, last equity round age, revenue band, headcount, region, verified use)
- v3.1 to v4 churn in the top 50, with 3 notable movers and why
- what PDL's docs confirmed (fields, cost, free limit)
- the dry-run plan (how many orgs, credits)
- anything that looks wrong

Tool call `Bash`
```
mkdir -p docs/deliverables/archive && cp docs/deliverables/top50.csv docs/deliverables/archive/top50_v3.1.csv && ls; ls src/white_circle src/white_circle/sql src/white_circle/seeds docs; wc -l src/white_circle/*.py src/white_circle/sql/* docs/*.md; cat Makefile | head -40
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
docs:
assignment.md
crm-data-model.md
dashboard
data-profile.md
deliverables
part2-system-design.md
traces
whitecircle-research.md

src/white_circle:
__init__.py
__pycache__
cli.py
dashboard.py
obs.py
paths.py
seeds
sql
templates
traces.py

src/white_circle/seeds:
company_review.csv

src/white_circle/sql:
00_schemas.sql
10_stg_organizations.sql
20_stg_category_map.sql
25_stg_org_category.sql
30_stg_funding_rounds.sql
35_stg_org_funding.sql
40_stg_contacts.sql
50_mart_score_weights.sql
52_stg_company_review.sql
55_mart_org_features.sql
60_mart_org_score.sql
70_mart_segments.sql
80_crm_export.sql
90_dq_checks.sql
95_dq_score_checks.sql
       1 src/white_circle/__init__.py
     257 src/white_circle/cli.py
     139 src/white_circle/dashboard.py
     112 src/white_circle/obs.py
      16 src/white_circle/paths.py
     386 src/white_circle/traces.py
      17 src/white_circle/sql/00_schemas.sql
     177 src/white_circle/sql/10_stg_organizations.sql
     208 src/white_circle/sql/20_stg_category_map.sql
      33 src/white_circle/sql/25_stg_org_category.sql
      71 src/white_circle/sql/30_stg_funding_rounds.sql
      67 src/white_circle/sql/35_stg_org_funding.sql
      98 src/white_circle/sql/40_stg_contacts.sql
     139 src/white_circle/sql/50_mart_score_weights.sql
      72 src/white_circle/sql/52_stg_company_review.sql
     273 src/white_circle/sql/55_mart_org_features.sql
     132 src/white_circle/sql/60_mart_org_score.sql
  
... [truncated 639 chars]
```

Tool call `Bash`
```
cd white_circle/src/white_circle && cat sql/00_schemas.sql sql/30_stg_funding_rounds.sql sql/35_stg_org_funding.sql sql/50_mart_score_weights.sql sql/52_stg_company_review.sql
```

Tool call `Bash`
```
cd white_circle/src/white_circle && cat sql/55_mart_org_features.sql sql/60_mart_org_score.sql sql/70_mart_segments.sql
```

Result of `Bash`
```
-- 00_schemas.sql
-- Rebuilds the derived schemas from scratch on every `whitecircle build`.
--
--   raw  : untouched copy of the CSVs, every column VARCHAR (made by `whitecircle load`)
--   stg  : cleaned, typed, flagged tables (this folder)
--   dq   : data-quality check log, computed live from raw + stg
--   mart : the answer layer: score weights, org features, fit score, segments, top 50
--   ops  : audit trail of CLI runs and API calls (NOT dropped here; see obs.py)
--
-- Dropping stg, dq and mart makes the build idempotent: the result depends only on raw
-- and these SQL files, never on what a previous run left behind.
DROP SCHEMA IF EXISTS stg CASCADE;
DROP SCHEMA IF EXISTS dq CASCADE;
DROP SCHEMA IF EXISTS mart CASCADE;
CREATE SCHEMA stg;
CREATE SCHEMA dq;
CREATE SCHEMA mart;
-- 30_stg_funding_rounds.sql  ->  stg.funding_rounds  (one row per round, 1,854)
--
-- FIXES:
--  1. Typing: announced_on -> DATE, amounts -> DOUBLE via try_cast; failures would
--     show up as NULLs and be counted in dq.checks (there are none today).
--  2. money_raised_usd = 0 means "amount undisclosed", not "raised $0" (one row,
--     Adzact pre_seed). amount_usd is NULLIF(x, 0); money_raised_raw_usd keeps the
--     source value so the org-level total can still be reconciled exactly.
--  3. is_post_ipo: post_ipo_equity / post_ipo_debt / post_ipo_secondary are public
--     market transactions of listed companies (Accor 3.2B, Wix 1.0B). They are not
--     venture raises and wreck any avera
... [truncated 24206 chars]
```

Result of `Bash`
```
[redacted: outside project scope]
```

Tool call `Bash`
```
cd white_circle/src/white_circle && cat sql/55_mart_org_features.sql
```

Result of `Bash`
```
-- 55_mart_org_features.sql  ->  mart.org_features  (one row per org, all 3,000)
--
-- Turns the staging tables into the handful of decision-ready attributes the score
-- and the segments use. Nothing is scored here; this file only answers "what do we
-- know about this company". Everything starts FROM stg.organizations with LEFT JOINs:
-- 73% of orgs have no funding round and 65% no contact, and an inner join would
-- silently delete them from the universe.
--
-- llm_level (strong / nlp_only / ml_only / none): how close the product is to LLMs.
--   strong   a category token in stg.llm_signal_token (genai, agentic, chatbot,
--            virtual assistant, foundation model...) OR the description matches the
--            regex below. NOTE: the 'nlp' signal in that table is NOT strong here;
--            plain "Natural Language Processing" is the nlp_only tier (it predates
--            LLMs). Regex uses word boundaries so "gpt" does not hit "egypt" and
--            "agent" alone (real-estate agent, insurance agent) does not count: we
--            require "ai agent" / "agentic".
--   nlp_only NLP / speech / conversational / voice-AI tag or wording, nothing stronger.
--   ml_only  generic AI / ML tag (any 'ai_platform' sector token) or "AI" in text.
-- vertical: the highest-risk sector any category token maps to, in order
--   fintech_banking > insurance > health > legal_compliance > public_sector >
--   education > hr_recruiting > crypto_web3 > finance_ops > security > ecomm
... [truncated 18777 chars]
```

Tool call `Bash`
```
cd white_circle/src/white_circle && cat sql/60_mart_org_score.sql sql/70_mart_segments.sql
```

Tool call `Bash`
```
cd white_circle/src/white_circle && cat cli.py paths.py; sed -n 1,112p obs.py
```

Result of `Bash`
```
-- 60_mart_org_score.sql  ->  mart.org_score  (one row per org, all 3,000)
--
-- Fit score 0-100 = sum of components, each looked up in mart.score_weight (50_),
-- capped at 100. No point value is written in this file. One column per component
-- so a reviewer (or an AE asking "why is this #7?") can see exactly where the points
-- came from:
--   pts_llm        LLM product                       max 35
--   pts_regulated  regulated-sector risk x llm_factor max 25
--   pts_bonus      LLM x regulated interaction       max 10  (strong LLM AND is_regulated)
--   pts_capacity   = pts_recency + pts_stage + pts_round_size   max 10 + 6 + 4 = 20
--   pts_size       headcount                         max 10
--   pts_region     EU/UK > US/CA > other             max 5
--   pts_reach      best buyer persona on file        max 5
--   pts_agentic    v3: +3 when a website check found an action-taking agent AND a
--                  customer-facing LLM ('yes'); 0 for everyone not checked
-- v2: the base maxima add to exactly 100 (35+25+20+10+5+5); with the +10 bonus the
-- raw total can reach 110, so the cap at 100 matters for the very best accounts only.
-- v2 LLM GATE: regulated points are the sector's value (50_) times mart.llm_factor
-- (strong 1.0, nlp_only 0.5, ml_only 0.2, none 0), rounded to a whole point. A bank
-- with no AI product earns nothing for being a bank. The bonus is unchanged.
-- v3: llm_level, vertical and is_regulated come from mart.org_features, where a
-- confident webs
... [truncated 17886 chars]
```

Result of `Bash`
```
[redacted: outside project scope]
```

Tool call `Bash`
```
cd white_circle/src/white_circle && cat dashboard.py; ls templates; wc -l templates/*; cat sql/95_dq_score_checks.sql; sed -n 1,40p sql/90_dq_checks.sql; tail -30 sql/90_dq_checks.sql; cat sql/80_crm_export.sql | head -80
```

Tool call `Bash`
```
cat docs/whitecircle-research.md; sed -n 1,60p src/white_circle/sql/20_stg_category_map.sql; grep -n "sector" src/white_circle/sql/20_stg_category_map.sql | awk -F"'" '{print $0}' | grep -o "'[a-z_]*')" | sort | uniq -c
```

Result of `Bash`
```
"""Export the pipeline results from DuckDB and render docs/dashboard/index.html.

Read-only: one short connection, closed before the page is written. The page is a
single self-contained HTML file with the data embedded as JSON. Columns added later
by the score v3 work (llm_level_source, verified_llm_use, is_agentic, evidence_quote,
vertical_source, evidence source/url) are picked up from whichever mart table holds
them; when absent the page simply hides them.
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

import duckdb

from .paths import DB, ROOT

TEMPLATE = Path(__file__).resolve().parent / "templates" / "dashboard.html"
OUT = ROOT / "docs" / "dashboard" / "index.html"

V3_COLS = ["llm_level_source", "verified_llm_use", "is_agentic", "evidence_quote", "vertical_source",
           "evidence_url", "evidence_source", "source_url", "evidence_source_url"]
TIERS = ["Tier 1", "Tier 2", "Tier 3", "Nurture"]
CORE_SEGMENTS = ["Regulated GenAI", "AI-native builders", "Regulated AI-adjacent", "Low fit", "Not deploying AI"]
OTHER_SEGMENTS = ["Enterprise", "Competitor", "Out: closed or acquired", "Out: nonprofit"]


def _rows(con, sql: str, params: list | None = None) -> list[dict]:
    cur = con.execute(sql, params or [])
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def _exists(con, table: str) -> bool:
    s, t = table.split(".")
    return con.execute("SELECT
... [truncated 25868 chars]
```

Result of `Bash`
```
# White Circle: company research for ICP definition

Researched 2026-10-30 (Tavily worked). Tags: [C] = confirmed on a cited page, [I] = inferred by me.
Sources are numbered, listed at the bottom.

## 1. What the product does

- One line: an "AI control" layer. Customers write plain-language policies, and White Circle's own models check every input, output and tool call against them in real time, then block, rewrite or escalate. [C] S1, S4, S5
- Four modules on the homepage: Test (find failure modes before users do, i.e. red teaming), Control (runtime guardrails across inputs, outputs, tools), Analyze (user and model behaviour over time, monitoring), Improve (tune prompts and models from live signals, labelled-feedback loop). [C] S1
- Also: audit logs and explanations of which policy fired, per-region/jurisdiction policies, user strike/ban system with appeals, user-level risk scoring, human review queue, custom natural-language metrics, Slack and webhook alerts. [C] S1, S2, S3
- Deployment: hosted SaaS API (single event endpoint, EU and US regions, `wceu-`/`wcus-` keys), "5 mins to integrate", 99.99% uptime claim, 150+ languages, text and image checking. Docs show integration guides for an AI support chatbot, a vibe-coding app and a coding assistant. [C] S1, S2, S3
- Self-hosting: the Test product page FAQ says on-prem/VPC is supported for strict-compliance enterprises. [C] S8 (older page, treat as less certain)
- Threats covered: prompt injection, jailbreaks, PII/data leakag
... [truncated 17455 chars]
```

Tool call `Bash`
```
ls data data/* | head -30; grep -o "'[a-z_]*')" src/white_circle/sql/20_stg_category_map.sql | sort | uniq -c | sort -rn | head -40; python3 - <<'E'
import csv,collections
r=list(csv.DictReader(open('src/white_circle/seeds/company_review.csv')))
print(len(r));print(collections.Counter(x['true_vertical'] for x in r))
print(collections.Counter(x['ships_customer_facing_llm'] for x in r))
E
cat src/white_circle/sql/25_stg_org_category.sql | tail -20; sed -n 1,60p src/white_circle/sql/10_stg_organizations.sql | head -5; grep -n "employees\|revenue\|AS " src/white_circle/sql/10_stg_organizations.sql | sed -n 1,80p
```

Result of `Bash`
```
data/white_circle.duckdb
white_circle.duckdb
contacts.csv
funding_rounds.csv
organizations.csv
  FROM raw.organizations WHERE nullif(trim(categories), '') IS NOT NULL
  FROM raw.organizations WHERE nullif(trim(category_groups), '') IS NOT NULL),
-- 10_stg_organizations.sql  ->  stg.organizations  (one row per company, 3,000)
-- Source: raw.organizations (all VARCHAR). Principle: never delete a row here.
[128 other listing lines redacted: outside project scope]
```

Tool call `Bash`
```
sed -n 40,64p src/white_circle/sql/10_stg_organizations.sql; grep -in "real estate\|real_estate\|property" src/white_circle/sql/20_stg_category_map.sql | head; sed -n 1,60p docs/data-profile.md; grep -n "revenue" docs/data-profile.md | head
```

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

Result of `Bash`
```
-- 10. short_description is capped at 140 chars by the source and has non-breaking
--     spaces; we replace U+00A0 with a space and flag description_truncated.
-- 11. categories / category_groups kept raw here; see 20_/25_ for the long form.
CREATE TABLE stg.organizations AS
WITH
emp(code, employees_min, employees_max, employees_label, employees_order) AS (VALUES
  ('c_00001_00010',     1,    10, '1-10',          1),
  ('c_00011_00050',    11,    50, '11-50',         2),
  ('c_00051_00100',    51,   100, '51-100',        3),
  ('c_00101_00250',   101,   250, '101-250',       4),
  ('c_00251_00500',   251,   500, '251-500',       5),
  ('c_00501_01000',   501,  1000, '501-1,000',     6),
  ('c_01001_05000',  1001,  5000, '1,001-5,000',   7),
  ('c_05001_10000',  5001, 10000, '5,001-10,000',  8),
  ('c_10001_max',   10001,  NULL, '10,001+',       9)),
rev(code, revenue_min_usd, revenue_max_usd, revenue_label, revenue_order) AS (VALUES
  ('r_00000000',           0,    1000000, 'under $1M',     1),
  ('r_00001000',     1000000,   10000000, '$1M-$10M',      2),
  ('r_00010000',    10000000,   50000000, '$10M-$50M',     3),
  ('r_00050000',    50000000,  100000000, '$50M-$100M',    4),
  ('r_00100000',   100000000,  500000000, '$100M-$500M',   5),
  ('r_00500000',   500000000, 1000000000, '$500M-$1B',     6),
  ('r_01000000',  1000000000,10000000000, '$1B-$10B',      7),
  ('r_10000000', 10000000000,       NULL, '$10B+',         8)),
-- local parts that mean "a shared mailbox", no
... [truncated 6644 chars]
```

Tool call `WebFetch`
```
{
 "url": "https://docs.peopledatalabs.com/docs/company-enrichment-api",
 "prompt": "Company Enrichment API: endpoint URL, auth header, query params (website, name, profile, min_likelihood, pretty, titlecase), response fields related to employee count history / growth (employee_count_by_month, employee_growth_rate, employee_count), likelihood, credit cost per successful match, 404 behaviour, free tier limits. Quote exact field names."
}
```

Tool call `WebFetch`
```
{
 "url": "https://docs.peopledatalabs.com/docs/company-schema",
 "prompt": "Find fields employee_count, employee_count_by_month, employee_growth_rate, inferred_revenue, and their exact structure/keys (e.g. growth rate keys 3, 6, 12 months). Quote exact names and examples."
}
```

Tool call `WebFetch`
```
{
 "url": "https://docs.peopledatalabs.com/docs/credit-pricing",
 "prompt": "Credits per company enrichment record, free plan credit limits per month for company enrichment, rate limits."
}
```

Result of `WebFetch`
```
The server returned HTTP 404 Not Found.

The response body was not retrieved. If this URL requires authentication, use an authenticated tool (e.g. `gh` for GitHub, or an MCP-provided fetch tool) instead of WebFetch.
```

Result of `WebFetch`
```
The page you provided is only the overview and index for the Company Enrichment API, so it doesn't include the details you asked for: the endpoint URL, auth header, query parameters, employee count fields, likelihood, credit cost, 404 behavior, or free tier limits.

It does say the API "lets you enrich data on a company by performing a one-to-one match" with company profiles, and that after a match you can access "all the fields in our Company Schema."

The index points to other pages that likely cover what you need:

- **Reference**: technical specifications and usage constraints
- **Input Parameters**: the input parameters the API supports
- **Output Response**: the output response object
- **FAQs**: commonly asked questions and other good-to-know information

If you share the content of those pages, I can pull together the specific details.
```

Result of `WebFetch`
```
## `employee_count`

- **Data Type:** `Integer (>= 0)`
- **Description:** "The current number of employees working at the company based on our number of profiles."
- **Calculation:** Counts profiles whose `experience.company.id` matches the company, with a non-null `job_start_date` and no end date.
- **Example:** `"employee_count": 78`

## `employee_count_by_month`

- **Data Type:** `Object`
- **Keys:** Months in `YYYY-MM` format, with integer values.
- **Description:** "The number of employees at the end of each month."
- **Range:** Starts at the first associated employee's start date or January 1, 2010, whichever is later.
- **Example:**
  `` `json
  "employee_count_by_month": {
    "2021-07": 84,
    "2021-08": 86,
    "2021-09": 84
  }
  `` `

## `employee_growth_rate`

- **Data Type:** `Object`
- **Keys and types:** `3_month`, `6_month`, `12_month`, `24_month`, each a `Float`.
- **Description:** "The percentage increase in total headcount from N months prior."
- **Calculation:** `(current_employee_count / previous_employee_count) - 1`, rounded to four decimal places. It can be negative, and it is `null` if the company had zero employees or did not exist at the start of the window.
- **Example:**
  `` `json
  "employee_growth_rate": {
    "3_month": 0.0595,
    "6_month": 0.0723,
    "12_month": 0.8542,
    "24_month": 1.4722
  }
  `` `

## `inferred_revenue`

- **Data Type:** `Enum (String)`
- **Description:** "Company's estimated annual revenue range in US dollars."
- **Sou
... [truncated 586 chars]
```

Tool call `WebFetch`
```
{
 "url": "https://docs.peopledatalabs.com/docs/input-parameters-company-enrichment-api",
 "prompt": "Endpoint URL, auth (X-Api-Key header), params (website, name, profile, ticker, pdl_id, min_likelihood, required, titlecase), and example request. Quote exactly."
}
```

Tool call `WebFetch`
```
{
 "url": "https://docs.peopledatalabs.com/docs/billing-and-credits",
 "prompt": "How many credits does one Company Enrichment match cost? Are 404 no-match charged? Free plan limits for company enrichment per month. Rate limits."
}
```

Tool call `WebFetch`
```
{
 "url": "https://docs.peopledatalabs.com/docs/output-response-company-enrichment-api",
 "prompt": "Response shape: status, likelihood, fields at top level (are company fields top-level or nested under data?), 404 body. Quote exact JSON."
}
```

Result of `WebFetch`
```
The server returned HTTP 404 Not Found.

The response body was not retrieved. If this URL requires authentication, use an authenticated tool (e.g. `gh` for GitHub, or an MCP-provided fetch tool) instead of WebFetch.
```

Result of `WebFetch`
```
**Shape:** Company fields are top-level, not nested under `data`. The page says: "Unlike our other APIs, the profile fields for the Company Enrichment API are **NOT** contained in a top-level `data` object."

The example response is:

`` `json
{
  "status": 200,
  "name": "people data labs",
  "id": "tnHcNHbCv8MKeLh92946LAkX6PKg",
  ...,
  "likelihood": 6
}
`` `

- **`status`** (Integer): the API response code.
- **`likelihood`** (Integer, 1–10): confidence that the returned profile matches the requested company.
- **Profile fields** (e.g., `name`, `id`): top-level, per the [Company Schema]. Fields without data are `null`.
- **`matched`** (Array of strings): only included when `include_if_matched` is `true`.

**404 body:** The page does not show a 404 response body. It only links to an errors page for response codes.
```

Result of `WebFetch`
```
**Endpoint:** `GET https://api.peopledatalabs.com/v5/company/enrich`

**Authentication:** Send your API key in the `X-Api-Key` header. The docs say the key "must be included in either the request header or the api_key parameter."

**Parameters**

A request needs at least one of `pdl_id`, `name`, `ticker`, `website`, or `profile`.

| Parameter | Type | Description |
| :--- | :--- | :--- |
| `website` | String | The company's website, e.g., `google.com`. |
| `name` | String | The company's name, e.g., `Google, Inc.`. |
| `profile` | String | The company's social profile, e.g., `linkedin.com/company/google`. |
| `ticker` | String | The stock ticker, if publicly traded, e.g., `GOOGL`. |
| `pdl_id` | String | The PDL ID or `linkedin_slug`. If used with other match inputs, only `pdl_id` is used. |
| `min_likelihood` | Integer | Minimum match score, 1-10. Default is `2`. |
| `required` | String | Fields a response must include to count as a match, as a boolean statement, e.g., `location AND (website OR linkedin_url)`. |
| `titlecase` | Boolean | Default `false`. Set to `true` to title-case response text. Otherwise, text is lowercase. |

**Example request (cURL)**

`` `bash
curl -X GET -G \
  'https://api.peopledatalabs.com/v5/company/enrich' \
  -H 'X-[REDACTED_SECRET]' \
  --data-urlencode 'website=google.com' \
  --data-urlencode 'min_likelihood=5'
`` `
```

Tool call `WebFetch`
```
{
 "url": "https://docs.peopledatalabs.com/docs/reference-company-enrichment-api",
 "prompt": "Credit cost per match, whether 404 is charged, rate limits, free plan limits. Quote."
}
```

Tool call `WebFetch`
```
{
 "url": "https://www.peopledatalabs.com/pricing/company",
 "prompt": "Free plan: how many company enrichment credits/records per month? Pro plan price per company record? Is employee_count_by_month/growth included?"
}
```

Result of `WebFetch`
```
- **Cost per match:** The page says "We charge **per match**." It doesn't state a credit amount or price per match.
- **404 responses:** A 404 means no matching company was found, and billing is tied to matches. So a 404 should not incur a match charge, though the page doesn't state this explicitly.
- **Rate limits:** Free customers get 10 requests per minute. Paying customers get 1,000 per minute.
- **Free plan limits:** The page gives only the free rate limit. It doesn't list a total quota or monthly allowance for free accounts.
```

Result of `WebFetch`
```
- **Free plan:** Up to 100 records per month, described as "Up to 100 monthly records."
- **Pro plan price per company record:** The page doesn't list one. The Pro card shows $100/mo starting at 1,000 monthly records, but the comparison table says "Starting at 350 records / mo" and "Starting at $98 / mo," so the figures are inconsistent.
- **employee_count_by_month / growth:** The page doesn't mention these fields.
```

Tool call `Bash`
```
grep -rn "fit_score\|score_weight\|llm_factor\|mart\.\(org_score\|top50\)" --include=*.py --include=*.sql --include=*.html --include=Makefile --include=*.toml src Makefile pyproject.toml | grep -v "sql/\(50\|55\|60\|70\|95\)_" | head -30; grep -n "fit_score\|pts_\|weights\|cutoffs\|top50\|score_version" src/white_circle/templates/dashboard.html | head -80; cat pyproject.toml; git status --short . | head
```

Result of `Bash`
```
(eval):1: no matches found: --include=*.py
142:<section id="top50">
217:  kpi(fmt(M.tier1), "Tier 1 accounts", "Score " + (D.cutoffs[0]?.min_score ?? "") + " or more: AEs work now") +
220:  kpi(esc(M.score_version || "-"), "Score version", "Weights are a hypothesis, not a fit");
238:  const cuts = D.cutoffs.map(c => `${c.tier} from ${c.min_score}`).join(", ");
242:/* weights + stacked components */
243:const COMPS = [["pts_llm", "Ships an LLM product"], ["pts_regulated", "Regulated sector"], ["pts_bonus", "LLM x regulated bonus"],
244:  ["pts_capacity", "Buying capacity"], ["pts_size", "Team size"], ["pts_region", "Region"], ["pts_reach", "Reachable buyer"]];
251:    const ws = D.weights.filter(w => w.component === k).sort((a, b) => b.points - a.points);
257:  const el = $("comp-bars"); const mx = Math.max(...D.top50.map(r => r.fit_score), 100) * 1.0;
259:  D.top50.forEach(r => {
264:      `</div><div class="tot">${r.fit_score}</div>`;
274:opts("f-seg", [...new Set(D.top50.map(r => r.segment))].map(s => [s, s]), "All segments");
275:opts("f-tier", D.tiers.filter(t => D.top50.some(r => r.tier === t)).map(t => [t, t]), "All tiers");
276:opts("f-reg", [...new Set(D.top50.map(r => r.region_bucket))].map(s => [s, REG[s] || s]), "All regions");
287:  const rows = D.top50.filter(r => (!f.s || r.segment === f.s) && (!f.t || r.tier === f.t) && (!f.r || r.region_bucket === f.r));
288:  $("f-count").textContent = `${rows.length} of ${D.top50.length} shown`;
301:      <td><span class="ch
... [truncated 536 chars]
```

Tool call `Bash`
```
cd white_circle/src/white_circle/sql && cat > 50_mart_score_weights.sql <<'EOF'
-- 50_mart_score_weights.sql  ->  mart.params, mart.vertical_gate, mart.score_weight, mart.fit_bonus_rule
--
-- SCORE v4. THE ONE PLACE the scoring opinion lives. The model has two stages and the
-- owner designed both:
--   1. EXCLUSION GATES (58_): yes/no rules. An org that trips ANY gate is out, and the
--      first gate it trips is recorded. Gates never score; they only remove.
--   2. A FIXED POINTS RUBRIC (60_) for the orgs that pass every gate. Every point value
--      is read from this file. No weights are written anywhere else.
-- Re-weighting = edit this file and run `whitecircle build`.
--
-- THE WEIGHTS ARE STATED PRIORS. They encode the owner's hypothesis about who buys an
-- AI-control product, they are NOT fitted to closed-won data (the extract has no
-- customer flag), and they are meant to be RECALIBRATED against realized results.
-- Example of what a recalibration would look like: if companies with strong recent
-- headcount growth but NO new funding round keep converting better than the funding
-- recency weight predicts, move points from "funding recency" to "headcount growth".
-- To make that possible, every scoring run is appended to ops.score_history (61_) with
-- the exact inputs, the points per component and a timestamp, so a past ranking can be
-- reproduced and compared with what actually happened.
--
-- RUBRIC (100 points) plus FIT BONUS (up to 10) = 110:
--   Funding recency   40  last EQUITY round: money recently raised means budget now
--   Revenue range     25  can they pay for an enterprise tool
--   Headcount         15  big enough to have a product + security team, small enough to buy quickly
--   Headcount growth  20  a company that is hiring fast is shipping fast (PDL; 0 until enriched)
--   Fit bonus      0-10  White Circle's own landing pages and press, see fit_bonus_rule below
-- REGION earns NO points. The owner says White Circle sells in Europe and North America,
-- so region only breaks ties in the ranking (eu_uk and us_ca first, see 60_).
--
-- mart.params: as_of is pinned (not current_date) so the ranking never drifts with the
-- day it is run. The snapshot's latest round is 2026-06-20.
CREATE TABLE mart.params AS
SELECT DATE '2026-10-29' AS as_of, 'v4' AS score_version;

-- mart.vertical_gate: which industries pass gate 9 (industry_not_matched), and why.
-- The owner chose these groups. "Vertical" is the org's industry after the website check
-- (verified) or, if never checked, after the Crunchbase tags (55_). 'ai_native' is not a
-- Crunchbase industry: 57_ assigns it to an org that SHIPS an LLM / agent as its product
-- and sits in a horizontal sector (generic_tech / ai_platform / devtools) instead of an
-- industry, i.e. the Lovable-style builders.
--   regulated core       fintech_banking, insurance, health, legal_compliance
--   AI-native builders   ai_native
--   verticals White Circle markets to (homepage tabs + landing pages, research section 2):
--                        public_sector, education, hr_recruiting, ecommerce, gaming,
--                        creative_tools, real_estate
--   everything else FAILS: crypto_web3, consumer_wellness, finance_ops, security, media,
--                        generic_tech (a generic software company that does NOT ship an
--                        LLM product), other.
-- Limits of the tags: the shared taxonomy files media, commerce, logistics, travel and
-- real estate under 'other' (55_ keeps only the 14 sectors above), so an UNVERIFIED org
-- in those sectors lands in 'other' and fails, which is the owner's intent for media and
-- other; real_estate is listed so the rule is visible, but no org can reach it because
-- real estate is not separable from physical_economy in the map (20_). Verified orgs
-- carry the reviewer's true_vertical and can land in any row.
CREATE TABLE mart.vertical_gate AS
SELECT * FROM (VALUES
  ('fintech_banking',  'regulated core
... [truncated 8966 chars]
```

Result of `Bash`
```
PreToolUse:Bash hook error: PROVENANCE GATE: this write adds owner-ruling language ('owner ruling/ruled/decided/approved/click…') but quotes no owner words. Rulings must trace to the owner. Include a verbatim quote (in double quotes, ≥5 words) from something the owner typed this session, or from a deliberate (non-default) button answer. Button picks that were all '(Recommended)' do NOT count. If the owner has not actually ruled, write it as 'PROPOSED, awaiting owner' instead.
```

Tool call `Bash`
```
cd white_circle/src/white_circle/sql && cat > 50_mart_score_weights.sql <<'EOF'
-- 50_mart_score_weights.sql  ->  mart.params, mart.vertical_gate, mart.score_weight, mart.fit_bonus_rule
--
-- SCORE v4. THE ONE PLACE the scoring opinion lives. The model has two stages:
--   1. EXCLUSION GATES (58_): yes/no rules. An org that trips ANY gate is out, and the
--      first gate it trips is recorded. Gates never score; they only remove.
--   2. A FIXED POINTS RUBRIC (60_) for the orgs that pass every gate. Every point value
--      is read from this file. No weights are written anywhere else.
-- Re-weighting = edit this file and run `whitecircle build`.
--
-- THE WEIGHTS ARE STATED PRIORS. They encode a hypothesis about who buys an AI-control
-- product, they are NOT fitted to closed-won data (the extract has no customer flag),
-- and they are meant to be RECALIBRATED against realized results.
-- Example of what a recalibration would look like: if companies with strong recent
-- headcount growth but NO new funding round keep converting better than the funding
-- recency weight predicts, move points from "funding recency" to "headcount growth".
-- To make that possible, every scoring run is appended to ops.score_history (61_, shown
-- as mart.score_history) with the exact inputs, the points per component and a
-- timestamp, so a past ranking can be reproduced and compared with what happened.
--
-- RUBRIC (100 points) plus FIT BONUS (up to 10) = 110:
--   Funding recency   40  last EQUITY round: money recently raised means budget now
--   Revenue range     25  can they pay for an enterprise tool
--   Headcount         15  big enough to have a product + security team, small enough to buy quickly
--   Headcount growth  20  a company that is hiring fast is shipping fast (PDL; 0 until enriched)
--   Fit bonus      0-10   White Circle's own landing pages and press, see fit_bonus_rule below
-- REGION earns NO points. White Circle sells in Europe and North America, so region
-- only breaks ties in the ranking (eu_uk and us_ca first, see 60_).
--
-- mart.params: as_of is pinned (not current_date) so the ranking never drifts with the
-- day it is run. The snapshot's latest round is 2026-06-20.
CREATE TABLE mart.params AS
SELECT DATE '2026-10-29' AS as_of, 'v4' AS score_version;

-- mart.vertical_gate: which industries pass gate 9 (industry_not_matched), and why.
-- "Vertical" is the org's industry after the website check (verified) or, if never
-- checked, after the Crunchbase tags (55_). 'ai_native' is not a Crunchbase industry:
-- 57_ assigns it to an org that SHIPS an LLM / agent as its product and sits in a
-- horizontal sector (generic_tech / ai_platform / devtools) instead of an industry,
-- i.e. the Lovable-style builders.
--   regulated core       fintech_banking, insurance, health, legal_compliance
--   AI-native builders   ai_native
--   verticals White Circle markets to (homepage tabs + landing pages, research section 2):
--                        public_sector, education, hr_recruiting, ecommerce, gaming,
--                        creative_tools, real_estate
--   everything else FAILS: crypto_web3, consumer_wellness, finance_ops, security, media,
--                        generic_tech (generic software that does NOT ship an LLM
--                        product), other.
-- Limits of the tags: the shared taxonomy files media, commerce, logistics, travel and
-- real estate under 'other' (55_ keeps only 14 sectors), so an UNVERIFIED org in those
-- sectors lands in 'other' and fails (right for media and other). real_estate is listed
-- so the rule is visible, but no org can reach it because real estate is not separable
-- from physical_economy in the map (20_). Verified orgs carry the reviewer's
-- true_vertical and can land in any row.
CREATE TABLE mart.vertical_gate AS
SELECT * FROM (VALUES
  ('fintech_banking',  'regulated core',     TRUE,  'Banking, payments, lending, neobank: the validated bank wedge (research section 2).'),
  ('
... [truncated 9200 chars]
```

Result of `Bash`
```
3
```

Tool call `Bash`
```
cd white_circle/src/white_circle/sql && cat > 56_stg_headcount_history.sql <<'EOF'
-- 56_stg_headcount_history.sql  ->  stg.headcount_history  (one row per ENRICHED org)
--
-- Headcount over time is NOT in the Crunchbase extract (only a size band). It comes from
-- People Data Labs via `whitecircle enrich-headcount` (enrich_pdl.py), which writes the
-- committed seed src/white_circle/seeds/headcount_history.csv. This file turns that CSV
-- into a typed table. There is no key yet, so today the seed does not exist: the table
-- is created EMPTY and every org simply has unknown growth (scored 0, never negative).
-- Same pattern as 52_: the first statement always runs, the second only when the seed
-- file exists (the marker line is read by `whitecircle build`).
--
-- Columns: hc_current and hc_Nm_ago are employee counts (current and N months before the
-- fetch month); growth_Nm_pct is the percentage change (25.0 means +25%), as PDL
-- reports it times 100; hc_source names the provider; hc_fetched_at is when it was pulled.
CREATE TABLE stg.headcount_history (
  org_uuid VARCHAR, pdl_id VARCHAR, likelihood INTEGER,
  hc_current INTEGER, hc_3m_ago INTEGER, hc_6m_ago INTEGER, hc_12m_ago INTEGER,
  growth_3m_pct DOUBLE, growth_6m_pct DOUBLE, growth_12m_pct DOUBLE,
  hc_source VARCHAR, hc_fetched_at TIMESTAMP);

-- @requires-hc-seed
INSERT INTO stg.headcount_history
SELECT nullif(trim(org_uuid), ''), nullif(trim(pdl_id), ''), try_cast(likelihood AS INTEGER),
       try_cast(hc_current AS INTEGER), try_cast(hc_3m_ago AS INTEGER), try_cast(hc_6m_ago AS INTEGER),
       try_cast(hc_12m_ago AS INTEGER),
       try_cast(growth_3m_pct AS DOUBLE), try_cast(growth_6m_pct AS DOUBLE), try_cast(growth_12m_pct AS DOUBLE),
       nullif(trim(hc_source), ''), try_cast(hc_fetched_at AS TIMESTAMP)
FROM read_csv('{{hc_seed}}', all_varchar=true, header=true, quote='"', escape='"')
WHERE nullif(trim(org_uuid), '') IS NOT NULL
QUALIFY row_number() OVER (PARTITION BY org_uuid ORDER BY hc_fetched_at DESC) = 1;
EOF
cat > 57_mart_org_master.sql <<'EOF'
-- 57_mart_org_master.sql  ->  mart.org_master  (one row per org, all 3,000)
--
-- THE SINGLE SOURCE for the gates (58_) and the rubric (60_). Nothing downstream joins
-- back to stg: if a gate or a point needs a fact, it is a column here. LEFT JOINs only,
-- starting from stg.organizations: 73% of orgs have no funding round and an inner join
-- would silently delete them. A dq check asserts exactly one row per org.
--
-- Column groups
--   * every stg.organizations column (including the decoded revenue_* and employees_*)
--   * funding, joined on org uuid from stg.funding_rounds:
--       rounds                      LIST of STRUCT(announced_on, investment_type, is_equity,
--                                   money_raised_usd, investor_count, lead_investor_names),
--                                   oldest first. money_raised_usd is the source value
--                                   (0 stays 0, "undisclosed"; see 30_).
--       all_rounds_count / _usd     every round incl. debt, grants and post-IPO
--       equity_rounds_count / _usd  venture equity only (round_group = 'equity_venture')
--       first_round_date            earliest round of any kind
--       last_equity_date/type/amount  the latest EQUITY round (same-day ties: later stage)
--       months_since_last_equity    whole months from that date to as_of (2026-10-29)
--     Why equity only for "recency": a loan or grant does not mean the company just
--     raised money to spend on AI rollout (see 55_ for the full list of what is excluded).
--   * the website check (stg.company_review via 55_): llm_level and its source, the
--     tag-based guess it replaced, true_vertical, is_agentic, site_status, evidence quote
--   * vertical: the org's industry for gate 9. It is 55_'s vertical with ONE refinement,
--     'ai_native' (see mart.vertical_gate in 50_): an org that ships an LLM (llm_level
--     'strong') and whose industry is horizontal. Verified o
... [truncated 4494 chars]
```

Result of `Bash`
```
(Bash completed with no output)
```

Tool call `Bash`
```
cd white_circle/src/white_circle/sql && cat > 58_mart_org_gate.sql <<'EOF'
-- 58_mart_org_gate.sql  ->  mart.org_gate, mart.gate_funnel
--
-- STAGE 1 OF SCORE v4: exclusion gates. Nine yes/no tests, evaluated IN THIS ORDER. An
-- org is a candidate only if it trips NONE of them. A gate that is TRUE means the org is
-- EXCLUDED by that rule. Every gate is computed for every org (so an org's full record
-- of failures is visible), and first_failed_gate records the first one in the order
-- below, which is the reason shown in the segment "Out: <gate>".
--
--   1 is_closed              Crunchbase says the company shut down. Nobody to sell to.
--   2 is_acquired            Acquired (or funding_stage m_and_a). The buyer is now the
--                            parent company; it is a different account and a different deal.
--   3 is_nonprofit           Non-profits buy on grants and do not match the commercial motion.
--   4 is_public              Publicly listed. NOT discarded as junk: these form the separate
--                            ENTERPRISE segment (long procurement, a different sales motion).
--   5 is_competitor          Sells guardrails / AI-safety / red-teaming / LLM security (tags,
--                            or the website check showed it). Partner or rival, never a lead.
--   6 is_services_firm       Agency, consultancy, dev shop: builds LLM apps FOR clients and
--                            does not run them at scale. A weak buyer however AI-heavy it sounds.
--   7 dead_or_hijacked_site  The website check found the site dead, unverifiable or hijacked.
--                            A June 2026 snapshot cannot show the company shut down or pivoted.
--   8 not_ai                 FAILS unless llm_level is 'strong' or 'nlp_only'. White Circle
--                            guards LLM inputs, outputs and actions, so the company must have
--                            language AI in production. Analytics / classic ML-only AI fails
--                            ('ml_only'), no AI signal fails ('none'), and a website check
--                            that said the company does NOT ship an LLM fails (it is
--                            downgraded to ml_only / none in 55_).
--   9 industry_not_matched   FAILS unless the org's vertical is on the passing list in
--                            mart.vertical_gate (50_ header lists every vertical and which
--                            side it lands on).
--
-- Unknown data never excludes by itself: gates 1-4 read flags that default to FALSE, gate 7
-- fires only on an explicit site_status. Gates 8 and 9 do exclude orgs with no AI signal /
-- no matching industry, which is the point of them.
--
-- mart.gate_funnel: rows remaining after each gate, in order, starting from all orgs.
CREATE TABLE mart.org_gate AS
WITH g AS (
  SELECT m.uuid AS org_uuid, m.organization_name,
    coalesce(m.is_closed, FALSE)                                              AS is_closed,
    coalesce(m.is_acquired, FALSE)                                            AS is_acquired,
    coalesce(m.is_nonprofit, FALSE)                                           AS is_nonprofit,
    coalesce(m.is_public, FALSE)                                              AS is_public,
    coalesce(m.is_competitor, FALSE)                                          AS is_competitor,
    coalesce(m.is_services_firm, FALSE)                                       AS is_services_firm,
    coalesce(m.site_status IN ('dead_or_unverified', 'hijacked'), FALSE)      AS dead_or_hijacked_site,
    coalesce(m.llm_level, 'none') NOT IN ('strong', 'nlp_only')               AS not_ai,
    NOT coalesce((SELECT passes FROM mart.vertical_gate v WHERE v.vertical = m.vertical), FALSE) AS industry_not_matched
  FROM mart.org_master m)
SELECT g.*,
  CASE WHEN is_closed THEN 'is_closed' WHEN is_acquired THEN 'is_acquired'
       WHEN is_nonprofit THEN 'is_nonprofit' WHEN is_public THEN 'is_public'
       WHEN is_competitor THEN 'is_competitor' WHEN is_servi
... [truncated 1250 chars]
```

Result of `Bash`
```
(Bash completed with no output)
```

Tool call `Bash`
```
cd white_circle/src/white_circle/sql && cat > 60_mart_org_score.sql <<'EOF'
-- 60_mart_org_score.sql  ->  mart.org_score  (score v4: one row per org that PASSES ALL GATES)
--
-- STAGE 2 OF SCORE v4: a fixed points rubric. Only orgs with mart.org_gate.passes_all are
-- scored; an excluded org has no score at all (it has a reason instead, in org_gate).
-- No point value is written in this file: every number is looked up in mart.score_weight
-- or mart.fit_bonus_rule (50_), which also say WHY. One column per component, so an AE
-- asking "why is this #7?" can read the answer off the row.
--
--   pts_recency    max 40  months since the LAST EQUITY round (as_of 2026-10-29):
--                          <=6 40, <=12 32, <=18 24, <=24 16, <=36 8, older 2, none/unknown 0
--   pts_revenue    max 25  decoded revenue band: <$1M 5, $1-10M 15, $10-50M 25, $50-100M 25,
--                          $100M+ 20 (enterprise procurement drag), unknown 0
--   pts_headcount  max 15  1-10 3, 11-50 8, 51-200 15, 201-500 15, 501-1000 12, 1001+ 8, unknown 0
--   pts_growth     max 20  12-month headcount growth >=50% 12, >=20% 8, >=0% 4, negative 0;
--                          +4 if 6-month growth >=20%; +4 if 3-month growth >=10%; capped at
--                          20. Unknown (not yet enriched by PDL) 0, never negative.
--   pts_bonus      max 10  fit bonus: best matching vertical tier from mart.fit_bonus_rule
--                          (pts_bonus_vertical) + 4 when the website check found an agent that
--                          takes actions (pts_bonus_agentic), capped at 10. Derived only from
--                          docs/whitecircle-research.md; region earns NO points.
--   rubric_total   = recency + revenue + headcount + growth        (out of 100)
--   total          = rubric_total + pts_bonus                       (out of 110)
-- Missing data = 0 points for that component and nothing more. We do not subtract for
-- unknowns, because most orgs have no round, revenue band or growth data: a penalty would
-- just rank by "who has a Crunchbase profile". How much we know is data_confidence, a
-- separate column used as a tie-break.
--
-- ORDER (rank): total desc, then region_priority (eu_uk and us_ca = 1, others = 2; region
-- is a TIE-BREAKER only and earns no points: White Circle sells in Europe and North
-- America), then data_confidence desc, then name. `ord` is that order, 1 = best.
--
-- reason_1..3: the three components that added the most points, in plain words, for the AE
-- and the CRM. For a website-verified org reason_1 stays "Ships: <what the site says it
-- ships>" and reasons 2-3 are the next two best components. Ties keep a fixed order
-- (fit, funding, revenue, headcount, growth) so the output is deterministic.
--
-- scored_at / score_version: when this build scored the org, and 'v4'. Every build is also
-- appended to ops.score_history (61_) so rescoring leaves an audit trail.
CREATE TABLE mart.org_score AS
WITH
w AS (SELECT component, level, points FROM mart.score_weight),
src AS (
  SELECT m.*,
    CASE WHEN m.months_since_last_equity IS NULL THEN 'unknown'
         WHEN m.months_since_last_equity <= 6  THEN 'le_6m'
         WHEN m.months_since_last_equity <= 12 THEN 'le_12m'
         WHEN m.months_since_last_equity <= 18 THEN 'le_18m'
         WHEN m.months_since_last_equity <= 24 THEN 'le_24m'
         WHEN m.months_since_last_equity <= 36 THEN 'le_36m'
         ELSE 'gt_36m' END AS recency_level,
    CASE WHEN m.revenue_min_usd IS NULL THEN 'unknown'
         WHEN m.revenue_min_usd < 1000000   THEN 'lt_1m'
         WHEN m.revenue_min_usd < 10000000  THEN '1m_10m'
         WHEN m.revenue_min_usd < 50000000  THEN '10m_50m'
         WHEN m.revenue_min_usd < 100000000 THEN '50m_100m'
         ELSE 'ge_100m' END AS revenue_level,
    CASE WHEN m.employees_min IS NULL THEN 'unknown'
         WHEN m.employees_min <= 10  THEN '1-10'
         WHEN m.employees_min <= 50  THEN '11-50'
         WHEN m.employees_min <= 200 THEN '51-200
... [truncated 8765 chars]
```

Result of `Bash`
```
27:--  6. employee_count_range / revenue_range are codes (c_00011_00050, r_00001000).
139:  d.employee_count_range,
141:  d.revenue_range,
170:LEFT JOIN emp e ON e.code = d.employee_count_range
```

Tool call `Bash`
```
cd white_circle/src/white_circle/sql && sed -i 's/SELECT md5(coalesce((SELECT string_agg(component/SELECT md5(coalesce((SELECT string_agg(component/; s/ AS h),/ AS wt),/; s/(SELECT h FROM wh)/(SELECT wt FROM wh)/g' 61_ops_score_history.sql && grep -n "wt" 61_ops_score_history.sql | head; 
cat > 70_mart_segments.sql <<'EOF'
-- 70_mart_segments.sql  ->  mart.tier_cutoff, mart.org_segment, mart.top50, mart.verify_next
--
-- Two separate questions, answered separately:
--   SEGMENT = WHO they are (what kind of buyer, which play to run). Rule-based, so an
--             AE can explain it in one breath. Does not use the score.
--   TIER    = HOW SOON to work them. Cut from the v4 total (out of 110). Gate-passers only.
--
-- Segments
--   Regulated GenAI     passed every gate AND the vertical is the regulated core
--                       (fintech_banking, insurance, health, legal_compliance): ships language
--                       AI where a bad answer is a compliance event. The thesis account.
--   AI-native builders  passed every gate, vertical 'ai_native': the Lovable lookalikes.
--   Marketed verticals  passed every gate, vertical is one White Circle markets to (public
--                       sector, education, HR, e-commerce, gaming, creative tools).
--   Enterprise          failed gate 4: publicly listed. A different sales motion, kept visible.
--   Competitor          failed gate 5: guardrail / AI-safety vendors.
--   Out: <gate>         everything else, named by the FIRST gate it failed (Out: is_closed,
--                       Out: not_ai, Out: industry_not_matched ...). Nobody is dropped
--                       silently; every org has a segment.
-- segment_universe = 'core' for gate-passers, otherwise the first failed gate.
--
-- TIER CUTOFFS (total out of 110, gate-passers only). Re-picked on the v4 distribution.
-- WHY these numbers is documented next to the values below; the counts are checked live
-- in `whitecircle segments`. Cutoffs live in mart.tier_cutoff so they can move without
-- editing logic.
--@@TIER_NOTES@@
--
-- mart.top50: gate-passers only, ranked by TOTAL descending (mart.org_score.ord: total,
-- then region_priority, then data_confidence, then name). Tier is a column, not the sort
-- key. Keeps the v3.1 rule that every top-50 org is VERIFIED: a high/medium-confidence
-- website check that says it ships a customer-facing LLM ('yes'), on a live (or
-- search-recovered) site. Tags alone can fill the tiers, never this list.
--
-- mart.verify_next: the "verify before outreach" queue: gate-passers that are NOT verified
-- (never reviewed, or reviewed unclear/low), best total first. Work it top-down: each org
-- verified moves into the top-50 pool if it ships, or out if it does not.
CREATE TABLE mart.tier_cutoff AS
SELECT * FROM (VALUES
  ('Tier 1', 0, 1), ('Tier 2', 0, 2), ('Tier 3', 0, 3), ('Nurture', 0, 4)
) AS t(tier, min_score, ord);

CREATE TABLE mart.org_segment AS
SELECT g.org_uuid, g.passes_all, g.first_failed_gate,
  CASE WHEN g.passes_all THEN 'core' ELSE g.first_failed_gate END AS segment_universe,
  CASE WHEN g.passes_all THEN
         CASE WHEN s.vertical IN ('fintech_banking', 'insurance', 'health', 'legal_compliance') THEN 'Regulated GenAI'
              WHEN s.vertical = 'ai_native' THEN 'AI-native builders'
              ELSE 'Marketed verticals' END
       WHEN g.first_failed_gate = 'is_public'     THEN 'Enterprise'
       WHEN g.first_failed_gate = 'is_competitor' THEN 'Competitor'
       ELSE 'Out: ' || g.first_failed_gate END AS segment,
  s.total,
  CASE WHEN g.passes_all THEN (SELECT tier FROM mart.tier_cutoff c WHERE s.total >= c.min_score ORDER BY c.ord LIMIT 1) END AS tier
FROM mart.org_gate g
LEFT JOIN mart.org_score s ON s.org_uuid = g.org_uuid;

CREATE UNIQUE INDEX mart_org_segment_org ON mart.org_segment (org_uuid);

CREATE TABLE mart.top50 AS
SELECT row_number() OVER (ORDER BY s.ord) AS rank,
  s.org_uuid, m.organization_name AS name, m.domain, m.country, m.short_description,
... [truncated 2883 chars]
```

Result of `Bash`
```
sed: 1: "61_ops_score_history.sql
": invalid command code _
CREATE OR REPLACE VIEW crm.company_upsert AS
SELECT
  CASE WHEN o.domain IS NOT NULL THEN 'domains' ELSE 'crunchbase_uuid' END AS match_attribute,
  o.domain                                   AS domains,           -- Attio: [{domain}]
  o.uuid                                     AS crunchbase_uuid,   -- custom, unique
  o.organization_name                        AS name,
  o.short_description                        AS description,
  o.linkedin_url                             AS linkedin,
  o.city || ', ' || o.country                AS primary_location_text,
  o.country                                  AS country,
  o.employees_label                          AS employee_range,
  o.founded_year                             AS founded_year,
  o.funding_stage_clean                      AS funding_stage,
  x.last_round_type                          AS last_round_type,    -- v2: last EQUITY round
  x.last_round_date                          AS last_round_date,    -- v2: last EQUITY round
  f.total_funding_usd                        AS total_funding_usd,
  -- scoring (machine-owned, versioned)
  -- v2: mapped to the real mart.org_score columns (v1 relied on alias columns that
  -- were added to the score table only to satisfy this file; they are gone).
  s.total                                    AS fit_score,          -- v4: out of 110
  s.rubric_total, s.score_version, s.scored_at, s.data_confidence,
  s.pts_recency       
... [truncated 647 chars]
```

Tool call `Bash`
```
cd white_circle/src/white_circle/sql && python3 - <<'E'
p='61_ops_score_history.sql'
s=open(p).read()
s=s.replace(" AS h),\nx AS"," AS wt),\nx AS").replace("(SELECT h FROM wh)","(SELECT wt FROM wh)")
open(p,'w').write(s)
E
grep -n "wt" 61_ops_score_history.sql | head -3
cd .. && python3 - <<'E'
s=open('paths.py').read()
s+='HC_SEED = SEEDS / "headcount_history.csv"\nENRICH = DATA / "enrich" / "pdl"\n'
open('paths.py','w').write(s)
c=open('cli.py').read()
c=c.replace("from .paths import DB, RAW, REVIEW_SEED, ROOT, SQL_DIR, VERIFY","from .paths import DB, HC_SEED, RAW, REVIEW_SEED, ROOT, SQL_DIR, VERIFY")
old=c[c.index("                # '-- @requires-seed' splits"):c.index("                typer.echo(f\"ran {f.name}\")")]
new='''                # '-- @requires-seed' / '-- @requires-hc-seed' split a file in two: the part after
                # the marker runs only when that committed seed exists (see 52_ and 56_).
                marker, seed, key = (("-- @requires-hc-seed\\n", HC_SEED, "{{hc_seed}}")
                                     if "-- @requires-hc-seed\\n" in text
                                     else ("-- @requires-seed\\n", REVIEW_SEED, "{{review_seed}}"))
                head, _, tail = text.partition(marker)
                con.execute(head)
                if tail:
                    if seed.exists():
                        con.execute(tail.replace(key, str(seed)))
                    else:
                        typer.echo(f"  (no {seed.name}: table left empty)")
'''
c=c.replace(old,new)
open('cli.py','w').write(c)
E
sed -n 40,70p cli.py
```

Result of `Bash`
```
13:-- growth percentages, vertical, agentic flag, as_of date) PLUS a hash of the weight and
21:  pts_recency INTEGER, pts_revenue INTEGER, pts_headcount INTEGER, pts_growth INTEGER,
28:          || coalesce((SELECT string_agg(kind || '|' || key || '|' || points, ';' ORDER BY kind, key) FROM mart.fit_bonus_rule), '')) AS wt),
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
                for (
... [truncated 417 chars]
```

Tool call `Bash`
```
cd white_circle/src/white_circle/sql && cat > 95_dq_score_checks.sql <<'EOF'
-- 95_dq_score_checks.sql  ->  dq.score_checks
--
-- Checks on the master table, the gates and the v4 score. Kept apart from
-- 90_dq_checks.sql (raw/stg data quality). Same convention: rows_affected = 0 is PASS,
-- except rows labelled INFO. `whitecircle dq` prints both.
CREATE TABLE dq.score_checks AS
WITH checks(ord, check_name, description, rows_affected, action_taken) AS (
  -- master table [REDACTED_SECRET]
  SELECT 901, 'master_one_row_per_org', 'ASSERT: orgs without exactly one mart.org_master row (missing + duplicated)',
    (SELECT abs(count(*) - (SELECT count(*) FROM stg.organizations)) + abs(count(*) - count(DISTINCT uuid)) FROM mart.org_master),
    '0 = pass. No LEFT JOIN dropped or fanned out an org'
  UNION ALL SELECT 902, 'master_rounds_reconcile_per_org', 'ASSERT: orgs whose rounds list length differs from stg.funding_rounds',
    (SELECT count(*) FROM mart.org_master m
      WHERE len(m.rounds) <> (SELECT count(*) FROM stg.funding_rounds r WHERE r.org_uuid = m.uuid)),
    '0 = pass. The rounds LIST holds every round, none lost in the join'
  UNION ALL SELECT 903, 'master_rounds_reconcile_total', 'ASSERT: total rounds in mart.org_master differs from stg.funding_rounds',
    (SELECT abs((SELECT coalesce(sum(len(rounds)), 0) FROM mart.org_master) - (SELECT count(*) FROM stg.funding_rounds))),
    '0 = pass. Total 1,854 rounds on both sides'
  UNION ALL SELECT 904, 'master_equity_count_reconcile', 'ASSERT: orgs whose equity_rounds_count differs from the is_equity entries in rounds',
    (SELECT count(*) FROM mart.org_master m
      WHERE m.equity_rounds_count <> len(list_filter(m.rounds, x -> x.is_equity))),
    '0 = pass'
  -- gates [REDACTED_SECRET]
  UNION ALL SELECT 910, 'gate_one_row_per_org', 'ASSERT: orgs without exactly one mart.org_gate row',
    (SELECT abs(count(*) - (SELECT count(*) FROM mart.org_master)) + abs(count(*) - count(DISTINCT org_uuid)) FROM mart.org_gate), '0 = pass'
  UNION ALL SELECT 911, 'funnel_not_monotonic', 'ASSERT: gate_funnel steps where remaining rises, or the last step differs from the gate-passers',
    (SELECT count(*) FROM (SELECT remaining, lag(remaining) OVER (ORDER BY step) AS prev FROM mart.gate_funnel) WHERE prev IS NOT NULL AND remaining > prev)
     + abs((SELECT remaining FROM mart.gate_funnel ORDER BY step DESC LIMIT 1) - (SELECT count(*) FROM mart.org_gate WHERE passes_all)),
    '0 = pass. Each gate can only remove rows'
  UNION ALL SELECT 912, 'industry_gate_missing_vertical', 'Orgs whose vertical has no row in mart.vertical_gate (would silently fail gate 9)',
    (SELECT count(*) FROM mart.org_master m WHERE NOT EXISTS (SELECT 1 FROM mart.vertical_gate v WHERE v.vertical = m.vertical)),
    '0 = pass. Catches a new vertical bucket in 55_/57_ that 50_ does not list'
  -- score [REDACTED_SECRET]
  UNION ALL SELECT 920, 'score_only_gate_passers', 'ASSERT: scored orgs that do not pass every gate, or passers without a score',
    (SELECT count(*) FROM mart.org_score s JOIN mart.org_gate g USING (org_uuid) WHERE NOT g.passes_all)
     + (SELECT count(*) FROM mart.org_gate g WHERE g.passes_all AND NOT EXISTS (SELECT 1 FROM mart.org_score s WHERE s.org_uuid = g.org_uuid)), '0 = pass'
  UNION ALL SELECT 921, 'top50_gate_failure', 'ASSERT: every top-50 org passes all gates (top-50 rows that do not)',
    (SELECT count(*) FROM mart.top50 t JOIN mart.org_gate g USING (org_uuid) WHERE NOT g.passes_all), '0 = pass'
  UNION ALL SELECT 922, 'score_component_sum_mismatch', 'ASSERT: orgs where component sum differs from total',
    (SELECT count(*) FROM mart.org_score WHERE pts_recency + pts_revenue + pts_headcount + pts_growth + pts_bonus <> total
        OR pts_recency + pts_revenue + pts_headcount + pts_growth <> rubric_total), '0 = pass. total is exactly the sum of the visible columns'
  UNION ALL SELECT 923, 'bonus_over_10', 'ASSERT: orgs with a fit bonus above 10',
    (SELECT count(*) FROM mart.or
... [truncated 5104 chars]
```

Result of `Bash`
```
raw.organizations: 3,000 rows
raw.funding_rounds: 1,854 rows
raw.contacts: 2,763 rows
5 parts, 180 rows -> 180 unique orgs -> [REDACTED_SECRET].csv
api calls: loaded 41 (53 credits, 21 search calls estimated at 1 each), dropped 1 exact duplicate lines, skipped 0 already loaded
ran 00_schemas.sql
ran 10_stg_organizations.sql
ran 20_stg_category_map.sql
ran 25_stg_org_category.sql
ran 30_stg_funding_rounds.sql
ran 35_stg_org_funding.sql
ran 40_stg_contacts.sql
ran 50_mart_score_weights.sql
ran 52_stg_company_review.sql
ran 55_mart_org_features.sql
  (no headcount_history.csv: table left empty)
ran 56_stg_headcount_history.sql
ran 57_mart_org_master.sql
ran 58_mart_org_gate.sql
ran 60_mart_org_score.sql
ran 61_ops_score_history.sql
ran 70_mart_segments.sql
ran 80_crm_export.sql
ran 90_dq_checks.sql
╭───────────────────── Traceback (most recent call last) ──────────────────────╮
│ white_circle/src/white_circle/ │
│ cli.py:54 in build                                                           │
│                                                                              │
│    51 │   │   │   │   │   │   │   │   │    if "-- @requires-hc-seed\n" in    │
│       text                                                                   │
│    52 │   │   │   │   │   │   │   │   │    else ("-- @requires-seed\n",      │
│       REVIEW_SEED, "{{review_seed}}"))                                       │
│    53 │   │   │   │   head, _, tail = text.partition(marker)                 │
│ ❱  54 │ 
... [truncated 736 chars]
```

Tool call `Bash`
```
sed -i '' 's/list_filter(m.rounds, x -> x.is_equity)/list_filter(m.rounds, lambda x: x.is_equity)/' src/white_circle/sql/95_dq_score_checks.sql && git status --short src docs | head; uv run whitecircle build 2>&1 | tail -4; uv run whitecircle dq 2>&1 | grep -v "^ *(" | awk 'NR==1||$2!="0"' | head -50
```

Result of `Bash`
```
?? docs/
?? src/
  mart.top50: 50
  mart.vertical_gate: 19
  dq.checks: 62
  dq.score_checks: 26
check                                rows  action / description
org_without_funding_round           2,200  LEFT JOIN from organizations everywhere; "no funding data" is a segment, never dropped
org_without_contact                 1,953  Kept; becomes the "needs enrichment" segment
org_website_not_clean               2,138  domain column = lower-case host with scheme, www, path, query and port stripped
org_website_tracking_params             5  Query string stripped when building domain
org_website_social_profile              1  domain set to NULL, website_is_social = TRUE (so it cannot be used as an enrichment key)
org_website_missing                    20  domain NULL; enrichment must fall back to name + linkedin_url
org_acquired_but_active               106  is_acquired = TRUE, so is_operating = FALSE; excluded from outreach
org_acquired_total                    127  Flagged is_acquired
org_closed                             72  is_closed = TRUE, excluded from is_operating
org_closed_without_closed_on           46  Use operating_status, never closed_on, to find dead companies
org_nonprofit                          17  is_nonprofit = TRUE, excluded from is_operating
org_public                             29  is_public = TRUE, excluded from is_operating; kept so an enterprise segment is possible
org_public_without_ipo_stage            3  Trust ipo_status over funding_stage
org_fun
... [truncated 3470 chars]
```

Tool call `Bash`
```
uv run python - <<'E'
import duckdb
c=duckdb.connect('data/white_circle.duckdb',read_only=True)
for r in c.execute("select ord,check_name,rows_affected from dq.score_checks order by ord").fetchall(): print(r)
print(c.execute("select * from mart.gate_funnel").fetchall())
print(c.execute("select segment,count(*) from mart.org_segment group by 1 order by 2 desc").fetchall())
print(c.execute("select vertical,count(*) from mart.org_score group by 1 order by 2 desc").fetchall())
print(c.execute("select total,count(*) from mart.org_score group by 1 order by 1 desc").fetchall())
print(c.execute("select count(*),count(*) filter(where has_verified_review) from mart.org_score").fetchall())
E
```

Result of `Bash`
```
(901, 'master_one_row_per_org', 0)
(902, 'master_rounds_reconcile_per_org', 0)
(903, 'master_rounds_reconcile_total', 0)
(904, 'master_equity_count_reconcile', 0)
(910, 'gate_one_row_per_org', 0)
(911, 'funnel_not_monotonic', 0)
(912, 'industry_gate_missing_vertical', 0)
(920, 'score_only_gate_passers', 0)
(921, 'top50_gate_failure', 0)
(922, 'score_component_sum_mismatch', 0)
(923, 'bonus_over_10', 0)
(924, 'rubric_max_not_100', 0)
(925, 'component_over_max', 0)
(926, 'total_out_of_range', 0)
(927, 'score_level_missing_weight', 0)
(928, 'bonus_unsupported_by_research', 0)
(929, 'agentic_bonus_unverified', 0)
(930, 'score_history_dupes', 0)
(940, 'top50_size', 0)
(941, 'top50_not_verified', 0)
(942, 'top50_not_sorted_by_total', 0)
(943, 'verify_next_size', 545)
(944, 'org_without_segment', 0)
(945, 'passer_without_tier', 0)
(950, 'growth_not_yet_enriched', 608)
(951, 'review_rows_ignored', 40)
[(0, 'all orgs', 3000, 0), (1, 'is_closed', 2928, 72), (2, 'is_acquired', 2822, 106), (3, 'is_nonprofit', 2805, 17), (4, 'is_public', 2779, 26), (5, 'is_competitor', 2772, 7), (6, 'is_services_firm', 2278, 494), (7, 'dead_or_hijacked_site', 2250, 28), (8, 'not_ai', 672, 1578), (9, 'industry_not_matched', 608, 64)]
[('Out: not_ai', 1578), ('Out: is_services_firm', 494), ('AI-native builders', 472), ('Marketed verticals', 109), ('Out: is_acquired', 106), ('Out: is_closed', 72), ('Out: industry_not_matched', 64), ('Out: dead_or_hijacked_site', 28), ('Regulated GenAI', 27), ('Enterprise', 2
... [truncated 728 chars]
```

Tool call `Bash`
```
cd white_circle/src/white_circle/sql && python3 - <<'E'
p='70_mart_segments.sql'
s=open(p).read()
notes="""--   Tier 1   >= 40   AE works these now          (47 accounts)
--   Tier 2   25-39    SDR sequence, AE joins on reply (76)
--   Tier 3   14-24    automated nurture, promote on a trigger such as a new round (136)
--   Nurture  < 14     watch list; re-score on new data (349)
-- WHY (the v4 total is 0-110 over the 608 orgs that pass every gate; counts as built):
--   * The top of the distribution is thin: only 3 orgs score 72+, 13 score 52+, and the
--     counts per point are 9 at 49 and 9 at 41. 40 is the first round number below that 41
--     cluster and gives 47 accounts, about the size a 3-person AE team can work in a
--     quarter (the aim was 40-60). 45 would leave 32, 50 would leave 15: too few to staff.
--   * 238 orgs sit at exactly 9 points: nothing known except a headcount band. That is the
--     "no signal" mass, not a lead list. 14 is the first score above it that needs at least
--     one real fact (a round, a revenue band, a growth reading or a fit bonus), so Tier 3
--     starts at 14 and everything below is Nurture.
--   * 25 splits the 14-39 middle so Tier 2 (76) is a size an SDR sequence can cover and
--     Tier 3 (136) is the automated nurture. 25 is also the revenue sweet-spot value, a
--     round number with no gap to anchor on (the score is a sum of small pieces).
--   * The scale changed from v3 (0-100, tag-based points) to v4 (0-110, rubric), and the
--     population changed (gates remove 80%), so v3's 65/52/42 cannot be reused.
--   * Headcount growth is 0 for everyone until PDL enrichment runs (up to +20), so these
--     cutoffs are expected to be RE-PICKED after enrichment; scores will rise for fast
--     growers. History in ops.score_history shows the before and after."""
s=s.replace("--@@TIER_NOTES@@",notes)
s=s.replace("('Tier 1', 0, 1), ('Tier 2', 0, 2), ('Tier 3', 0, 3), ('Nurture', 0, 4)","('Tier 1', 40, 1), ('Tier 2', 25, 2), ('Tier 3', 14, 3), ('Nurture', 0, 4)")
open(p,'w').write(s)
p='00_schemas.sql'
s=open(p).read()
s=s.replace("--   ops  : audit trail of CLI runs and API calls (NOT dropped here; see obs.py)","--   ops  : audit trail of CLI runs and API calls, and ops.score_history, the append-only\n--          record of every scoring run (NOT dropped here; see obs.py and 61_)")
s=s.replace("score weights, org features, fit score, segments, top 50","v4 weights, org master, gates, rubric score, segments, top 50")
open(p,'w').write(s)
E
cd ../../.. && uv run whitecircle build >/dev/null 2>&1; uv run whitecircle segments; uv run whitecircle dq | grep -E "^(score|master|top50|funnel)" ; uv run python - <<'E'
import duckdb
c=duckdb.connect('data/white_circle.duckdb',read_only=True)
for r in c.execute("select rank,name,total,rubric_total,pts_bonus,months_since_last_equity,revenue_label,employees_label,country,region_bucket,verified_llm_use,tier,segment from mart.top50 order by rank limit 15").fetchall(): print(r)
print(c.execute("select tier,count(*) from mart.org_segment where passes_all group by 1 order by 1").fetchall())
E
```

Result of `Bash`
```
tier cutoffs (fit_score >=): Tier 1 40, Tier 2 25, Tier 3 14, Nurture 0
segment                   Tier 1   Tier 2   Tier 3  Nurture      n/a    total
Regulated GenAI                6        7        4       10        0       27
AI-native builders            28       58      115      271        0      472
Regulated AI-adjacent          0        0        0        0        0        0
Low fit                        0        0        0        0        0        0
Not deploying AI               0        0        0        0        0        0
Enterprise                     0        0        0        0       26       26
Competitor                     0        0        0        0        7        7
Out: closed or acquired        0        0        0        0        0        0
Out: nonprofit                 0        0        0        0        0        0
TOTAL                         34       65      119      281       33      532
master_one_row_per_org                  0  0 = pass. No LEFT JOIN dropped or fanned out an org
master_rounds_reconcile_per_org         0  0 = pass. The rounds LIST holds every round, none lost in the join
master_rounds_reconcile_total           0  0 = pass. Total 1,854 rounds on both sides
master_equity_count_reconcile           0  0 = pass
funnel_not_monotonic                    0  0 = pass. Each gate can only remove rows
score_only_gate_passers                 0  0 = pass
top50_gate_failure                      0  0 = pass
score_component_sum_mismatch           
... [truncated 2906 chars]
```

Tool call `Bash`
```
cd white_circle/src/white_circle && cat > enrich_pdl.py <<'EOF'
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
        v = r
... [truncated 8095 chars]
```

Result of `Bash`
```
{'org_uuid': 'X', 'pdl_id': 'tnHcNHbCv8MKeLh92946LAkX6PKg', 'likelihood': 8, 'hc_current': 78, 'hc_3m_ago': 70, 'hc_6m_ago': 60, 'hc_12m_ago': 52, 'growth_3m_pct': 11.43, 'growth_6m_pct': 30.0, 'growth_12m_pct': 56.0, 'hc_source': 'peopledatalabs', 'hc_fetched_at': '2026-10-30 12:00:00'}
None 2025-11
PDL company enrich: 608 gate-passers not yet fetched; this run would make 25 requests (cap: --max-credits 25, --limit None); worst case 25 credits (1 per match assumed).
free plan: ~10 requests/minute, so about 2.5 minutes of waiting.
   83  Centrical                            centrical.com
   77  Replit                               replit.com
   72  Shapes                               shapes.co
   64  Audion                               audion.ai
   64  Botpress                             botpress.com
   57  Dash0                                dash0.com
   57  Kinfolk                              kinfolkhq.com
   54  Auctor                               getauctor.com
   54  Smartcat                             smartcat.com
   54  Appraisal Dream                      appraisaldream.com
  ... and 15 more
dry run: no API calls made, nothing written. Re-run with --no-dry-run and PDL_API_KEY set.
data:
logs
raw
verify
white_circle.duckdb

src/white_circle/seeds:
company_review.csv
```

Tool call `Bash`
```
ls docs docs/deliverables docs/deliverables/accounts 2>&1 | head -30; cat docs/approach-evolution.md 2>&1 | head -80
```

Tool call `Bash`
```
cat src/white_circle/templates/dashboard.html
```

Result of `Bash`
```
<title>White Circle Pipeline</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&display=swap">
<style>
/* Layout: one calm column, summary first, detail below; wide tables scroll inside their own box. */
:root {
  --bg: #f7f7f5; --surface: #ffffff; --ink: #14151a; --ink-2: #4a4d57; --ink-3: #747884;
  --rule: #e2e2dd; --accent: #2a78d6; --accent-ink: #ffffff;
  --good: #1a7f4b; --warn: #a15c00; --bad: #c4372f; --info: #3a5f9e;
  --s1: #2a78d6; --s2: #eb6834; --s3: #1baf7a; --s4: #eda100; --s5: #e87ba4; --s6: #008300; --s7: #6250d6;
  --font-body: "IBM Plex Sans", system-ui, -apple-system, "Segoe UI", sans-serif;
  --font-mono: "IBM Plex Mono", ui-monospace, "SF Mono", Menlo, monospace;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #121316; --surface: #1a1b1f; --ink: #f0efec; --ink-2: #c3c2b7; --ink-3: #8f9099;
  --rule: #2e3036; --accent: #3987e5; --accent-ink: #0b0b0b;
  --good: #4cc38a; --warn: #e0a84a; --bad: #ef7b73; --info: #7fa6e6;
  --s1: #3987e5; --s2: #d95926; --s3: #199e70; --s4: #c98500; --s5: #d55181; --s6: #008300; --s7: #9085e9;
  color-scheme: dark; } }
:root[data-theme="dark"] {
  --bg: #121316; --surface: #1a1b1f; --ink: #f0efec; --ink-2: #c3c2b7; --ink-3: #8f9099;
  --rule: #2e3036; --accent: #3987e5; --accent-ink: #0b0b0b;
  --good: #4cc38a; --warn: #e0a84a; --bad: #ef7b73; --
... [truncated 25778 chars]
```

Result of `Bash`
```
   contacts. The top of the list exposed the problems. "Regulated" swept in crypto, fitness and
[53 other listing lines redacted: outside project scope]
```

Tool call `Bash`
```
cd white_circle/src/white_circle && python3 - <<'E'
s=open('dashboard.py').read()
a=s.index("V3_COLS = ")
b=s.index("def _rows(")
s=s[:a]+'''TIERS = ["Tier 1", "Tier 2", "Tier 3", "Nurture"]
CORE_SEGMENTS = ["Regulated GenAI", "AI-native builders", "Marketed verticals"]
OTHER_SEGMENTS = ["Enterprise", "Competitor", "Out: is_closed", "Out: is_acquired", "Out: is_nonprofit",
                  "Out: is_services_firm", "Out: dead_or_hijacked_site", "Out: not_ai", "Out: industry_not_matched"]
DOCS = ROOT / "docs"
ACCOUNTS_DIR = DOCS / "deliverables" / "accounts"
CRM_MODEL = DOCS / "deliverables" / "crm_model.json"
EVOLUTION = DOCS / "approach-evolution.md"


'''+s[b:]
# replace _v3_sources .. export
a=s.index("def _v3_sources")
b=s.index("def render()")
new='''def _load_json(path: Path):
    try:
        return json.loads(path.read_text())
    except Exception:  # missing or half-written file: the page shows "pending"
        return None


def _accounts() -> dict:
    """Dossiers written by other agents: docs/deliverables/accounts/<org_uuid>.json. Whatever exists is embedded."""
    out = {}
    if ACCOUNTS_DIR.exists():
        for p in sorted(ACCOUNTS_DIR.glob("*.json")):
            d = _load_json(p)
            if isinstance(d, dict):
                out[p.stem] = d
    return out


def md_to_html(md: str) -> str:
    """Minimal, safe markdown: headings, **bold**, *italic*, numbered lists, paragraphs. Input is HTML-escaped first."""
    def inline(t: str) -> str:
        t = html.escape(t, quote=True)
        t = re.sub(r"\\*\\*(.+?)\\*\\*", r"<strong>\\1</strong>", t)
        return re.sub(r"(?<![\\w*])\\*(?!\\s)(.+?)(?<!\\s)\\*(?![\\w*])", r"<em>\\1</em>", t)

    out, para, items = [], [], []

    def flush_para():
        if para:
            out.append("<p>" + inline(" ".join(para)) + "</p>")
            para.clear()

    def flush_list():
        if items:
            out.append("<ol>" + "".join(f"<li>{inline(' '.join(i))}</li>" for i in items) + "</ol>")
            items.clear()

    for line in md.splitlines():
        m_h = re.match(r"^(#{1,6})\\s+(.*)$", line)
        m_n = re.match(r"^\\s*\\d+\\.\\s+(.*)$", line)
        if m_h:
            flush_para(); flush_list()
            lvl = min(len(m_h.group(1)) + 1, 4)
            out.append(f"<h{lvl}>{inline(m_h.group(2))}</h{lvl}>")
        elif m_n:
            flush_para()
            items.append([m_n.group(1)])
        elif not line.strip():
            flush_para(); flush_list()
        elif items and line.startswith((" ", "\\t")):
            items[-1].append(line.strip())
        else:
            flush_list()
            para.append(line.strip())
    flush_para(); flush_list()
    return "\\n".join(out)


def export(con) -> dict:
    top = _rows(con, """
        SELECT t.rank, t.org_uuid, t.name, t.domain, t.country, t.short_description, t.segment, t.tier, t.total, t.rubric_total,
          t.pts_recency, t.pts_revenue, t.pts_headcount, t.pts_growth, t.pts_bonus, t.pts_bonus_vertical, t.pts_bonus_agentic,
          t.region_bucket, t.vertical, t.llm_level, t.last_equity_date, t.months_since_last_equity, t.revenue_label, t.employees_label,
          t.growth_3m_pct, t.growth_6m_pct, t.growth_12m_pct, round(t.data_confidence, 2) AS data_confidence,
          t.reason_1, t.reason_2, t.reason_3, t.best_contact_name, t.best_contact_title,
          t.llm_level_source, t.verified_ships_llm, t.verified_llm_use, t.is_agentic, t.evidence_quote,
          r.source_url AS evidence_url, r.url_checked
        FROM mart.top50 t LEFT JOIN stg.company_review r USING (org_uuid) ORDER BY t.rank""")
    seg = _rows(con, "SELECT segment, coalesce(tier,'-') AS tier, count(*) AS n FROM mart.org_segment GROUP BY 1,2")
    universe = con.execute("SELECT count(*) FROM mart.org_segment").fetchone()[0]
    core = con.execute("SELECT count(*) FROM mart.org_segment WHERE passes_all").fetchone()[0]
    tier1 = con.execute("SELECT count(*) FROM mart.org_segment WHERE tier='Tier 1'").fetchone
... [truncated 4208 chars]
```

Result of `Bash`
```
"""Export the pipeline results from DuckDB and render docs/dashboard/index.html.

Read-only: one short connection, closed before the page is written. The page is a
single self-contained HTML file with the data embedded as JSON. Columns added later
v4 mart tables (gate funnel, rubric, fit-bonus rules, verify queue), the optional
account dossiers (docs/deliverables/accounts/*.json), the CRM model JSON and the
approach-evolution markdown. Free text from JSON is rendered by the page as text only.
"""
from __future__ import annotations

import html
import json

TEMPLATE = Path(__file__).resolve().parent / "templates" / "dashboard.html"
OUT = ROOT / "docs" / "dashboard" / "index.html"

TIERS = ["Tier 1", "Tier 2", "Tier 3", "Nurture"]
CORE_SEGMENTS = ["Regulated GenAI", "AI-native builders", "Marketed verticals"]
OTHER_SEGMENTS = ["Enterprise", "Competitor", "Out: is_closed", "Out: is_acquired", "Out: is_nonprofit",
                  "Out: is_services_firm", "Out: dead_or_hijacked_site", "Out: not_ai", "Out: industry_not_matched"]
DOCS = ROOT / "docs"
ACCOUNTS_DIR = DOCS / "deliverables" / "accounts"
CRM_MODEL = DOCS / "deliverables" / "crm_model.json"
EVOLUTION = DOCS / "approach-evolution.md"


def _rows(con, sql: str, params: list | None = None) -> list[dict]:
    cur = con.execute(sql, params or [])
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def _exists(con, table: str) -> bool:
```

Tool call `Bash`
```
cd white_circle/src/white_circle && python3 - <<'E'
s=open('dashboard.py').read()
s=s.replace("single self-contained HTML file with the data embedded as JSON. Columns added later\nv4 mart tables","single self-contained HTML file with the data embedded as JSON. It embeds the\nv4 mart tables")
open('dashboard.py','w').write(s)
t=open('templates/dashboard.html').read()
css_end=t.index("</style>")
css=t[:css_end]
css+='''
/* v4 additions */
.tabs { display: flex; gap: 4px; border-bottom: 1px solid var(--rule); }
.tabs [role="tab"] { border: 0; border-bottom: 2px solid transparent; border-radius: 0; background: none; padding: 8px 14px; font-weight: 500; color: var(--ink-2); }
.tabs [role="tab"][aria-selected="true"] { color: var(--ink); border-bottom-color: var(--accent); }
[role="tabpanel"] { display: flex; flex-direction: column; gap: 40px; }
[role="tabpanel"][hidden] { display: none; }
.cA { --c: var(--s1); } .cB { --c: var(--s2); } .cC { --c: var(--s3); } .cD { --c: var(--s4); } .cE { --c: var(--s5); }
.cell { display: flex; align-items: center; gap: 6px; justify-content: flex-end; font-variant-numeric: tabular-nums; white-space: nowrap; }
.cell .sb { display: inline-block; width: 38px; height: 5px; border-radius: 3px; background: var(--rule); overflow: hidden; }
.cell .sb i { display: block; height: 100%; background: var(--c); }
.totcell { min-width: 130px; }
.totcell b { font-size: 15px; }
.stack { display: flex; height: 6px; width: 90px; border-radius: 3px; overflow: hidden; background: var(--rule); margin-top: 3px; }
.stack i { display: block; height: 100%; }
th small { display: block; font-weight: 400; letter-spacing: 0; text-transform: none; }
.help { width: 22px; height: 22px; border-radius: 50%; padding: 0; font: 600 12px var(--font-body); line-height: 1; margin-left: 8px; vertical-align: middle; }
.pop { position: absolute; z-index: 30; max-width: 400px; background: var(--surface); color: var(--ink); border: 1px solid var(--ink-3);
  border-radius: 6px; padding: 12px 14px; font-size: 13px; box-shadow: 0 6px 24px rgba(0,0,0,.18); }
.pop[hidden] { display: none; }
.pop ul { margin: 6px 0 0; padding-left: 16px; }
.h2row { position: relative; display: flex; align-items: center; flex-wrap: wrap; }
.dive { font: 500 11px var(--font-mono); margin-left: 6px; padding: 1px 6px; border-radius: 3px; background: var(--accent); color: var(--accent-ink); border-color: var(--accent); white-space: nowrap; }
.na { color: var(--ink-3); cursor: help; }
.funnel { display: grid; grid-template-columns: 24px minmax(120px, 190px) 1fr 90px; gap: 6px 10px; align-items: center; font-size: 13px; }
.funnel .track { height: 16px; background: var(--rule); border-radius: 3px; overflow: hidden; }
.funnel .track i { display: block; height: 100%; background: var(--s1); }
.funnel .rem { text-align: right; font-family: var(--font-mono); }
.md h2 { font-size: 18px; } .md h3, .md h4 { font-size: 14px; } .md p, .md ol { margin: 0 0 10px; max-width: 74ch; } .md li { margin-bottom: 8px; }
#dossier-bg { position: fixed; inset: 0; background: rgba(0,0,0,.4); z-index: 40; display: none; }
#dossier { position: fixed; top: 0; right: 0; bottom: 0; width: min(760px, 100vw); background: var(--bg); z-index: 41; overflow-y: auto;
  padding: 20px max(16px, env(safe-area-inset-right, 0px)) 40px 20px; box-shadow: -8px 0 32px rgba(0,0,0,.25); display: none; }
#dossier.open, #dossier-bg.open { display: block; }
#dossier .x { position: sticky; top: 0; float: right; }
#dossier h3 { margin-top: 18px; font-size: 14px; }
#dossier ul { margin: 4px 0; padding-left: 18px; }
.warnbox { border: 1px dashed var(--warn); color: var(--warn); border-radius: 6px; padding: 6px 10px; font-size: 12px; }
.cards { display: flex; flex-direction: column; gap: 20px; }
.cost { font: 500 10px var(--font-mono); text-transform: uppercase; padding: 1px 6px; border-radius: 3px; border: 1px solid var(--rule); margin-left: 6px; }
.cost.baseline { border-color: var(--info); color: var(--info); } .cost.deep {
... [truncated 8032 chars]
```

Result of `Bash`
```
_css.part
_html.part
dashboard.html
```

Tool call `Bash`
```
cd white_circle/src/white_circle/templates && rm -f /tmp/_dummy && cat > _js.part <<'EOF'
const $ = id => document.getElementById(id);
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const fmt = n => (n == null ? "-" : Number(n).toLocaleString("en-US"));
const REG = {eu_uk: "Europe", us_ca: "North America", other: "Elsewhere", unknown: "Unknown"};
const VERT = v => (v || "other").replace(/_/g, " / ");
const SEGCOL = {}; D.core_segments.forEach((s, i) => SEGCOL[s] = `var(--s${i + 1})`);
const M = D.meta;

/* safe DOM builder: every value goes in through textContent, never innerHTML */
function h(tag, attrs, ...kids) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs || {})) {
    if (v == null || v === false) continue;
    if (k === "class") e.className = v; else if (k === "text") e.textContent = v; else e.setAttribute(k, v === true ? "" : v);
  }
  kids.flat().forEach(c => { if (c != null && c !== false) e.append(c.nodeType ? c : document.createTextNode(String(c))); });
  return e;
}
const safeUrl = u => (typeof u === "string" && /^https?:\/\//i.test(u)) ? u : null;
function link(url, text) { const u = safeUrl(url); return u ? h("a", {href: u, target: "_blank", rel: "noopener noreferrer"}, text || u) : document.createTextNode(text || url || ""); }

/* tooltip */
const tip = $("tip");
document.addEventListener("mousemove", e => { if (tip.style.display === "block") {
  tip.style.left = Math.min(e.clientX + 12, innerWidth - 270) + "px"; tip.style.top = e.clientY + 14 + "px"; } });
function bindTip(el, text) {
  el.addEventListener("mouseenter", () => { tip.textContent = text; tip.style.display = "block"; });
  el.addEventListener("mouseleave", () => tip.style.display = "none");
  el.setAttribute("aria-label", text);
}

/* tabs: arrow keys, URL hash, remembered in localStorage */
(function () {
  const tabs = [...document.querySelectorAll('[role="tab"]')];
  const hashOf = t => t.id.replace("tab-", "");
  function select(t, focus, writeHash) {
    tabs.forEach(x => { const on = x === t; x.setAttribute("aria-selected", on); x.tabIndex = on ? 0 : -1;
      $(x.getAttribute("aria-controls")).hidden = !on; });
    if (focus) t.focus();
    try { localStorage.setItem("wc-tab", hashOf(t)); } catch (e) {}
    if (writeHash) { try { history.replaceState(null, "", "#" + hashOf(t)); } catch (e) { location.hash = hashOf(t); } }
  }
  tabs.forEach((t, i) => {
    t.addEventListener("click", () => select(t, false, true));
    t.addEventListener("keydown", e => {
      const k = {ArrowRight: 1, ArrowLeft: -1}[e.key];
      if (k) { e.preventDefault(); select(tabs[(i + k + tabs.length) % tabs.length], true, true); }
      else if (e.key === "Home") { e.preventDefault(); select(tabs[0], true, true); }
      else if (e.key === "End") { e.preventDefault(); select(tabs[tabs.length - 1], true, true); }
    });
  });
  function fromHash() {
    const hs = location.hash.slice(1); const t = tabs.find(x => hashOf(x) === hs);
    if (t) { select(t, false, false); return true; }
    if (hs && document.getElementById(hs)) { select(tabs[0], false, false); return true; }
    return false;
  }
  window.addEventListener("hashchange", fromHash);
  if (!fromHash()) {
    let last = null; try { last = localStorage.getItem("wc-tab"); } catch (e) {}
    const t = tabs.find(x => hashOf(x) === last) || tabs[0]; select(t, false, false);
  }
})();

/* KPIs */
function kpi(v, l, n) { return `<div class="kpi"><div class="v">${v}</div><div class="l">${l}</div>${n ? `<div class="n">${n}</div>` : ""}</div>`; }
$("kpis").innerHTML =
  kpi(fmt(M.universe), "Companies in the data", "Everything loaded, nobody dropped") +
  kpi(fmt(M.core), "Pass all nine gates", "These get a score") +
  kpi(fmt(M.tier1), "Tier 1 accounts", "Total " + (D.cutoffs[0]?.min_score ?? "") + " or more (of 110): AEs work now") +
  kpi(fmt(M.verified), "Verified AI use", "Passers whose website
... [truncated 24934 chars]
```

Result of `Bash`
```
<title>White Circle Pipeline</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&display=swap">
<style>
/* Layout: one calm column, summary first, detailwrote white_circle/docs/dashboard/index.html (181 KB)
185469
False
{
  "objects": [
    {
      "name": "Company",
      "description": "The account. Keyed on domain; holds the fit score and enrichment facts.",
      "attributes": [
        {
          "name": "name",
          "type": "text",
          "source": "crunchbase",
          "written_by": "machine",
          "example": "Example Agent AI"
        },
        {
          "name": "domains",
          "type": "domain",
          "source": "crunchbase / rb2b / form / human",
          "written_by": "machine",
          "example": "example-agent.ai"
        },
        {
          "name": "crunchbase_uui
```

Tool call `ToolSearch`
```
{
 "query": "select:SendMessage",
 "max_results": 1
}
```

Result of `ToolSearch`
```
[omitted: tool-schema lookup]
```

Tool call `Bash`
```
uv run python - <<'E'
import duckdb
c=duckdb.connect('data/white_circle.duckdb',read_only=True)
for r in c.execute("select rank,org_uuid,name,domain,total from mart.top50 order by rank limit 5").fetchall(): print(r)
E
```

Result of `Bash`
```
(1, 'cf909ca8-1b1b-0f1d-a6c9-e83df329a5d7', 'Replit', 'replit.com', 77)
(2, '02dd4a44-954b-4a1d-acbd-e195b73d5e0e', 'Shapes', 'shapes.co', 72)
(3, '0f1bd793-dfdf-433a-896d-c94f5c340938', 'Botpress', 'botpress.com', 64)
(4, '2fde4e6f-4f52-4deb-ba76-f6b9edf1dce0', 'Dash0', 'dash0.com', 57)
(5, '3ab6a3cf-4209-4993-bced-d12f5b078f91', 'Kinfolk', 'kinfolkhq.com', 57)
```

Tool call `SendMessage`
```
{
 "to": "main",
 "summary": "v4 top 5 for deep-dive agents",
 "message": "v4 top 5 (rank, org_uuid, name, domain, total out of 110). Gates, rubric and dq are built and passing; tier cutoffs are 40/25/14, so these five are Tier 1.\n1. cf909ca8-1b1b-0f1d-a6c9-e83df329a5d7  Replit  replit.com  77\n2. 02dd4a44-954b-4a1d-acbd-e195b73d5e0e  Shapes  shapes.co  72\n3. 0f1bd793-dfdf-433a-896d-c94f5c340938  Botpress  botpress.com  64\n4. 2fde4e6f-4f52-4deb-ba76-f6b9edf1dce0  Dash0  dash0.com  57\n5. 3ab6a3cf-4209-4993-bced-d12f5b078f91  Kinfolk  kinfolkhq.com  57\nDossier JSON path: docs/deliverables/accounts/<org_uuid>.json. The dashboard already embeds whatever files exist there. Note: Dash0 and Kinfolk tie at 57, ordered by region (both Europe/NA) then data_confidence.",
 "type": "message",
 "recipient": "main",
 "recipient_kind": "main",
 "content": "v4 top 5 (rank, org_uuid, name, domain, total out…"
}
```

Result of `SendMessage`
```
{"success":true,"message":"Message queued for the main conversation's next turn."}
```

Tool call `Bash`
```
grep -c "panel-crm\|dossier" src/white_circle/templates/dashboard.html; git diff --stat 2>/dev/null | tail -1; ls docs/deliverables/accounts 2>&1 | head -3; uv run whitecircle dashboard && python3 - <<'E'
import re,subprocess
s=open('docs/dashboard/index.html').read()
js=re.findall(r'<script>(.*?)</script>',s,re.S)[-1]
open('[REDACTED_SECRET].js','w').write(js)
E
node --check [REDACTED_SECRET].js && echo syntax ok; which node
```

Result of `Bash`
```
16
 135 files changed, 453 insertions(+), 425 deletions(-)
ls: docs/deliverables/accounts: No such file or directory
wrote white_circle/docs/dashboard/index.html (181 KB)
syntax ok
/opt/homebrew/bin/node
```

Tool call `Bash`
```
cd [REDACTED_SECRET] && (ls node_modules/jsdom >/dev/null 2>&1 || npm i jsdom --silent 2>&1 | tail -2); cat > t.js <<'EOF'
const {JSDOM}=require('jsdom');const fs=require('fs');
const html=fs.readFileSync('white_circle/docs/dashboard/index.html','utf8');
const d=new JSDOM(html,{runScripts:'dangerously',url:'http://x/#crm'});
const w=d.window;w.addEventListener('error',e=>console.log('ERR',e.message));
setTimeout(()=>{const D=w.document;
console.log('crm selected',D.getElementById('tab-crm').getAttribute('aria-selected'),'cards',D.getElementById('crm-cards').children.length);
console.log('rows',D.querySelectorAll('#top-t tbody tr').length,'dive',D.querySelectorAll('button.dive').length);
D.querySelector('button.dive').click();console.log('dossier open',D.getElementById('dossier').className,D.getElementById('dossier').textContent.slice(0,60));
console.log(D.getElementById('funnel-c').textContent.slice(0,120));
console.log(D.getElementById('evo').innerHTML.slice(0,200));
},300);
EOF
node t.js
```

Result of `Bash`
```
crm selected true cards 3
rows 50 dive 5
dossier open open × CloseReplitDeep dive in progressShips: AI agent that build
All companies
      
      3,0001Closed
      
      2,928 (-72)2Acquired
      
      2,822 (-106)3Non-profit
      
  
<h2>How the approach changed</h2>
<p>Short version: every change to the scoring came from looking at real rows. Either the data showed a problem, or what White Circle actually sells did.</p>
<ol><li><
```

Tool call `Bash`
```
uv run python - <<'E'
import csv,duckdb
old=list(csv.DictReader(open('docs/deliverables/archive/top50_v3.1.csv')))
oldr={r['name']:int(r['rank']) for r in old}
c=duckdb.connect('data/white_circle.duckdb',read_only=True)
new={n:r for r,n in c.execute("select rank,name from mart.top50").fetchall()}
common=set(oldr)&set(new)
print(len(common),'kept;',50-len(common),'new;')
print('left:',[ (n,oldr[n]) for n in oldr if n not in new][:50])
print('movers:',sorted([(new[n]-oldr[n],n,oldr[n],new[n]) for n in common])[:5], sorted([(new[n]-oldr[n],n,oldr[n],new[n]) for n in common])[-5:])
# why departed
for n in [n for n in oldr if n not in new][:50]:
    r=c.execute("select first_failed_gate from mart.org_gate where organization_name=?",[n]).fetchone()
    s=c.execute("select s.total from mart.org_score s where organization_name=?",[n]).fetchone()
    print(n,oldr[n],r,s)
E
```

Result of `Bash`
```
40 kept; 10 new;
left: [('Bicksler and Associates', 20), ('CHIL FEMTECH CENTER LIMITED', 21), ('Paces', 25), ('Amical', 35), ('Cosmos', 39), ('Outlex', 40), ('MijnRecht.AI', 41), ('Cardilog Health App', 42), ('Abra', 45), ('Pervaziv AI', 49)]
movers: [(-29, 'Kinfolk', 34, 5), (-29, 'Return Signals', 48, 19), (-26, 'Natural Bot', 50, 24), (-22, 'Journify Learning', 38, 16), (-18, 'Klaimee', 28, 10)] [(27, 'CourtifyAI', 18, 45), (29, 'Regaldi ai', 15, 44), (34, 'ReplyCX', 9, 43), (36, 'UbiGrowth', 6, 42), (37, 'AGENTIC WORKS LTD', 13, 50)]
Bicksler and Associates 20 (None,) (6,)
CHIL FEMTECH CENTER LIMITED 21 (None,) (5,)
Paces 25 ('industry_not_matched',) None
Amical 35 (None,) (8,)
Cosmos 39 (None,) (10,)
Outlex 40 (None,) (6,)
MijnRecht.AI 41 (None,) (10,)
Cardilog Health App 42 (None,) (8,)
Abra 45 ('industry_not_matched',) None
Pervaziv AI 49 ('industry_not_matched',) None
```

Tool call `Bash`
```
uv run python - <<'E'
import duckdb
c=duckdb.connect('data/white_circle.duckdb',read_only=True)
for n in ['UbiGrowth','AGENTIC WORKS LTD','Kinfolk','Klaimee','Paces','Abra']:
    print(n,c.execute("select s.pts_recency,s.pts_revenue,s.pts_headcount,s.pts_bonus,s.total,s.vertical,m.months_since_last_equity,m.revenue_label,m.employees_label from mart.org_master m left join mart.org_score s on s.org_uuid=m.uuid where m.organization_name=?",[n]).fetchall(), c.execute("select vertical from mart.org_master where organization_name=?",[n]).fetchall())
E
grep -n "UbiGrowth\|AGENTIC WORKS\|Kinfolk" docs/deliverables/archive/top50_v3.1.csv | cut -c1-260
```

Result of `Bash`
```
UbiGrowth [(0, 0, 8, 10, 18, 'ai_native', None, None, '11-50')] [('ai_native',)]
AGENTIC WORKS LTD [(0, 0, 0, 10, 10, 'ai_native', None, None, None)] [('ai_native',)]
Kinfolk [(32, 15, 3, 7, 57, 'hr_recruiting', 8, '$1M-$10M', '1-10')] [('hr_recruiting',)]
Klaimee [(40, 0, 3, 7, 50, 'insurance', 6, None, '1-10')] [('insurance',)]
Paces [(None, None, None, None, None, None, 27, '$1M-$10M', '11-50')] [('other',)]
Abra [(None, None, None, None, None, None, 21, None, '1-10')] [('finance_ops',)]
7:6,UbiGrowth,ubigrowth.ai,United States,Regulated GenAI,Tier 1,86,35,25,10,3,0,6,4,3,0.67,"Ships: Governed AI platform doing sales, ops, finance tasks (agentic)","Regulated: fintech / banking, and ships LLMs",Team size 11-50,verified,"Governed AI platform doi
14:13,AGENTIC WORKS LTD,agentic-works.com,United Kingdom,Regulated GenAI,Tier 1,78,35,25,10,3,0,0,5,0,0.33,Ships: On-prem agentic AI and local LLM platform (agentic),"Regulated: fintech / banking, and ships LLMs",Based in EU/UK (AI Act exposure),verified,On-pr
35:34,Kinfolk,kinfolkhq.com,United Kingdom,AI-native builders,Tier 2,79,35,12,0,3,16,3,5,5,1.0,Ships: AI agents answering employee HR requests in Slack/Teams (agentic),Raised a seed round 8 months ago,Sector: hr / recruiting,verified,AI agents answering employ
```

Tool call `Bash`
```
python3 - <<'E'
p='docs/approach-evolution.md'
s=open(p).read()
old="markets. Region (Europe and North America) breaks ties only."
new=old+""" On the real data, 608 of 3,000 companies
   pass all nine gates (no language-AI product removes 1,578 and services firms 494). 10 of the v3.1 top 50
   changed: 3 now fail the industry gate and 7 pass but score too low to stay."""
assert old in s
open(p,'w').write(s.replace(old,new))
E
uv run whitecircle dashboard >/dev/null; sed -n 24,32p docs/approach-evolution.md
```

Result of `Bash`
```
   outranked. It also surfaced 3 competitors (agent control planes, AI gateways). Rule from then
   on: **no company enters the top 50 unverified.**

5. **v4: gates, then a fixed rubric.** Exclusions are now pass/fail, applied before any points:
   closed, acquired, non-AI, wrong industry, competitor, services firm, dead site. The survivors
   are scored on a fixed rubric: recent funding 40, revenue 25, headcount 15, headcount growth 20.
   A fit bonus of up to 10 is anchored on the industries and use cases White Circle already
   markets. Region (Europe and North America) breaks ties only. On the real data, 608 of 3,000 companies
   pass all nine gates (no language-AI product removes 1,578 and services firms 494). 10 of the v3.1 top 50
```

Tool call `Bash`
```
rm -f data/white_circle.duckdb && (uv run whitecircle load && uv run whitecircle merge-reviews && uv run whitecircle build && uv run whitecircle dq && uv run whitecircle segments && uv run whitecircle top50 && uv run whitecircle dashboard && uv run whitecircle enrich-headcount --dry-run) > [REDACTED_SECRET].log 2>&1; echo exit $?; grep -ci "error\|traceback" [REDACTED_SECRET].log; uv run whitecircle build >/dev/null 2>&1; uv run python - <<'E'
import duckdb
c=duckdb.connect('data/white_circle.duckdb',read_only=True)
print(c.execute("select count(*),count(distinct scored_at) from ops.score_history").fetchall())
print(c.execute("select count(*) from dq.score_checks where rows_affected<>0 and action_taken like '0 = pass%'").fetchall())
E
git status --short | head -3; tail -22 [REDACTED_SECRET].log | head -30
```

Result of `Bash`
```
[redacted: outside project scope]
```

**Final report (hand-back)**

Score v4 is built and the from-scratch run came out clean. That run was load, merge-reviews, build, dq, segments, top50, dashboard, then `enrich-headcount --dry-run`. Nothing is committed and everything is inside white_circle/. The v3.1 archive is at docs/deliverables/archive/top50_v3.1.csv.

**Funnel (3,000 orgs):**
- Closed: -72, leaves 2,928.
- Acquired: -106, leaves 2,822.
- Non-profit: -17, leaves 2,805.
- Public: -26, leaves 2,779. These become the Enterprise segment.
- Competitor: -7, leaves 2,772.
- Services firm: -494, leaves 2,278.
- Dead or hijacked site: -28, leaves 2,250.
- No language-AI product: -1,578, leaves 672.
- Industry not matched: -64, leaves 608.

**Pass all gates, by segment:** 608 in total: AI-native builders 472, Marketed verticals 109, Regulated GenAI 27.

**Tier cutoffs on total /110:**
- Tier 1 is 40 or more (47 orgs).
- Tier 2 is 25 to 39 (76).
- Tier 3 is 14 to 24 (136).
- Nurture is below 14 (349).
- The reasoning is in the 70_ header. 238 orgs sit at exactly 9 points, which is just a headcount band with no other signal.
- Cutoffs should be re-picked once PDL growth data lands.

**Top 15** (total, rubric+bonus, months since last equity round, revenue band, headcount, region; verified use is the "Ships:" line):
1. Replit 77, 67+10, 7 months, $100M-$500M, 101-250, US. Verified use: AI agent that builds and deploys apps from prompts.
2. Shapes 72, 65+7, 10, $10M-$50M, 11-50, Israel. AI chat and workflows inside an HR platform.
3. Botpress 64, 54+10, 16, $1M-$10M, 51-100, Canada. Support agents that issue refunds and update accounts.
4. Dash0 57, 47+10, 7, revenue band unknown, 101-250, US. AI trace triage and MCP agent access.
5. Kinfolk 57, 50+7, 8, $1M-$10M, 1-10, UK. HR agents answering employee requests in Slack/Teams.
6. Auctor 54, 48+6, 6, revenue unknown, 11-50, US. AI-generated implementation artifacts for software teams.
7. Smartcat 54, 48+6, 25, $50M-$100M, 251-500, US. AI translation and localization platform.
8. AWorld 52, 47+5, 17, $1M-$10M, 11-50, Italy. AI-generated courses, bank customer learning.
9. GloCoach 52, 49+3, 21, $10M-$50M, 11-50, Singapore. AI leadership advisor.
10. Klaimee 50, 43+7, 6, revenue unknown, 1-10, US. Underwriting agent for insurance.
11. Spellbook 50, 47+3, 12, revenue unknown, 101-250, Canada. AI contract review copilot.
12. Jasper 49, 42+7, 48, $50M-$100M, 251-500, US. Generative marketing agents.
13. Threekit 49, 42+7, 59, $10M-$50M, 51-100, US. AI sales agent that configures products and quotes.
14. Persistence 49, 40+9, 7, revenue unknown, 11-50, US. Voice agents booking appointments and answering patient questions.
15. Sympera AI 49, 39+10, 19, $1M-$10M, 11-50, US. Agentic assistant for bank relationship managers.

**Churn, v3.1 to v4:** 40 of the v3.1 top 50 are still in, 10 changed. Three now fail the industry gate (Paces, Abra, Pervaziv AI). Seven pass the gates but score too low (Bicksler, CHIL Femtech, Amical, Cosmos, Outlex, MijnRecht.AI, Cardilog). Three notable movers:
- **Kinfolk, 34 to 5:** a seed round 8 months ago now earns 32, its $1M-$10M revenue band 15, and the HR-vertical bonus applies. The v3 cap for a 1-10 headcount no longer exists.
- **Klaimee, 28 to 10:** a round 6 months ago earns the full 40 recency points.
- **UbiGrowth, 6 to 42:** it was "Regulated GenAI" on tags. The website check says generic tech, so it is now ai_native with no round or revenue on file and scores 18.

**PDL docs confirmed:**
- The endpoint is `GET /v5/company/enrich` with an `X-Api-Key` header, and `website` or `name` inputs.
- `min_likelihood` is 1-10, and company fields come back top level.
- The headcount fields are `employee_count`, `employee_count_by_month` ("YYYY-MM" keys), and `employee_growth_rate` with keys `3_month`, `6_month`, `12_month`, `24_month`, as fractions.
- Billing is "per match". The free plan is 10 requests/min and "up to 100 monthly records".
- Not confirmed: credits per match (assumed 1), whether a 404 is free, and the 404 body.
- The module docstring in enrich_pdl.py lists confirmed against assumed. Only the parser (against a fixture in the scratchpad) and the dry-run were tested, and no seed rows were invented.

**Dry-run plan:** 608 gate-passers are unfetched. The default cap is 25 credits, so it would make 25 requests (worst case 25 credits, about 2.5 minutes at the free rate). It starts with Centrical, Replit, Shapes, Audion, Botpress.

**Your two additions:**
- **Stated priors and score history:** the weights are described as stated priors in the 50_ header and in every score_weight rationale. `mart.org_score` has `scored_at` next to `score_version`. `mart.score_history` is a view over `ops.score_history`, which is append-only. The ops schema is used because `00_schemas` drops mart on every build. It dedupes on (org_uuid, score_version, input_hash). A rebuild adds 0 rows (608 rows, 1 scored_at).
- **No other changes** beyond what the later messages asked for.

**Dashboard changes:**
- **Tabs:** Accounts and CRM model are real tabs with arrow keys, a URL hash, and localStorage in try/catch. The CRM tab renders `crm_model.json`: 3 cards, each with an attribute table and a "When enrichment runs" list with cost-tier badges.
- **Top-50 table:** ranked by total, with the columns and "?" popover as you specified, and tier next to the segment. The "?" opens on hover, focus and tap.
- **Dossier panel:** the top 5 rows have a "Deep dive →" button. The slide-over closes on Esc or X and renders everything as text, never innerHTML. It shows "Deep dive in progress" until a dossier file exists in `docs/deliverables/accounts/`. I only tested the placeholder, not a populated file.
- **Other sections:** a gate funnel, the rubric table, the fit-bonus rules with evidence, and a verify_next queue (first 40 of 545).
- **Approach section:** "How the approach changed" renders `approach-evolution.md` below the top 50. I edited the .md once. I added to step 5: "On the real data, 608 of 3,000 companies pass all nine gates (no language-AI product removes 1,578 and services firms 494). 10 of the v3.1 top 50 changed: 3 now fail the industry gate and 7 pass but score too low to stay."
- **Test:** a headless jsdom check confirmed the CRM tab opens from the `#crm` hash and the dossier opens.

**Things that look wrong:**
- **Thin verified pool:** only 63 of the 608 gate-passers are website-verified, so the top 50 reaches Nurture-level totals of 10-13 (ranks 47-50). Verifying the `verify_next` queue is the real fix.
- **AI-native is too broad:** 472 of 608 are "AI-native". Any LLM-tagged org with an `other` vertical and a generic-tech, AI-platform or devtools tag passes. That loosens the owner's industry list.
- **Real estate is unreachable:** the category map cannot separate it from physical_economy.
- **v3 vertical mismatches:** a few reviewer verticals override tag-based ones (UbiGrowth, Agentic Works moved from fintech to ai_native).
- **Stale CRM doc:** the CRM view columns were renamed, so `docs/crm-data-model.md` is out of date.
- **Untracked tree:** `white_circle/` is entirely untracked in git, so `git diff` shows no v3 history.
- **No growth data yet:** growth is 0 for everyone until PDL runs, and `ops.score_history` is lost if the db is deleted.

Result of `SubagentHandback`
```
{"success":true,"message":"Report delivered to your caller."}
```
