# Subagent trace: Build fit score + segments SQL

A delegated subagent (general-purpose). Its prompt, its tool calls and results, and its final report. Same redaction rules as the main session.

## Turn 1 - User (2026-10-29 15:26:24 UTC)

Build the scoring + segmentation layer for the White Circle GTM take-home at white_circle. Read first: `docs/assignment.md`, `docs/data-profile.md`, `README.md`, and the existing SQL in `src/white_circle/sql/` (00–90) plus `src/white_circle/cli.py` and `obs.py` — match their style (numbered SQL files, header comments explaining every choice and WHY in plain words; reviewers read the SQL). White Circle sells an AI-safety / LLM-guardrails platform; reference customers: Lovable (AI-native builder) and neobanks.

Design (decided by the executive; implement faithfully, flag anything that looks wrong rather than silently changing it). These weights are PROVISIONAL — put them in one table so they're easy to change.

1. `50_mart_score_weights.sql`: `mart.score_weight` VALUES table (component, level, points, rationale). as_of date = DATE '2026-10-29' in a one-row `mart.params` table.
2. `55_mart_org_features.sql` → `mart.org_features`, one row per org from stg tables (LEFT JOINs only — 73% have no rounds; never inner-join away orgs):
   - llm_level: 'strong' (category in the llm_signal set from stg.category_map, OR description regex for llm|large language|generative ai|genai|gen ai|ai agent|agentic|chatbot|copilot|gpt|conversational ai), 'nlp_only' (nlp/conversational/speech/voice-ai only), 'ml_only' (generic AI/ML tag only), 'none'.
   - vertical: highest-risk regulated sector the org touches (fintech_banking > insurance > health > legal_compliance > hr_education > security > other) from stg.category_map; is_regulated for the first four.
   - is_competitor: description/category mentions guardrail|ai safety|red team|red-team|llm security|prompt injection|ai governance|model monitoring|hallucination detection — these are competitors/partners, excluded from the AE list.
   - segment_universe: 'out_closed_acquired' (closed or acquired), 'out_nonprofit', 'enterprise' (is_public), 'competitor', else 'core'.
   - funding recency months vs as_of, stage bucket (pre_seed/angel, seed, series_a_c, late_d_plus, unknown) from stg.org_funding/organizations, employees range, region bucket (eu_uk incl. EEA+CH, us_ca, other, unknown), best buyer persona from stg.contacts (cto_eng_leader / ai_ml_leader / security / compliance_risk_legal = 'technical_or_risk_buyer'; ceo_founder only = 'founder_only'; none).
   - data_confidence 0–1 = share of 6 fields known: funding recency, stage, employees, region, any contact, description present.
3. `60_mart_org_score.sql` → `mart.org_score` with one column per component AND total fit_score (0–100):
   - LLM product (max 35): strong 35, nlp_only 20, ml_only 8, none 0.
   - Regulated risk (max 25): fintech_banking 25, insurance 22, health 22, legal_compliance 20, hr_education 10, security 8, other 0.
   - Interaction bonus +10 when llm_level='strong' AND is_regulated (the "LLM × regulated" thesis; cap total at 100).
   - Buying capacity (max 25): recency ≤12mo 12, 12–24mo 7, >24mo 2, unknown 0; stage series_a_c 8, late_d_plus 6, seed 5, pre_seed 2, unknown 0; last round ≥ $10M +5, ≥ $2M +3, else 0.
   - Size (max 10): 51–500 employees 10, 501–1000 7, 11–50 6, 1000+ 5, 1–10 3, unknown 0.
   - Region (max 5): eu_uk 5 (EU AI Act exposure), us_ca 4, other 2, unknown 0.
   - Reachability (max 5): technical_or_risk_buyer 5, founder_only 3, none 0.
   Missing data = 0 points (no penalty beyond that); data_confidence stays a separate column.
   - reason_1..3: the three highest-contributing components in plain words (e.g. "Ships a GenAI chatbot", "Regulated: fintech", "Raised Series B 5 months ago").
4. `70_mart_segments.sql` → `mart.org_segment`: named segment for core orgs: 'Regulated GenAI' (strong LLM + regulated), 'AI-native builders' (strong LLM, not regulated — Lovable lookalikes), 'Regulated AI-adjacent' (regulated, nlp_only/ml_only — neobank lookalikes, nurture until they ship LLMs), 'Low fit' (rest); plus 'Enterprise', 'Competitor', and out-of-universe groups. Priority tier for core: Tier 1 / Tier 2 / Tier 3 / Nurture — pick cutoffs from the fit_score distribution at natural breaks (look at it; aim for Tier 1 roughly 50–120 orgs) and document the cutoffs and why in the SQL header. `mart.top50`: core universe only, ranked by fit_score desc, tie-break data_confidence desc then last funding recency.
5. Add score sanity checks to dq (new `95_dq_score_checks.sql` or extend 90 — your call, keep 90 working): top50 contains no enterprise/competitor/closed/acquired orgs; every core org has a segment; component sums equal fit_score; weights table max points sum to 100+10 bonus capped.
6. CLI: `whitecircle build` should run the new files; add `whitecircle segments` (prints segment × tier counts matrix) and `whitecircle top50` (prints the list and writes `docs/deliverables/top50.csv` with rank, name, domain, country, segment, tier, fit_score, component scores, data_confidence, reason_1..3, best buyer contact name+title if any). Route through obs.py run logging.
7. Verify from scratch: delete only data/white_circle.duckdb, run load → build → dq → segments → top50; all clean.

Do not commit; touch nothing outside white_circle/; don't edit docs other than creating docs/deliverables/top50.csv. Final reply (max 20 lines): segment × tier counts matrix, the tier cutoffs and why, top 10 names with score + segment + reason_1, how many top-50 are EU/UK vs US, count of competitors flagged (list names), and any rule that produced results that looked wrong to you (e.g. public giants or obvious non-fits leaking into the top 50, regex false positives on "gpt"/"agent").

Tool call `Bash`
```
cd white_circle; cat docs/assignment.md docs/data-profile.md README.md | head -300; ls -R src | head -50; wc -l src/white_circle/*.py src/white_circle/sql/*
```

