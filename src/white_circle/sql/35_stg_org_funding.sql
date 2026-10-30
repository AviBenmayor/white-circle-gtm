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
         max(announced_on)                AS last_round_date
  FROM venture GROUP BY 1),
last_round AS (
  SELECT org_uuid, investment_type AS last_round_type, round_group AS last_round_group,
         amount_usd AS last_round_amount_usd
  FROM venture
  QUALIFY row_number() OVER (PARTITION BY org_uuid
                             ORDER BY announced_on DESC, type_rank DESC) = 1),
post_ipo AS (
  SELECT org_uuid, count(*) AS post_ipo_round_count
  FROM stg.funding_rounds WHERE is_post_ipo GROUP BY 1),
all_raw AS (
  SELECT org_uuid, sum(money_raised_raw_usd) AS total_incl_post_ipo_raw_usd,
         count(*) AS round_count_all
  FROM stg.funding_rounds GROUP BY 1)
SELECT
  o.uuid AS org_uuid,
  coalesce(a.round_count, 0)               AS round_count,
  (coalesce(a.round_count, 0) > 0)         AS has_funding_round,
  coalesce(a.rounds_with_amount, 0)        AS rounds_with_amount,
  a.total_funding_usd,
  a.first_round_date,
  a.last_round_date,
  l.last_round_type,
  l.last_round_group,
  l.last_round_amount_usd,
  coalesce(p.post_ipo_round_count, 0)      AS post_ipo_round_count,
  o.reported_funding_total_usd             AS reported_total_usd,
  ar.total_incl_post_ipo_raw_usd,
  CASE WHEN o.reported_funding_total_usd IS NULL AND ar.total_incl_post_ipo_raw_usd IS NULL THEN NULL
       ELSE abs(coalesce(o.reported_funding_total_usd, 0)
              - coalesce(ar.total_incl_post_ipo_raw_usd, 0)) < 1 END AS total_matches_reported
FROM stg.organizations o
LEFT JOIN agg a        ON a.org_uuid  = o.uuid
LEFT JOIN last_round l ON l.org_uuid  = o.uuid
LEFT JOIN post_ipo p   ON p.org_uuid  = o.uuid
LEFT JOIN all_raw ar   ON ar.org_uuid = o.uuid;

CREATE UNIQUE INDEX stg_org_funding_org ON stg.org_funding (org_uuid);
