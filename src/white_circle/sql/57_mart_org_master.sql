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
--     'strong') and whose industry is horizontal. Verified orgs: the reviewer's
--     true_vertical was 'generic_tech'. Unverified orgs: tags gave 'other' AND at least
--     one category token is a generic_tech / ai_platform / devtools_infra sector.
--     A verified generic_tech org that does NOT ship an LLM stays 'generic_tech' (fails).
--   * best buyer contact, flags (is_services_firm, is_competitor), region_bucket
--   * headcount growth, LEFT-joined from stg.headcount_history (56_): hc_current,
--     hc_3m_ago, hc_6m_ago, hc_12m_ago, growth_3m_pct, growth_6m_pct, growth_12m_pct,
--     hc_source, hc_fetched_at. NULL for every org until `enrich-headcount-apollo` has run. An enriched
--     attribute only: the score does not read it.
--     If PDL gave counts but no pct for a window, the pct is computed from the counts.
CREATE TABLE mart.org_master AS
WITH
p AS (SELECT as_of FROM mart.params),
rd AS (
  SELECT org_uuid,
    list(struct_pack(announced_on := announced_on, investment_type := investment_type,
                     is_equity := (round_group = 'equity_venture'),
                     money_raised_usd := money_raised_raw_usd, investor_count := investor_count,
                     lead_investor_names := lead_investor_names)
         ORDER BY announced_on NULLS FIRST, type_rank, investment_type)               AS rounds,
    count(*)                                                                          AS all_rounds_count,
    sum(amount_usd)                                                                   AS all_rounds_usd,
    count(*) FILTER (WHERE round_group = 'equity_venture')                            AS equity_rounds_count,
    sum(amount_usd) FILTER (WHERE round_group = 'equity_venture')                     AS equity_rounds_usd,
    min(announced_on)                                                                 AS first_round_date
  FROM stg.funding_rounds GROUP BY 1),
ainat AS (
  SELECT org_uuid, bool_or(sector IN ('generic_tech', 'ai_platform', 'devtools_infra')) AS has_horizontal_tag
  FROM stg.org_category GROUP BY 1)
SELECT
  o.*,
  coalesce(rd.rounds, [])                                    AS rounds,
  coalesce(rd.all_rounds_count, 0)                           AS all_rounds_count,
  rd.all_rounds_usd,
  coalesce(rd.equity_rounds_count, 0)                        AS equity_rounds_count,
  rd.equity_rounds_usd,
  rd.first_round_date,
  f.last_round_date                                          AS last_equity_date,
  f.last_round_type                                          AS last_equity_type,
  f.last_round_amount_usd                                    AS last_equity_amount_usd,
  f.months_since_last_round                                  AS months_since_last_equity,
  f.llm_level, f.llm_level_source, f.tags_llm_level,
  f.has_verified_review, f.verified_ships_llm, f.verified_llm_use, f.review_confidence,
  rv.true_vertical,
  f.vertical_source, f.is_regulated,
  CASE WHEN f.llm_level = 'strong' AND f.vertical = 'generic_tech'                       THEN 'ai_native'
       WHEN f.llm_level = 'strong' AND f.vertical = 'other' AND f.vertical_source = 'tags'
            AND coalesce(a.has_horizontal_tag, FALSE)                                    THEN 'ai_native'
       ELSE f.vertical END                                   AS vertical,
  f.vertical                                                 AS vertical_v3,
  f.is_agentic, f.evidence_quote, f.site_status,
  f.is_services_firm, f.is_competitor,
  f.region_bucket, f.size_bucket, f.stage_bucket, f.persona_bucket, f.contact_count,
  f.best_contact_name, f.best_contact_title, f.best_contact_bucket,
  f.data_confidence,
  h.hc_current, h.hc_3m_ago, h.hc_6m_ago, h.hc_12m_ago,
  coalesce(h.growth_3m_pct,  CASE WHEN h.hc_3m_ago  > 0 THEN round((h.hc_current::DOUBLE / h.hc_3m_ago  - 1) * 100, 2) END) AS growth_3m_pct,
  coalesce(h.growth_6m_pct,  CASE WHEN h.hc_6m_ago  > 0 THEN round((h.hc_current::DOUBLE / h.hc_6m_ago  - 1) * 100, 2) END) AS growth_6m_pct,
  coalesce(h.growth_12m_pct, CASE WHEN h.hc_12m_ago > 0 THEN round((h.hc_current::DOUBLE / h.hc_12m_ago - 1) * 100, 2) END) AS growth_12m_pct,
  h.hc_source, h.hc_fetched_at
FROM stg.organizations o
CROSS JOIN p
LEFT JOIN rd                          ON rd.org_uuid = o.uuid
LEFT JOIN mart.org_features f         ON f.org_uuid  = o.uuid
LEFT JOIN stg.company_review rv       ON rv.org_uuid = o.uuid AND f.has_verified_review
LEFT JOIN ainat a                     ON a.org_uuid  = o.uuid
LEFT JOIN stg.headcount_history h     ON h.org_uuid  = o.uuid;

CREATE UNIQUE INDEX mart_org_master_org ON mart.org_master (uuid);