Result of `Bash`
```
# GTM Engineer — Take-Home Exercise

> Source: https://whitecircle.notion.site/GTM-Engineer-Take-Home-Exercise-38fc3dbe97908031bd22cb2d027b3f23 (copied 2026-10-29)


We’re at a critical juncture - revenue and customers, but no repeatability or playbook. Right now we have customers like Lovable and neobanks. Sales were founder-led till recently. We have started using Attio, Clay and are open to other tools as they become needed (eg. Granola for meetings where Attio cannot record, but don’t fixate on this).

Customer segmentation is not defined and we have SDRs and AEs joining soon. SDRs will be almost solely focused on cold calling, other channels should be automated for them. We want to prevent AEs from having to hunt so they can just focus on closing. Paid ads will be running in a few weeks and RB2B has been installed on our website.


---


#### Part 1 - Segmentation
*(Attachment: gtm-takehome-dataset.zip — the three CSVs in `data/raw/`)*
We've given you a slice of Crunchbase company data. It's raw and a little messy, on purpose.

Load it using the tool/tech of your choice, explore it, and use SQL to answer one question: *which companies should our AEs prioritize, and how would you group them into segments?*

- This is open-ended. You decide what "good fit" means for an AI-safety platform sold to companies deploying LLMs, and you defend it. There is no answer key.
- We want to see your SQL, not just conclusions. Show how you handle data quality issues, inconsistent categori
... [truncated 23155 chars]
```

Tool call `Bash`
```
cd white_circle/src/white_circle; cat cli.py obs.py sql/00_schemas.sql sql/20_stg_category_map.sql sql/35_stg_org_funding.sql sql/40_stg_contacts.sql; sed -n 1,177p sql/10_stg_organizations.sql; sed -n 1,60p sql/90_dq_checks.sql; tail -30 sql/90_dq_checks.sql; cat sql/25_stg_org_category.sql
```

Result of `Bash`
```
[redacted: outside project scope]
```

Tool call `Bash`
```
cd white_circle/src/white_circle; cat cli.py | sed -n 40,80p; cat sql/00_schemas.sql; sed -n 1,80p sql/20_stg_category_map.sql; sed -n 80,175p sql/20_stg_category_map.sql | cut -c1-200
```

Tool call `Bash`
```
cd white_circle/src/white_circle; cat sql/35_stg_org_funding.sql sql/40_stg_contacts.sql sql/25_stg_org_category.sql; grep -n "^ *[a-z_]* *\(AS\|,\)" sql/10_stg_organizations.sql | head -0; sed -n 1,177p sql/10_stg_organizations.sql | grep -v "^--" ; sed -n 1,40p sql/90_dq_checks.sql; tail -25 sql/90_dq_checks.sql; sed -n 1,40p obs.py
```

Result of `Bash`
```
@app.command()
def build() -> None:
    """Run src/white_circle/sql/*.sql in numeric order (stg.*, dq.*)."""
    with track_run("build") as run:
        con = duckdb.connect(str(DB))
        try:
            for f in sorted(SQL_DIR.glob("*.sql")):
                con.execute(f.read_text())
                typer.echo(f"ran {f.name}")
            for sch in ("stg", "dq"):
                for (t,) in con.execute(
                        "SELECT table_name FROM information_schema.tables WHERE table_schema=? "
                        "AND table_type='BASE TABLE' ORDER BY 1", [sch]).fetchall():
                    n = con.execute(f"SELECT count(*) FROM {sch}.{t}").fetchone()[0]
                    run.add_rows(n)
                    typer.echo(f"  {sch}.{t}: {n:,}")
        finally:
            con.close()


@app.command()
def dq() -> None:
    """Print the data-quality check table (dq.checks)."""
    with track_run("dq"):
        con = duckdb.connect(str(DB), read_only=True)
        try:
            rows = con.execute(
                "SELECT check_name, rows_affected, action_taken, description "
                "FROM dq.checks ORDER BY ord").fetchall()
        finally:
            con.close()
        w = max(len(r[0]) for r in rows)
        typer.echo(f"{'check':<{w}}  {'rows':>6}  action / description")
        for name, n, action, desc in rows:
            typer.echo(f"{name:<{w}}  {n:>6,}  {action}")
            typer.echo(f"{'':<{w}}  {'':>6}    ({desc})")
-- 00_schemas.sql
-
... [truncated 12472 chars]
```

Result of `Bash`
```
-- 35_stg_org_funding.sql  ->  stg.org_funding  (one row per ORG, all 3,000)
--
-- Per-company funding aggregates rebuilt from the rounds, EXCLUDING post-IPO rounds
-- (public-market transactions are not venture funding, see 30_). We rebuild instead
-- of trusting organizations.funding_* because the source columns are NULL for the
-- 2,200 orgs with no rounds, and last_funding_type is wrong where two rounds share a
-- date.
--
-- Starts from organizations (LEFT JOIN) on purpose: 73% of companies have no round,
-- and an INNER JOIN would silently drop them. "No funding data" is a segment, not an
-- error: has_funding_round = FALSE, counts 0, amounts NULL (never 0).
--
-- total_funding_usd is NULL (not 0) when rounds exist but none disclosed an amount
-- (180 orgs).
--
-- Reconciliation: reported_total_usd comes from the source's funding_total_usd;
-- total_incl_post_ipo_raw_usd re-sums ALL rounds with the source's raw amounts. The
-- profile showed these agree exactly for all 620 orgs that have a total, so
-- total_matches_reported = TRUE is expected; any FALSE is a re-pull regression.
CREATE TABLE stg.org_funding AS
WITH venture AS (
  SELECT * FROM stg.funding_rounds WHERE NOT is_post_ipo),
agg AS (
  SELECT org_uuid,
         count(*)                         AS round_count,
         count(amount_usd)                AS rounds_with_amount,
         sum(amount_usd)                  AS total_funding_usd,
         min(announced_on)                AS first_round_date,
         ma
... [truncated 22074 chars]
```

Tool call `Bash`
```
cd white_circle; cat src/white_circle/paths.py; sed -n 1,71p src/white_circle/sql/30_stg_funding_rounds.sql | grep -n "round_group\|type_rank\|CASE\|WHEN" | head -40; ls data; uv run python -c "
import duckdb;c=duckdb.connect('data/white_circle.duckdb',read_only=True)
print(c.sql('select round_group,investment_type,count(*) from stg.funding_rounds group by 1,2 order by 1,2').fetchall())
print(c.sql('select distinct country from stg.organizations').fetchall())
print(c.sql('select title_bucket,count(*) from stg.contacts group by 1').fetchall())
print(c.sql('select funding_stage_clean,count(*) from stg.organizations group by 1').fetchall())
print(c.sql('select operating_status,count(*) from stg.organizations group by 1').fetchall())
"
```

