-- 95_dq_score_checks.sql  ->  dq.score_checks
--
-- Checks on the master table, the gates and the v4 score. Kept apart from
-- 90_dq_checks.sql (raw/stg data quality). Same convention: rows_affected = 0 is PASS,
-- except rows labelled INFO. `whitecircle dq` prints both.
CREATE TABLE dq.score_checks AS
WITH checks(ord, check_name, description, rows_affected, action_taken) AS (
  -- master table ------------------------------------------------------------------------
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
      WHERE m.equity_rounds_count <> len(list_filter(m.rounds, lambda x: x.is_equity))),
    '0 = pass'
  -- gates ---------------------------------------------------------------------------------
  UNION ALL SELECT 910, 'gate_one_row_per_org', 'ASSERT: orgs without exactly one mart.org_gate row',
    (SELECT abs(count(*) - (SELECT count(*) FROM mart.org_master)) + abs(count(*) - count(DISTINCT org_uuid)) FROM mart.org_gate), '0 = pass'
  UNION ALL SELECT 911, 'funnel_not_monotonic', 'ASSERT: gate_funnel steps where remaining rises, or the last step differs from the gate-passers',
    (SELECT count(*) FROM (SELECT remaining, lag(remaining) OVER (ORDER BY step) AS prev FROM mart.gate_funnel) WHERE prev IS NOT NULL AND remaining > prev)
     + abs((SELECT remaining FROM mart.gate_funnel ORDER BY step DESC LIMIT 1) - (SELECT count(*) FROM mart.org_gate WHERE passes_all)),
    '0 = pass. Each gate can only remove rows'
  UNION ALL SELECT 912, 'industry_gate_missing_vertical', 'Orgs whose vertical has no row in mart.vertical_gate (would silently fail gate 9)',
    (SELECT count(*) FROM mart.org_master m WHERE NOT EXISTS (SELECT 1 FROM mart.vertical_gate v WHERE v.vertical = m.vertical)),
    '0 = pass. Catches a new vertical bucket in 55_/57_ that 50_ does not list'
  -- score ----------------------------------------------------------------------------------
  UNION ALL SELECT 920, 'score_only_gate_passers', 'ASSERT: scored orgs that do not pass every gate, or passers without a score',
    (SELECT count(*) FROM mart.org_score s JOIN mart.org_gate g USING (org_uuid) WHERE NOT g.passes_all)
     + (SELECT count(*) FROM mart.org_gate g WHERE g.passes_all AND NOT EXISTS (SELECT 1 FROM mart.org_score s WHERE s.org_uuid = g.org_uuid)), '0 = pass'
  UNION ALL SELECT 921, 'top50_gate_failure', 'ASSERT: every top-50 org passes all gates (top-50 rows that do not)',
    (SELECT count(*) FROM mart.top50 t JOIN mart.org_gate g USING (org_uuid) WHERE NOT g.passes_all), '0 = pass'
  UNION ALL SELECT 922, 'score_component_sum_mismatch', 'ASSERT: orgs where component sum differs from total',
    (SELECT count(*) FROM mart.org_score WHERE pts_recency + pts_revenue + pts_headcount + pts_bonus <> total
        OR pts_recency + pts_revenue + pts_headcount <> rubric_total), '0 = pass. total is exactly the sum of the visible columns'
  UNION ALL SELECT 923, 'bonus_over_10', 'ASSERT: orgs with a fit bonus above 10',
    (SELECT count(*) FROM mart.org_score WHERE pts_bonus > 10 OR pts_bonus < 0), '0 = pass'
  UNION ALL SELECT 924, 'rubric_max_not_80', 'ASSERT: sum of the rubric component maxima differs from 80 (40+25+15)',
    (SELECT abs((SELECT max(points) FROM mart.score_weight WHERE component = 'funding_recency')
              + (SELECT max(points) FROM mart.score_weight WHERE component = 'revenue')
              + (SELECT max(points) FROM mart.score_weight WHERE component = 'headcount')
              - 80)),
    '0 = pass. Weights 40/25/15'
  UNION ALL SELECT 925, 'component_over_max', 'ASSERT: orgs with a component above its maximum (40/25/15)',
    (SELECT count(*) FROM mart.org_score WHERE pts_recency > 40 OR pts_revenue > 25 OR pts_headcount > 15), '0 = pass'
  UNION ALL SELECT 926, 'total_out_of_range', 'Orgs with total outside 0-90',
    (SELECT count(*) FROM mart.org_score WHERE total < 0 OR total > 90), '0 = pass'
  UNION ALL SELECT 927, 'score_level_missing_weight', 'Orgs whose derived level has no row in mart.score_weight (would silently score NULL)',
    (SELECT count(*) FROM mart.org_score s
      WHERE s.pts_recency IS NULL OR s.pts_revenue IS NULL OR s.pts_headcount IS NULL), '0 = pass. Catches a typo in a level name in 50_ or 60_'
  UNION ALL SELECT 928, 'bonus_unsupported_by_research', 'Bonus rows whose vertical has no fit_bonus_rule row (silently 0)',
    (SELECT count(DISTINCT vertical) FROM mart.org_score s WHERE NOT EXISTS (SELECT 1 FROM mart.fit_bonus_rule b WHERE b.kind = 'vertical' AND b.key = s.vertical)),
    'INFO: a vertical that passes the industry gate but earns no bonus row is scored 0 for the bonus'
  UNION ALL SELECT 929, 'agentic_bonus_unverified', 'Orgs given the agentic bonus without a verified customer-facing LLM',
    (SELECT count(*) FROM mart.org_score WHERE pts_bonus_agentic > 0 AND NOT (is_agentic AND verified_ships_llm = 'yes')), '0 = pass'
  UNION ALL SELECT 930, 'score_history_dupes', 'ASSERT: duplicate (org_uuid, score_version, input_hash) rows in ops.score_history',
    (SELECT count(*) - count(DISTINCT (org_uuid, score_version, input_hash)) FROM ops.score_history), '0 = pass. History is append-only and deduped'
  -- top 50 and queue --------------------------------------------------------------------------
  UNION ALL SELECT 940, 'top50_size', 'Top-50 rows short of 50 (50 - rows)',
    (SELECT 50 - count(*) FROM mart.top50), '0 = pass'
  UNION ALL SELECT 941, 'top50_not_verified', 'ASSERT: top-50 rows without a verified (high/medium, live site) ships=yes check',
    (SELECT count(*) FROM mart.top50 WHERE NOT (llm_level_source = 'verified' AND verified_ships_llm = 'yes' AND site_status IN ('live', 'recovered_via_search'))), '0 = pass'
  UNION ALL SELECT 942, 'top50_not_sorted_by_total', 'ASSERT: top-50 rank order violates total desc, then region_priority, data_confidence desc, name',
    (SELECT count(*) FROM (SELECT total, region_priority, data_confidence, name,
        lag(total) OVER (ORDER BY rank) pt, lag(region_priority) OVER (ORDER BY rank) pr,
        lag(data_confidence) OVER (ORDER BY rank) pd, lag(name) OVER (ORDER BY rank) pn FROM mart.top50)
      WHERE pt IS NOT NULL AND (total > pt
        OR (total = pt AND region_priority < pr)
        OR (total = pt AND region_priority = pr AND data_confidence > pd)
        OR (total = pt AND region_priority = pr AND data_confidence = pd AND name < pn))), '0 = pass'
  UNION ALL SELECT 943, 'verify_next_size', 'INFO: gate-passers not yet verified (mart.verify_next)',
    (SELECT count(*) FROM mart.verify_next), 'Information: work this queue top-down'
  UNION ALL SELECT 944, 'org_without_segment', 'Orgs (any universe) with no segment',
    (SELECT count(*) FROM mart.org_master m WHERE NOT EXISTS (SELECT 1 FROM mart.org_segment g WHERE g.org_uuid = m.uuid AND g.segment IS NOT NULL)), '0 = pass. Nobody silently dropped'
  UNION ALL SELECT 945, 'passer_without_tier', 'Gate-passers with no tier',
    (SELECT count(*) FROM mart.org_segment WHERE passes_all AND tier IS NULL), '0 = pass'
  UNION ALL SELECT 950, 'growth_not_yet_enriched', 'INFO: gate-passers with no headcount-growth data yet (enrichment not run; growth is not scored)',
    (SELECT count(*) FROM mart.org_score s JOIN mart.org_master m ON m.uuid = s.org_uuid WHERE m.growth_12m_pct IS NULL AND m.growth_6m_pct IS NULL AND m.growth_3m_pct IS NULL),
    'Information: growth is a future enriched attribute (`whitecircle enrich-headcount-apollo`); nothing in the score reads it'
  UNION ALL SELECT 951, 'review_rows_ignored', 'INFO: review rows ignored (low/missing confidence, or org not in the extract)',
    (SELECT count(*) FROM stg.company_review r WHERE r.confidence NOT IN ('high','medium') OR r.confidence IS NULL
        OR NOT EXISTS (SELECT 1 FROM mart.org_master f WHERE f.uuid = r.org_uuid)), 'Information'
)
SELECT ord, check_name, description, rows_affected::BIGINT AS rows_affected, action_taken FROM checks;
