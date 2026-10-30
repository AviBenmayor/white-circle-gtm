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
--   pts_bonus      max 10  fit bonus: best matching vertical tier from mart.fit_bonus_rule
--                          (pts_bonus_vertical) + 4 when the website check found an agent that
--                          takes actions (pts_bonus_agentic), capped at 10. Derived only from
--                          docs/context/whitecircle-research.md; region earns NO points.
--   rubric_total   = recency + revenue + headcount                 (out of 80)
--   total          = rubric_total + pts_bonus                       (out of 90)
-- Headcount growth is NOT scored in this version (no enrichment data; see memo).
-- Missing data = 0 points for that component and nothing more. We do not subtract for
-- unknowns, because most orgs have no round or revenue band: a penalty would
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
-- (fit, funding, revenue, headcount) so the output is deterministic.
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
         WHEN m.employees_min <= 200 THEN '51-200'
         WHEN m.employees_min <= 500 THEN '201-500'
         WHEN m.employees_min <= 1000 THEN '501-1000'
         ELSE '1001+' END AS headcount_level,
    CASE WHEN m.region_bucket IN ('eu_uk', 'us_ca') THEN 1 ELSE 2 END AS region_priority
  FROM mart.org_master m JOIN mart.org_gate g ON g.org_uuid = m.uuid AND g.passes_all),
pts AS (
  SELECT s.*,
    (SELECT points FROM w WHERE component='funding_recency' AND level = s.recency_level)  AS pts_recency,
    (SELECT points FROM w WHERE component='revenue'         AND level = s.revenue_level)  AS pts_revenue,
    (SELECT points FROM w WHERE component='headcount'       AND level = s.headcount_level) AS pts_headcount,
    coalesce((SELECT points FROM mart.fit_bonus_rule b WHERE b.kind='vertical' AND b.key = s.vertical), 0) AS pts_bonus_vertical,
    CASE WHEN s.is_agentic AND s.verified_ships_llm = 'yes'
         THEN (SELECT points FROM mart.fit_bonus_rule b WHERE b.kind='feature' AND b.key='verified_agentic') ELSE 0 END AS pts_bonus_agentic,
    (SELECT tier FROM mart.fit_bonus_rule b WHERE b.kind='vertical' AND b.key = s.vertical) AS bonus_tier
  FROM src s),
tot AS (
  SELECT *,
    least((SELECT points FROM w WHERE component='fit_bonus_cap'), pts_bonus_vertical + pts_bonus_agentic) AS pts_bonus,
    pts_recency + pts_revenue + pts_headcount AS rubric_total
  FROM pts),
sc AS (SELECT *, rubric_total + pts_bonus AS total FROM tot),
cand AS (
  SELECT uuid AS org_uuid, 1 AS prio, pts_bonus AS p,
    CASE WHEN pts_bonus_agentic > 0 AND pts_bonus_vertical > 0 THEN 'Fits White Circle messaging (' || replace(vertical, '_', ' ') || ') and ships agents'
         WHEN pts_bonus_agentic > 0 THEN 'Ships agents that take actions'
         ELSE 'Fits White Circle messaging: ' || replace(vertical, '_', ' ') || ' (' || coalesce(bonus_tier, '') || ')' END AS txt FROM sc
  UNION ALL SELECT uuid, 2, pts_recency,
    CASE WHEN last_equity_date IS NULL THEN 'No equity round on file'
         ELSE CASE WHEN last_equity_type = 'series_unknown' THEN 'Raised a round'
                   WHEN last_equity_type LIKE 'series_%' THEN 'Raised Series ' || upper(substr(last_equity_type, 8))
                   WHEN last_equity_type = 'pre_seed' THEN 'Raised a pre-seed'
                   WHEN last_equity_type = 'seed' THEN 'Raised a seed round'
                   WHEN last_equity_type = 'angel' THEN 'Raised an angel round'
                   ELSE 'Last round: ' || replace(last_equity_type, '_', ' ') END
              || ' ' || months_since_last_equity || ' months ago' END FROM sc
  UNION ALL SELECT uuid, 3, pts_revenue, 'Revenue band ' || coalesce(revenue_label, 'unknown') FROM sc
  UNION ALL SELECT uuid, 4, pts_headcount, 'Team size ' || coalesce(employees_label, 'unknown') FROM sc
  ),
vflag AS (
  SELECT uuid AS org_uuid,
    CASE WHEN llm_level_source = 'verified' AND verified_ships_llm = 'yes' AND verified_llm_use IS NOT NULL
         THEN 'Ships: ' || verified_llm_use || CASE WHEN is_agentic THEN ' (agentic)' ELSE '' END END AS ships_txt
  FROM sc),
ranked AS (
  SELECT c.org_uuid, c.txt, row_number() OVER (PARTITION BY c.org_uuid ORDER BY c.p DESC, c.prio)
         + (v.ships_txt IS NOT NULL)::INT AS rk
  FROM cand c JOIN vflag v USING (org_uuid) WHERE c.p > 0),
reasons AS (
  SELECT v.org_uuid,
    coalesce(v.ships_txt, max(r.txt) FILTER (WHERE r.rk = 1)) AS reason_1,
    max(r.txt) FILTER (WHERE r.rk = 2) AS reason_2,
    max(r.txt) FILTER (WHERE r.rk = 3) AS reason_3
  FROM vflag v LEFT JOIN ranked r USING (org_uuid) GROUP BY v.org_uuid, v.ships_txt)
SELECT s.uuid AS org_uuid, s.organization_name,
  s.llm_level, s.vertical, s.llm_level_source, s.vertical_source, s.has_verified_review,
  s.verified_ships_llm, s.verified_llm_use, s.is_agentic, s.evidence_quote,
  s.recency_level, s.revenue_level, s.headcount_level,
  s.pts_recency, s.pts_revenue, s.pts_headcount,
  s.pts_bonus_vertical, s.pts_bonus_agentic, s.pts_bonus,
  s.rubric_total, s.total,
  s.region_bucket, s.region_priority, s.data_confidence,
  row_number() OVER (ORDER BY s.total DESC, s.region_priority, s.data_confidence DESC, s.organization_name) AS ord,
  'v4' AS score_version,
  current_timestamp::TIMESTAMP AS scored_at,
  r.reason_1, r.reason_2, r.reason_3
FROM sc s LEFT JOIN reasons r ON r.org_uuid = s.uuid;

CREATE UNIQUE INDEX mart_org_score_org ON mart.org_score (org_uuid);