Result of `Bash`
```
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "data"
RAW = DATA / "raw"
DB = DATA / "white_circle.duckdb"
LOGS = DATA / "logs"
EVENTS = LOGS / "events.jsonl"
SQL_DIR = Path(__file__).resolve().parent / "sql"
12:--  4. round_group collapses ~25 investment types into: equity_venture, non_dilutive
15:--  5. type_rank is a stable ordering by stage. 21 org+date pairs hold two rounds on
25:WITH typ(investment_type, round_group, type_rank) AS (VALUES
55:  coalesce(t.round_group, 'other')                      AS round_group,
56:  coalesce(t.type_rank, 0)                              AS type_rank,
59:  CASE WHEN r.announced_on LIKE '%-01-01' THEN 'year' ELSE 'day' END AS announced_date_precision,
logs
raw
white_circle.duckdb
[('debt', 'debt_financing', 47), ('debt', 'post_ipo_debt', 15), ('equity_venture', 'angel', 69), ('equity_venture', 'convertible_note', 33), ('equity_venture', 'equity_crowdfunding', 16), ('equity_venture', 'pre_seed', 348), ('equity_venture', 'seed', 581), ('equity_venture', 'series_a', 172), ('equity_venture', 'series_b', 81), ('equity_venture', 'series_c', 41), ('equity_venture', 'series_d', 21), ('equity_venture', 'series_e', 9), ('equity_venture', 'series_f', 7), ('equity_venture', 'series_g', 3), ('equity_venture', 'series_h', 2), ('equity_venture', 'series_unknown', 161), ('non_dilutive', 'grant', 94), ('non_dilutive', 'non_equity_assistance', 60), ('other', 'corporate_round', 19), ('other', 'initial_coin_offering', 3), 
... [truncated 2197 chars]
```

Tool call `Bash`
```
cd white_circle/src/white_circle/sql
python3 - <<'EOF'
p='00_schemas.sql'
s=open(p).read()
s=s.replace("DROP SCHEMA IF EXISTS dq CASCADE;","DROP SCHEMA IF EXISTS dq CASCADE;\nDROP SCHEMA IF EXISTS mart CASCADE;").replace("CREATE SCHEMA dq;","CREATE SCHEMA dq;\nCREATE SCHEMA mart;")
s=s.replace("--   dq   : data-quality check log, computed live from raw + stg\n","--   dq   : data-quality check log, computed live from raw + stg\n--   mart : the answer layer: score weights, org features, fit score, segments, top 50\n")
s=s.replace("Dropping stg and dq","Dropping stg, dq and mart")
open(p,'w').write(s)
EOF
cat > 50_mart_score_weights.sql <<'EOF'
-- 50_mart_score_weights.sql  ->  mart.params, mart.score_weight
--
-- THE ONE PLACE the scoring opinion lives. 60_mart_org_score.sql contains no
-- point values: it looks every number up here. To re-weight the model, edit this
-- file and run `whitecircle build`. The weights are PROVISIONAL: they encode a
-- hypothesis about who needs an AI-safety / LLM-guardrails platform, not a fit to
-- closed-won data (there is none: the extract has no customer flag, and neither
-- Lovable nor any neobank is in it).
--
-- The hypothesis in one sentence: a company is a good buyer when it SHIPS LLM
-- features (35 pts, so there is something to guard), in a REGULATED or
-- reputation-sensitive sector (25 pts, so a bad output is expensive), has MONEY and
-- a team big enough to buy (25 + 10 pts), sits in a jurisdiction with rules about it
-- (5 pts, EU AI Act) and has someone we can actually call (5 pts). The two big
-- factors are also multiplied together in spirit: LLM x regulated earns a +10 bonus,
-- because either alone is a weaker lead than both (Lovable ships LLMs and has
-- reputation risk; a neobank is regulated and is adding LLM support).
--
-- Missing data scores 0 for that component and nothing more. We do not subtract for
-- unknowns, because 73% of companies have no funding row and 18% no headcount: a
-- penalty would just rank by "who has a Crunchbase profile". How much we know is a
-- separate column, data_confidence, used to break ties.
--
-- mart.params: as_of is pinned (not current_date) so the ranking never drifts
-- with the day it is run. The snapshot's latest round is 2026-06-20.
CREATE TABLE mart.params AS
SELECT DATE '2026-10-29' AS as_of;

CREATE TABLE mart.score_weight AS
SELECT * FROM (VALUES
  -- LLM product (max 35) [REDACTED_SECRET]
  ('llm_product', 'strong',   35, 'Tagged GenAI / agentic / chatbot / copilot, or says so in its description: it ships generative output that can hallucinate, leak or be jailbroken. This is the product we guard.'),
  ('llm_product', 'nlp_only', 20, 'Classic NLP / speech / conversational tags: close to LLMs and often migrating, but not yet generating free text.'),
  ('llm_product', 'ml_only',   8, 'Generic AI/ML tag only. 67% of the extract has one, so it barely separates good from bad; kept as a small nudge.'),
  ('llm_product', 'none',      0, 'No AI signal: nothing to put a guardrail on.'),
  -- Regulated risk (max 25) [REDACTED_SECRET]
  ('regulated_risk', 'fintech_banking',  25, 'Money movement under financial regulators; a wrong or unsafe answer is a compliance event. Closest to the neobank reference customers.'),
  ('regulated_risk', 'insurance',        22, 'Claims and underwriting decisions are regulated and discriminatory outputs are actionable.'),
  ('regulated_risk', 'health',           22, 'Patient data and clinical advice (HIPAA, medical liability).'),
  ('regulated_risk', 'legal_compliance', 20, 'Hallucinated citations and advice carry professional liability; also includes government.'),
  ('regulated_risk', 'hr_education',     10, 'Hiring and minors are regulated, but enforcement and buying urgency are lower.'),
  ('regulated_risk', 'security',          8, 'Security vendors care about AI risk but are also the likeliest to build it themselves or compete.'),
  ('regulated_risk', 'other',             0, 'No regulated-sector signal.'),

... [truncated 2725 chars]
```

Result of `Bash`
```
(Bash completed with no output)
```

Tool call `Bash`
```
cd white_circle/src/white_circle/sql
cat > 55_mart_org_features.sql <<'EOF'
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
-- vertical: the highest-risk regulated sector any category token maps to, in order
--   fintech_banking > insurance > health > legal_compliance > hr_education > security
--   > other. A company in several sectors is judged by its riskiest one, because one
--   regulated customer base is enough to need the guardrail. hr_education = the
--   'education' sector plus HR / recruiting / staffing tokens (which the shared
--   taxonomy files under business_services).
-- is_competitor: guardrail / AI-safety / red-team / LLM-security vendors. They sell
--   what we sell, so they are partners or competitors, never AE targets.
-- segment_universe: why an org is in or out of the AE list. First match wins:
--   out_closed_acquired > out_nonprofit > enterprise (public) > competitor > core.
--   'enterprise' = publicly listed: a different sales motion, kept visible not deleted.
-- Funding: recency is months from the pinned as_of to the last VENTURE round (post-IPO
--   rounds are already excluded in stg.org_funding). Stage is the highest equity
--   round ever raised (grants, debt and PE do not make a company "Series B"); where
--   there are no rounds we fall back to the source's funding_stage (63 orgs).
-- region: eu_uk = EU27 + EEA (Iceland, Liechtenstein, Norway) + Switzerland + UK, the
--   places the EU AI Act or UK rules reach; us_ca = US and Canada.
-- best contact: persona buckets from stg.contacts. technical_or_risk_buyer = CTO/eng,
--   AI/ML, security or compliance person; founder_only = only CEO/founder on file.
--   Board members, advisors and investors never count.
-- data_confidence: share of 6 fields known (funding recency, stage, headcount, country,
--   any contact, description). Separate from the score; used only as a tie-break and
--   to tell an AE how much of the picture is guesswork.
CREATE TABLE mart.org_features AS
WITH
p AS (SELECT as_of FROM mart.params),
txt AS (
  SELECT o.uuid AS org_uuid,
         lower(coalesce(o.short_description, ''))                         AS d,
         lower(coalesce(o.short_description, '') || ' ' || coalesce(o.categories, '')) AS dc
  FROM stg.organizations o),
cat AS (
  SELECT org_uuid,
    bool_or(llm_signal IS NOT NULL AND llm_signal <> 'nlp')               AS cat_strong,
    bool_or(llm_signal = 'nlp' OR category_token IN ('speech recognition', 'voice ai', 'conversational ai')) AS cat_nlp,
    bool_or(sector = 'ai_platform')                                       AS cat_ml,
    min(CASE
          WHEN sector = 'fintech_banking'  THEN 1
          WHEN sector = 'insurance'        THEN 2
          WHEN sector = 'health'           THEN 3
          WHEN sector = 'le
... [truncated 6119 chars]
```

