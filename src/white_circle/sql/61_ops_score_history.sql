-- 61_ops_score_history.sql  ->  ops.score_history (append-only) and view mart.score_history
--
-- WHY. The weights are stated priors to be recalibrated against realized results (see 50_).
-- Recalibrating needs the past: which score did each org have on which date, from which
-- inputs? So every build APPENDS its scores here and never replaces them.
--
-- WHERE. The table lives in schema `ops`, which `00_schemas.sql` does not drop (mart is
-- dropped on every build, which would erase the history). mart.score_history is a plain
-- view over it, so reviewers can find it next to the other score tables.
--
-- DEDUPE KEY. (org_uuid, score_version, input_hash). input_hash is an md5 of everything
-- the score reads: the org's inputs (round dates and types, revenue band, headcount band,
-- vertical, agentic flag, as_of date) PLUS a hash of the weight and
-- bonus tables, so a change to a weight makes new rows even under the same version name.
-- Rebuilding from the same snapshot twice therefore adds ZERO rows; a new data pull, a
-- reweighting adds rows with a new scored_at. A past ranking is
-- reproduced by filtering one scored_at / input_hash and ordering by total.
CREATE SCHEMA IF NOT EXISTS ops;
CREATE TABLE IF NOT EXISTS ops.score_history (
  org_uuid VARCHAR, score_version VARCHAR, input_hash VARCHAR, scored_at TIMESTAMP, as_of DATE,
  pts_recency INTEGER, pts_revenue INTEGER, pts_headcount INTEGER,
  pts_bonus INTEGER, rubric_total INTEGER, total INTEGER, region_priority INTEGER,
  data_confidence DOUBLE);

INSERT INTO ops.score_history
WITH wh AS (
  SELECT md5(coalesce((SELECT string_agg(component || '|' || level || '|' || points, ';' ORDER BY component, level) FROM mart.score_weight), '')
          || coalesce((SELECT string_agg(kind || '|' || key || '|' || points, ';' ORDER BY kind, key) FROM mart.fit_bonus_rule), '')) AS wt),
x AS (
  SELECT s.*, m.last_equity_date, m.last_equity_type, m.revenue_range, m.employee_count_range
  FROM mart.org_score s JOIN mart.org_master m ON m.uuid = s.org_uuid)
SELECT x.org_uuid, x.score_version,
  md5(concat_ws('|', (SELECT as_of FROM mart.params), x.last_equity_date, x.last_equity_type, x.revenue_range,
        x.employee_count_range, x.vertical, x.is_agentic,
        x.verified_ships_llm, x.llm_level, x.region_bucket, (SELECT wt FROM wh))) AS input_hash,
  x.scored_at, (SELECT as_of FROM mart.params),
  x.pts_recency, x.pts_revenue, x.pts_headcount, x.pts_bonus, x.rubric_total, x.total,
  x.region_priority, x.data_confidence
FROM x
WHERE NOT EXISTS (
  SELECT 1 FROM ops.score_history h
  WHERE h.org_uuid = x.org_uuid AND h.score_version = x.score_version
    AND h.input_hash = md5(concat_ws('|', (SELECT as_of FROM mart.params), x.last_equity_date, x.last_equity_type, x.revenue_range,
        x.employee_count_range, x.vertical, x.is_agentic,
        x.verified_ships_llm, x.llm_level, x.region_bucket, (SELECT wt FROM wh))));

CREATE VIEW mart.score_history AS SELECT * FROM ops.score_history;
