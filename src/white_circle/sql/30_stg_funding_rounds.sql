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
--     venture raises and wreck any average, so every venture metric excludes them.
--  4. round_group collapses ~25 investment types into: equity_venture, non_dilutive
--     (grants, assistance), debt, public_market, other. series_unknown is a real
--     venture round of unknown letter, not "unfunded".
--  5. type_rank is a stable ordering by stage. 21 org+date pairs hold two rounds on
--     the same day (e.g. debt_financing + series_a); "latest round" breaks the tie
--     with the higher rank so the answer is deterministic (the source's own
--     last_funding_type disagreed with the latest round in 4 cases for this reason).
--  6. Date plausibility is FLAGGED, not deleted: round_before_founding (> 1 year
--     before founded_on) and round_after_close. announced_date_precision marks
--     Jan-1 padded dates.
--  7. The denormalised org_name is dropped (it never disagrees with organizations);
--     join for the name.
CREATE TABLE stg.funding_rounds AS
WITH typ(investment_type, round_group, type_rank) AS (VALUES
  ('pre_seed',               'equity_venture',  10),
  ('angel',                  'equity_venture',  12),
  ('convertible_note',       'equity_venture',  15),
  ('equity_crowdfunding',    'equity_venture',  18),
  ('seed',                   'equity_venture',  20),
  ('series_unknown',         'equity_venture',  25),
  ('series_a',               'equity_venture',  30),
  ('series_b',               'equity_venture',  40),
  ('series_c',               'equity_venture',  50),
  ('series_d',               'equity_venture',  60),
  ('series_e',               'equity_venture',  70),
  ('series_f',               'equity_venture',  80),
  ('series_g',               'equity_venture',  90),
  ('series_h',               'equity_venture', 100),
  ('grant',                  'non_dilutive',     5),
  ('non_equity_assistance',  'non_dilutive',     6),
  ('debt_financing',         'debt',            26),
  ('post_ipo_debt',          'debt',           210),
  ('corporate_round',        'other',           28),
  ('private_equity',         'other',          110),
  ('secondary_market',       'other',           27),
  ('undisclosed',            'other',            1),
  ('product_crowdfunding',   'other',            2),
  ('initial_coin_offering',  'other',            3),
  ('post_ipo_equity',        'public_market',  200),
  ('post_ipo_secondary',     'public_market',  205))
SELECT
  r.org_uuid,
  r.investment_type,
  coalesce(t.round_group, 'other')                      AS round_group,
  coalesce(t.type_rank, 0)                              AS type_rank,
  (r.investment_type LIKE 'post_ipo%')                  AS is_post_ipo,
  try_cast(r.announced_on AS DATE)                      AS announced_on,
  CASE WHEN r.announced_on LIKE '%-01-01' THEN 'year' ELSE 'day' END AS announced_date_precision,
  try_cast(r.money_raised_usd AS DOUBLE)                AS money_raised_raw_usd,
  nullif(try_cast(r.money_raised_usd AS DOUBLE), 0)     AS amount_usd,
  try_cast(r.investor_count AS INTEGER)                 AS investor_count,
  nullif(trim(r.lead_investor_names), '')               AS lead_investor_names,  -- free text, not splittable
  coalesce(try_cast(r.announced_on AS DATE) < o.founded_on - INTERVAL 1 YEAR, FALSE) AS round_before_founding,
  coalesce(try_cast(r.announced_on AS DATE) > o.closed_on, FALSE)                    AS round_after_close
FROM raw.funding_rounds r
LEFT JOIN typ t ON t.investment_type = r.investment_type
LEFT JOIN stg.organizations o ON o.uuid = r.org_uuid;

CREATE UNIQUE INDEX stg_funding_rounds_key
  ON stg.funding_rounds (org_uuid, investment_type, announced_on);