Result of `Bash`
```
(Bash completed with no output)
```

Tool call `Bash`
```
cd white_circle/src/white_circle/sql
cat > 60_mart_org_score.sql <<'EOF'
-- 60_mart_org_score.sql  ->  mart.org_score  (one row per org, all 3,000)
--
-- Fit score 0-100 = sum of components, each looked up in mart.score_weight (50_),
-- capped at 100. No point value is written in this file. One column per component
-- so a reviewer (or an AE asking "why is this #7?") can see exactly where the points
-- came from:
--   pts_llm        LLM product                       max 35
--   pts_regulated  regulated-sector risk             max 25
--   pts_bonus      LLM x regulated interaction       max 10  (strong LLM AND regulated)
--   pts_capacity   = pts_recency + pts_stage + pts_round_size   max 12 + 8 + 5 = 25
--   pts_size       headcount                         max 10
--   pts_region     EU/UK > US/CA > other             max 5
--   pts_reach      best buyer persona on file        max 5
-- The raw maxima add to 105 + 10 bonus = 115, so the cap at 100 matters for the
-- very best accounts only; it keeps the scale readable as a percentage.
--
-- Missing data = 0 points for that component and nothing more (see 50_). The
-- score is computed for EVERY org, including ones later excluded from the AE list
-- (enterprise, competitors, closed): the exclusion lives in 70_segments, so a
-- public giant can be inspected with the same score and visibly be a non-target.
--
-- reason_1..3: the three components that added the most points, in plain words, for
-- the AE and the CRM. The bonus is folded into the regulated reason (they are one
-- story: "ships LLMs in a regulated sector"); the three funding sub-scores are one
-- reason ("Raised Series B 5 months ago"). Ties keep a fixed order
-- (LLM, regulated, funding, reach, size, region) so the output is deterministic.
CREATE TABLE mart.org_score AS
WITH
w AS (SELECT component, level, points FROM mart.score_weight),
lv AS (
  SELECT f.*,
    CASE WHEN months_since_last_round IS NULL THEN 'unknown'
         WHEN months_since_last_round <= 12 THEN 'le_12m'
         WHEN months_since_last_round <= 24 THEN '12_24m'
         ELSE 'gt_24m' END AS recency_level,
    CASE WHEN last_round_amount_usd >= 10000000 THEN 'ge_10m'
         WHEN last_round_amount_usd >= 2000000  THEN 'ge_2m'
         ELSE 'lt_2m' END AS round_size_level,
    CASE WHEN llm_level = 'strong' AND is_regulated THEN 'strong_llm_x_regulated' END AS bonus_level
  FROM mart.org_features f),
pts AS (
  SELECT l.*,
    coalesce((SELECT points FROM w WHERE component='llm_product'       AND level = l.llm_level), 0)      AS pts_llm,
    coalesce((SELECT points FROM w WHERE component='regulated_risk'    AND level = l.vertical), 0)       AS pts_regulated,
    coalesce((SELECT points FROM w WHERE component='interaction_bonus' AND level = l.bonus_level), 0)    AS pts_bonus,
    coalesce((SELECT points FROM w WHERE component='funding_recency'   AND level = l.recency_level), 0)  AS pts_recency,
    coalesce((SELECT points FROM w WHERE component='funding_stage'     AND level = l.stage_bucket), 0)   AS pts_stage,
    coalesce((SELECT points FROM w WHERE component='round_size'        AND level = l.round_size_level), 0) AS pts_round_size,
    coalesce((SELECT points FROM w WHERE component='size'              AND level = l.size_bucket), 0)    AS pts_size,
    coalesce((SELECT points FROM w WHERE component='region'            AND level = l.region_bucket), 0)  AS pts_region,
    coalesce((SELECT points FROM w WHERE component='reachability'      AND level = l.persona_bucket), 0) AS pts_reach
  FROM lv l),
tot AS (
  SELECT *, pts_recency + pts_stage + pts_round_size AS pts_capacity,
    least(100, pts_llm + pts_regulated + pts_bonus + pts_recency + pts_stage + pts_round_size
               + pts_size + pts_region + pts_reach) AS fit_score
  FROM pts),
cand AS (
  SELECT org_uuid, 1 AS prio, pts_llm AS p,
    CASE llm_level WHEN 'strong' THEN 'Ships a GenAI / LLM product'
                   WHEN 'nlp_only' THEN 'Builds NLP / conversational AI'
               
... [truncated 2105 chars]
```

Result of `Bash`
```
╭───────────────────── Traceback (most recent call last) ──────────────────────╮
│ white_circle/src/white_circle/ │
│ cli.py:47 in build                                                           │
│                                                                              │
│   44 │   │   con = duckdb.connect(str(DB))                                   │
│   45 │   │   try:                                                            │
│   46 │   │   │   for f in sorted(SQL_DIR.glob("*.sql")):                     │
│ ❱ 47 │   │   │   │   con.execute(f.read_text())                              │
│   48 │   │   │   │   typer.echo(f"ran {f.name}")                             │
│   49 │   │   │   for sch in ("stg", "dq"):                                   │
│   50 │   │   │   │   for (t,) in con.execute(                                │
╰──────────────────────────────────────────────────────────────────────────────╯
CatalogException: Catalog Error: Scalar Function with name initcap does not 
exist!
Did you mean "ilike_escape"?
```

Tool call `Bash`
```
cd white_circle
python3 - <<'EOF'
p='src/white_circle/sql/60_mart_org_score.sql'
s=open(p).read()
old="replace(initcap(replace(last_round_type, '_', ' ')), 'Pre Seed', 'Pre-seed')"
new="CASE WHEN last_round_type LIKE 'series_%' THEN 'Series ' || upper(substr(last_round_type, 8)) ELSE upper(left(replace(last_round_type, '_', ' '), 1)) || substr(replace(last_round_type, '_', ' '), 2) END"
assert old in s
open(p,'w').write(s.replace(old,new))
EOF
uv run whitecircle build 2>&1 | tail -8
uv run python - <<'EOF'
import duckdb;c=duckdb.connect('data/white_circle.duckdb',read_only=True)
q=lambda s:print(c.sql(s))
q("select segment_universe,count(*) from mart.org_features group by 1 order by 2 desc")
q("select llm_level,count(*) from mart.org_features group by 1")
q("select vertical,count(*) from mart.org_features where segment_universe='core' group by 1")
q("select fit_score//5*5 b,count(*) from mart.org_score s join mart.org_features f using(org_uuid) where segment_universe='core' group by 1 order by 1 desc")
q("select organization_name from mart.org_features where is_competitor")
EOF
```

Result of `Bash`
```
│   46 │   │   │   for f in sorted(SQL_DIR.glob("*.sql")):                     │
│ ❱ 47 │   │   │   │   con.execute(f.read_text())                              │
│   48 │   │   │   │   typer.echo(f"ran {f.name}")                             │
│   49 │   │   │   for sch in ("stg", "dq"):                                   │
│   50 │   │   │   │   for (t,) in con.execute(                                │
╰──────────────────────────────────────────────────────────────────────────────╯
CatalogException: Catalog Error: Table with name org_segment does not exist!
Did you mean "org_score"?
┌─────────────────────┬──────────────┐
│  segment_universe   │ count_star() │
│       varchar       │    int64     │
├─────────────────────┼──────────────┤
│ core                │         2776 │
│ out_closed_acquired │          178 │
│ enterprise          │           26 │
│ out_nonprofit       │           17 │
│ competitor          │            3 │
└─────────────────────┴──────────────┘

┌───────────┬──────────────┐
│ llm_level │ count_star() │
│  varchar  │    int64     │
├───────────┼──────────────┤
│ ml_only   │         1311 │
│ strong    │          841 │
│ nlp_only  │           45 │
│ none      │          803 │
└───────────┴──────────────┘

┌──────────────────┬──────────────┐
│     vertical     │ count_star() │
│     varchar      │    int64     │
├──────────────────┼──────────────┤
│ fintech_banking  │          445 │
│ other            │         1622 │
│ security         │          167 │
│ heal
... [truncated 988 chars]
```

Tool call `Bash`
```
cd white_circle; ls -la src/white_circle/sql; git status --short | head
```

Result of `Bash`
```
[redacted: outside project scope]
```

Tool call `Bash`
```
cd white_circle; cat src/white_circle/sql/80_crm_export.sql | head -80; git status --short . 
```

Result of `Bash`
```
-- 80_crm_export.sql  ->  crm.company_upsert, crm.person_upsert  (VIEWS only)
--
-- RUNS AFTER 70_ (mart.org_score, mart.org_segment, mart.top50 from the scoring
-- step). Those tables may not exist yet; this file must not be run before they do.
-- It creates no tables and writes no data: each view is one row per Attio record,
-- column names are Attio attribute api_slugs, so the exporter does
--   SELECT * FROM crm.company_upsert  ->  PUT /v2/objects/companies/records?matching_attribute=domains
-- Custom attributes (see docs/crm-data-model.md) are prefixed nothing special; slugs
-- are snake_case and must be created in Attio first.
--
-- Companies with no usable domain (website was social/missing) get match_attribute =
-- 'crunchbase_uuid' instead of 'domains'; the exporter groups by match_attribute
-- because Attio takes ONE matching_attribute per request.
-- Only fields the machine owns are exported. Human-owned fields (owner, lifecycle_stage,
-- notes, MEDDPICC) are deliberately absent so an upsert cannot overwrite them.
CREATE SCHEMA IF NOT EXISTS crm;

CREATE OR REPLACE VIEW crm.company_upsert AS
SELECT
  CASE WHEN o.domain IS NOT NULL THEN 'domains' ELSE 'crunchbase_uuid' END AS match_attribute,
  o.domain                                   AS domains,           -- Attio: [{domain}]
  o.uuid                                     AS crunchbase_uuid,   -- custom, unique
  o.organization_name                        AS name,
  o.short_description                        AS des
... [truncated 2290 chars]
```

Tool call `Bash`
```
cd white_circle
python3 - <<'EOF'
p='src/white_circle/sql/60_mart_org_score.sql'
s=open(p).read()
s=s.replace("""  t.fit_score, t.data_confidence,
  r.reason_1""","""  t.fit_score, t.data_confidence,
  t.region_bucket AS region,
  'v0-provisional' AS score_version,
  -- compatibility aliases for 80_crm_export.sql (CRM field names), same numbers as above
  t.pts_llm + t.pts_bonus AS llm_exposure_score,
  t.pts_regulated         AS buyer_pain_score,
  t.pts_reach             AS reachability_score,
  t.pts_recency           AS timing_score,
  r.reason_1""")
open(p,'w').write(s)
EOF
cat > src/white_circle/sql/70_mart_segments.sql <<'EOF'
-- 70_mart_segments.sql  ->  mart.tier_cutoff, mart.org_segment, mart.top50
--
-- Two separate questions, answered separately:
--   SEGMENT = WHO they are (what kind of buyer, which play to run). Rule-based, so an
--             AE can explain it in one breath. Does not use the score.
--   TIER    = HOW SOON to work them. Cut from fit_score. Only for the core universe.
--
-- Segments (core universe only, first match wins)
--   Regulated GenAI        strong LLM product AND regulated sector. The thesis
--                          account: ships generative output where a bad answer is a
--                          compliance event. Work first.
--   AI-native builders     strong LLM, not regulated. The Lovable lookalikes: the
--                          pain is reputation, jailbreaks and enterprise security
--                          reviews, not a regulator.
--   Regulated AI-adjacent  regulated, but only NLP / generic ML (or no AI signal).
--                          The neobank lookalikes before they ship an LLM feature:
--                          nurture, and re-score when a signal appears.
--   Low fit                everything else: not regulated and no LLM product.
-- Everyone else gets a named group instead of a segment, so nobody is silently
-- dropped and nobody out-of-universe is mixed in: Enterprise (public companies, a
-- different sales motion), Competitor (guardrail / AI-safety vendors: partner or
-- competitor, not AE targets), Out: closed or acquired, Out: nonprofit. Their tier
-- is NULL.
--
-- Tier cutoffs (fit_score of core orgs, 0-100)
--   Tier 1   >= 75   AE works these now
--   Tier 2   60-74   SDR sequence, AE joins on reply
--   Tier 3   50-59   automated nurture, promote on a trigger (new round, hire)
--   Nurture  < 50    watch list; re-score monthly
-- WHY these numbers. The score has no sharp gap (it is a sum of many small pieces),
-- so the cutoffs are chosen from the shape of the histogram, not from a gap:
--   * 94 core orgs score >= 75: inside the 50-120 an AE team of ~3 can actually work
--     in a quarter. 70 would give 121 and 80 only 53.
--   * Below 50 the count roughly doubles every step (239 at 45-49, 363 at 40-44):
--     that is the large "AI-tagged, unremarkable" bulge, the modal company in this
--     sample. 50 is the last point before it, so Tier 1-3 are the companies with a
--     real signal (LLM and/or regulated plus some buying capacity) and Nurture is the
--     bulge.
--   * 60 splits the 50-74 band into two bands of similar size.
-- Cutoffs live in mart.tier_cutoff so they can be moved without editing logic.
-- Counts are checked live in `whitecircle segments`.
--
-- mart.top50: core universe only, best fit_score first; ties broken by higher
-- data_confidence (we know more, so the score is less of a guess), then the more
-- recent last round, then name so the order is deterministic. It also carries the
-- best buyer contact so the CSV is ready for an SDR.
CREATE TABLE mart.tier_cutoff AS
SELECT * FROM (VALUES
  ('Tier 1', 75, 1), ('Tier 2', 60, 2), ('Tier 3', 50, 3), ('Nurture', 0, 4)
) AS t(tier, min_score, ord);

CREATE TABLE mart.org_segment AS
SELECT f.org_uuid, f.segment_universe,
  CASE f.segment_universe
    WHEN 'out_closed_acquired' THEN 'Out: closed or acquired'
    WHEN 'out_nonprofit'       THEN 'Out: nonprofit'
    WHEN 'enterprise
... [truncated 5940 chars]
```

Result of `Bash`
```
ran 00_schemas.sql
ran 10_stg_organizations.sql
ran 20_stg_category_map.sql
ran 25_stg_org_category.sql
ran 30_stg_funding_rounds.sql
ran 35_stg_org_funding.sql
ran 40_stg_contacts.sql
ran 50_mart_score_weights.sql
ran 55_mart_org_features.sql
ran 60_mart_org_score.sql
ran 70_mart_segments.sql
ran 80_crm_export.sql
ran 90_dq_checks.sql
ran 95_dq_score_checks.sql
  stg.category_map: 222
  stg.contacts: 2,697
  stg.funding_rounds: 1,854
  stg.llm_signal_token: 12
  stg.org_category: 27,500
  stg.org_funding: 3,000
  stg.organizations: 3,000
  dq.checks: 62
  dq.score_checks: 12
```

Tool call `Bash`
```
cd white_circle
python3 - <<'EOF'
p='src/white_circle/sql/95_dq_score_checks.sql'
s=open(p).read()
s=s.replace(" GROUP BY CASE WHEN component IN ('funding_recency','funding_stage','round_size') THEN component ELSE component END)"," GROUP BY component)")
open(p,'w').write(s)
p='src/white_circle/cli.py'
s=open(p).read()
s=s.replace('"""whitecircle CLI: load -> build -> dq."""','"""whitecircle CLI: load -> build -> dq -> segments -> top50."""')
s=s.replace("(stg.*, dq.*)","(stg.*, mart.*, dq.*)").replace('for sch in ("stg", "dq"):','for sch in ("stg", "mart", "dq"):')
old=s[s.index("@app.command()\ndef dq()"):]
new='''@app.command()
def dq() -> None:
    """Print the data-quality checks (dq.checks) and the score sanity checks (dq.score_checks)."""
    with track_run("dq"):
        con = duckdb.connect(str(DB), read_only=True)
        try:
            rows = con.execute(
                "SELECT check_name, rows_affected, action_taken, description FROM dq.checks "
                "UNION ALL SELECT check_name, rows_affected, action_taken, description FROM dq.score_checks "
                "ORDER BY 1 IS NULL, (SELECT 0)").fetchall()
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
        order = ["Regulated GenAI", "AI-native builders", "Regulated AI-adjacent", "Low fit",
                 "Enterprise", "Competitor", "Out: closed or acquired", "Out: nonprofit"]
        w = max(len(s) for s in order)
        typer.echo("tier cutoffs (fit_score >=): " + ", ".join(f"{t} {m}" for t, m in cuts))
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
    """Print the ranked top-50 AE list and write docs/deliverables/top50.csv."""
    with track_run("top50") as run:
        con = duckdb.connect(str(DB), read_only=True)
        try:
            out = ROOT / "docs" / "deliverables" / "top50.csv"
            out.parent.mkdir(parents=True, exist_ok=True)
            con.execute(
                "COPY (SELECT rank, name, domain, country, segment, tier, fit_score, "
                "pts_llm AS llm_product_pts, pts_regulated AS regulated_risk_pts, "
                "pts_bonus AS interaction_bonus_pts, pts_capacity AS buying_capacity_pts, "
                "pts_size AS size_pts, pts_region AS region_pts, pts_reach AS reachability_pts, "
                "round(data_confidence, 2) AS data_confidence, reason_1, reason_2,
... [truncated 1407 chars]
```

Result of `Bash`
```
== load
== build
== dq
== segments
== top50

tier cutoffs (fit_score >=): Tier 1 75, Tier 2 60, Tier 3 50, Nurture 0
segment                   Tier 1   Tier 2   Tier 3  Nurture      n/a    total
Regulated GenAI               85       20        0        0        0      105
AI-native builders             7       69      125      504        0      705
Regulated AI-adjacent          2       26       65      598        0      691
Low fit                        0        0        2    1,273        0    1,275
Enterprise                     0        0        0        0       26       26
Competitor                     0        0        0        0        3        3
Out: closed or acquired        0        0        0        0      178      178
Out: nonprofit                 0        0        0        0       17       17
TOTAL                         94      115      192    2,375      224    3,000
 1. Palm                               United States  Regulated GenAI        Tier 1  100  Ships a GenAI / LLM product
 2. Spellbook                          Canada         Regulated GenAI        Tier 1  100  Ships a GenAI / LLM product
 3. Sympera AI                         United States  Regulated GenAI        Tier 1   97  Ships a GenAI / LLM product
 4. Klaimee                            United States  Regulated GenAI        Tier 1   96  Ships a GenAI / LLM product
 5. OhMD                               United States  Regulated GenAI        Tier 1   96  Ships a GenAI / LLM product
 6. Skorppio 
... [truncated 7684 chars]
```

Tool call `Bash`
```
cd white_circle; uv run python - <<'EOF'
import duckdb;c=duckdb.connect('data/white_circle.duckdb',read_only=True)
q=lambda s:print(c.sql(s).fetchall() if 0 else c.sql(s))
c.sql("select rank,name,fit_score,reason_1,reason_2,reason_3 from mart.top50 where rank<=10").show(max_width=250)
c.sql("select region_bucket,count(*) from mart.org_features f join mart.top50 t using(org_uuid) group by 1").show()
c.sql("select t.rank,t.name,f.vertical,f.llm_level,f.stage_bucket,f.size_bucket,f.persona_bucket,substr(f.short_description,1,90) d from mart.top50 t join mart.org_features f using(org_uuid) where rank in (29,30,37,32,3,4,13,18)").show(max_width=250)
# regex-only strong
c.sql("""select count(*) from mart.org_features f where llm_level='strong' and not exists (select 1 from stg.org_category o where o.org_uuid=f.org_uuid and llm_signal is not null and llm_signal<>'nlp')""").show()
c.sql("""select organization_name, regexp_extract(lower(short_description),'\\bllms?\\b|large language|generative ai|\\bgenai\\b|gen ai|ai agent|agentic|chatbot|copilot|\\bgpt\\b|\\bgpt-?[0-9]|conversational ai') m from mart.org_features f where llm_level='strong' and not exists (select 1 from stg.org_category o where o.org_uuid=f.org_uuid and llm_signal is not null and llm_signal<>'nlp') limit 15""").show()
c.sql("select vertical,is_regulated,count(*) from mart.org_features where llm_level='strong' and segment_universe='core' group by all").show()
c.sql("select organization_name, employees_label, ipo_status from mart.org_features f join stg.organizations o on o.uuid=f.org_uuid where segment_universe='core' and employees_min>=1001").show(max_width=200)
c.sql("select organization_name from mart.org_features where segment_universe='enterprise'").show(max_rows=30)
c.sql("select count(*) from mart.top50 where persona_bucket='x'") if 0 else None
c.sql("select f.persona_bucket,count(*) from mart.top50 t join mart.org_features f using(org_uuid) group by 1").show()
EOF
```

Result of `Bash`
```
Exit code 1
┌───────┬──────────────┬───────────┬─────────────────────────────┬───────────────────────────────────────────────┬─────────────────────────────────────┐
│ rank  │     name     │ fit_score │          reason_1           │                   reason_2                    │              reason_3               │
│ int64 │   varchar    │   int32   │           varchar           │                    varchar                    │               varchar               │
├───────┼──────────────┼───────────┼─────────────────────────────┼───────────────────────────────────────────────┼─────────────────────────────────────┤
│     1 │ Palm         │       100 │ Ships a GenAI / LLM product │ Regulated: fintech / banking, and ships LLMs  │ Raised Series UNKNOWN 6 months ago  │
│     2 │ Spellbook    │       100 │ Ships a GenAI / LLM product │ Regulated: legal / compliance, and ships LLMs │ Raised Debt financing 7 months ago  │
│     3 │ Sympera AI   │        97 │ Ships a GenAI / LLM product │ Regulated: fintech / banking, and ships LLMs  │ Raised Seed 19 months ago           │
│     4 │ Klaimee      │        96 │ Ships a GenAI / LLM product │ Regulated: fintech / banking, and ships LLMs  │ Raised Pre seed 6 months ago        │
│     5 │ OhMD         │        96 │ Ships a GenAI / LLM product │ Regulated: health, and ships LLMs             │ Raised Seed 56 months ago           │
│     6 │ Skorppio     │        94 │ Ships a GenAI / LLM product │ Regulated: fintech / banking, and ships LLMs
... [truncated 7161 chars]
```

Tool call `Bash`
```
cd white_circle
python3 - <<'EOF'
p='src/white_circle/sql/60_mart_org_score.sql'
s=open(p).read()
a=s.index("           THEN 'Raised ' ||")
b=s.index("         WHEN last_round_date IS NOT NULL\n           THEN 'Raised a round '")
new="""           THEN CASE
                  WHEN last_round_type LIKE 'series_unknown' THEN 'Raised a round'
                  WHEN last_round_type LIKE 'series_%' THEN 'Raised Series ' || upper(substr(last_round_type, 8))
                  WHEN last_round_type = 'pre_seed' THEN 'Raised a pre-seed'
                  WHEN last_round_type IN ('seed','angel') THEN 'Raised a ' || last_round_type || ' round'
                  ELSE 'Last round: ' || replace(last_round_type, '_', ' ') END
                || ' ' || months_since_last_round || ' months ago'
"""
s=s[:a]+new+s[b:]
open(p,'w').write(s)
EOF
rm data/white_circle.duckdb; for c in load build dq segments top50; do uv run whitecircle $c > /tmp/x.$c 2>&1 || { echo FAIL $c; tail /tmp/x.$c; }; done
uv run python - <<'EOF'
import duckdb;c=duckdb.connect('data/white_circle.duckdb',read_only=True)
c.sql("select rank,name,fit_score,segment,reason_1,reason_2,reason_3 from mart.top50 where rank<=10").show(max_width=300)
c.sql("select country in ('United States') us, region_bucket,count(*) from mart.top50 t join mart.org_features f using(org_uuid) group by all order by 3 desc").show()
c.sql("select count(*) from mart.org_features where llm_level='strong' and segment_universe='core' and (lower(short_description) ~ 'gpt')").show()
c.sql("select organization_name,substr(short_description,1,100) from mart.org_features where is_competitor").show(max_width=250)
EOF
cat /tmp/x.segments; grep -c . docs/deliverables/top50.csv; head -3 docs/deliverables/top50.csv; grep -E "^(top50|core|score|weights|org_without|features)" /tmp/x.dq | awk '{print $1,$2}'; tail -3 data/logs/events.jsonl | cut -c1-200
```

Result of `Bash`
```
┌───────┬──────────────┬───────────┬─────────────────┬─────────────────────────────┬───────────────────────────────────────────────┬──────────────────────────────────────────┐
│ rank  │     name     │ fit_score │     segment     │          reason_1           │                   reason_2                    │                 reason_3                 │
│ int64 │   varchar    │   int32   │     varchar     │           varchar           │                    varchar                    │                 varchar                  │
├───────┼──────────────┼───────────┼─────────────────┼─────────────────────────────┼───────────────────────────────────────────────┼──────────────────────────────────────────┤
│     1 │ Palm         │       100 │ Regulated GenAI │ Ships a GenAI / LLM product │ Regulated: fintech / banking, and ships LLMs  │ Raised a round 6 months ago              │
│     2 │ Spellbook    │       100 │ Regulated GenAI │ Ships a GenAI / LLM product │ Regulated: legal / compliance, and ships LLMs │ Last round: debt financing 7 months ago  │
│     3 │ Sympera AI   │        97 │ Regulated GenAI │ Ships a GenAI / LLM product │ Regulated: fintech / banking, and ships LLMs  │ Raised a seed round 19 months ago        │
│     4 │ Klaimee      │        96 │ Regulated GenAI │ Ships a GenAI / LLM product │ Regulated: fintech / banking, and ships LLMs  │ Raised a pre-seed 6 months ago           │
│     5 │ OhMD         │        96 │ Regulated GenAI │ Ships a GenAI / LLM product │ Regulat
... [truncated 4970 chars]
```

Tool call `Bash`
```
cd white_circle; uv run python - <<'EOF'
import duckdb;c=duckdb.connect('data/white_circle.duckdb',read_only=True)
c.sql("select f.region_bucket, f.country='United States' us,count(*) from mart.top50 t join mart.org_features f using(org_uuid) group by all order by 3 desc").show()
c.sql("select organization_name from mart.org_features where is_competitor").show()
c.sql("select count(*) n_t1_tiny from mart.org_segment g join mart.org_features f using(org_uuid) where tier='Tier 1' and size_bucket in ('1-10','unknown')").show()
EOF
```

Result of `Bash`
```
┌───────────────┬─────────┬──────────────┐
│ region_bucket │   us    │ count_star() │
│    varchar    │ boolean │    int64     │
├───────────────┼─────────┼──────────────┤
│ us_ca         │ true    │           25 │
│ other         │ false   │           14 │
│ eu_uk         │ false   │            8 │
│ us_ca         │ false   │            3 │
└───────────────┴─────────┴──────────────┘

┌───────────────────┐
│ organization_name │
│      varchar      │
├───────────────────┤
│ AceUp, Inc.       │
│ RATIONAL AI SRL   │
│ HumanLens         │
└───────────────────┘

┌───────────┐
│ n_t1_tiny │
│   int64   │
├───────────┤
│        46 │
└───────────┘
```

**Final report (hand-back)**

The scoring and segmentation layer is built, and the from-scratch run was clean. I deleted only data/white_circle.duckdb, then ran load, build, dq, segments and top50. All 12 new score checks pass at 0 rows. Nothing is committed, and I touched nothing outside white_circle/.

**Segment x tier (3,000 orgs)**

| Segment | T1 | T2 | T3 | Nurture | n/a | Total |
|---|---|---|---|---|---|---|
| Regulated GenAI | 85 | 20 | 0 | 0 | 0 | 105 |
| AI-native builders | 7 | 69 | 125 | 504 | 0 | 705 |
| Regulated AI-adjacent | 2 | 26 | 65 | 598 | 0 | 691 |
| Low fit | 0 | 0 | 2 | 1,273 | 0 | 1,275 |
| Enterprise (public) | | | | | 26 | 26 |
| Competitor | | | | | 3 | 3 |
| Out: closed or acquired | | | | | 178 | 178 |
| Out: nonprofit | | | | | 17 | 17 |
| **Total** | 94 | 115 | 192 | 2,375 | 224 | 3,000 |

**Tier cutoffs on fit_score:** Tier 1 is 75 or more, Tier 2 is 60-74, Tier 3 is 50-59, and Nurture is below 50. The cutoffs sit in `mart.tier_cutoff` so they are easy to move.
- There is no sharp gap in the scores, so I picked them from the histogram.
- 75 gives 94 Tier 1 orgs. 70 would give 121 and 80 only 53.
- Below 50 the count roughly doubles each step (239 at 45-49), which is the "AI-tagged but unremarkable" bulge. 50 is the last point before it.

**Top 10 (score, segment, reason_1):**
1. Palm 100
2. Spellbook 100
3. Sympera AI 97
4. Klaimee 96
5. OhMD 96
6. Skorppio 94
7. Private Labs 93
8. Natural Bot 93
9. Abra 91
10. Botcopy 90

All ten are Regulated GenAI, and reason_1 is "Ships a GenAI / LLM product" for each. Replit, the nearest Lovable lookalike, is #44.

**Top-50 region:** 8 are EU/UK and 28 are US/Canada (25 US, 3 Canada). 14 are elsewhere.

**Competitors flagged:** AceUp, Inc.; RATIONAL AI SRL; HumanLens.

**Things that looked wrong**
- **Regulated is too broad, and the top 50 is full of small dev shops.**
  - The `fintech_banking` mapping in stg.category_map includes blockchain, web3, crypto, accounting and billing. Fitness maps to health and government maps to legal.
  - So a game studio (NipsApp), a Web3 agency (Techwiz) and a "Training App for Competitive Athletes" (Advanced Training Athletic Club) all earn 25 points plus the 10 bonus and sit in the top 50.
  - 46 of the 94 Tier 1 orgs have a headcount of 1-10 or unknown.
  - I did not change it. I suggest narrowing the mapping (drop crypto, web3 and fitness from regulated) or adding a size gate for Tier 1.
- **The weights sum to 105, not 100.** Base maxima are 35 + 25 + 25 + 10 + 5 + 5 = 105, plus the 10 bonus. The cap at 100 does the work and I kept your numbers. Check 907 documents this.
- **The "nlp" signal in stg.llm_signal_token is not counted as strong.** I treated it as nlp_only, as your spec describes. Treating it as strong would flag more orgs.
- **Funding-recency noise.** The "last round" can be debt or `series_unknown`, which still earns recency points. Reasons read "Last round: debt financing 7 months ago" for Spellbook and Botcopy. OhMD's last round was 56 months ago and it still ranks #5 on LLM x regulated points.
- **The regexes held up.**
  - `gpt` and `agent` use word boundaries or require "ai agent", and I found no false positives.
  - About 47 core orgs are "strong" on description text only; the 15 I spot-checked were genuine.
  - The competitor regex caught only the 3 orgs the profile already named.
- **`80_crm_export.sql` appeared mid-task.** It is not mine, and it needs columns I did not plan. I added compatibility columns to `mart.org_score`: `score_version`, `region`, `llm_exposure_score`, `buyer_pain_score`, `reachability_score` and `timing_score`. They duplicate existing components, and `mart.top50` already provides `rank`. The build now runs 80 cleanly, but whoever owns it should confirm the aliases fit.

**What changed**
- New SQL in src/white_circle/sql/: 50_mart_score_weights.sql, 55_mart_org_features.sql, 60_mart_org_score.sql, 70_mart_segments.sql and 95_dq_score_checks.sql.
- Also edited in that folder: 00_schemas.sql (adds the `mart` schema). 90_dq_checks.sql is unchanged.
- src/white_circle/cli.py: `build` now covers mart, `dq` also prints `dq.score_checks`, and `segments` and `top50` are new. Both new commands use obs.py run logging.
- Output: docs/deliverables/top50.csv (50 rows plus header).

Result of `SubagentHandback`
```
{"success":true,"message":"Report delivered to your caller."}
```
