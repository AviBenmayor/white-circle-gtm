-- 70_mart_segments.sql  ->  mart.tier_cutoff, mart.org_segment, mart.top50, mart.verify_next
--
-- Two separate questions, answered separately:
--   SEGMENT = WHO they are (what kind of buyer, which play to run). Rule-based, so an
--             AE can explain it in one breath. Does not use the score.
--   TIER    = HOW SOON to work them. Cut from the v4 total (out of 90). Gate-passers only.
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
-- TIER CUTOFFS (total out of 90, gate-passers only). Re-picked on the v4 distribution.
-- WHY these numbers is documented next to the values below; the counts are checked live
-- in `whitecircle segments`. Cutoffs live in mart.tier_cutoff so they can move without
-- editing logic.
--   Tier 1   >= 40   AE works these now          (47 accounts)
--   Tier 2   25-39    SDR sequence, AE joins on reply (76)
--   Tier 3   14-24    automated nurture, promote on a trigger such as a new round (136)
--   Nurture  < 14     watch list; re-score on new data (349)
-- WHY (the v4 total is 0-90 over the 608 orgs that pass every gate; counts as built):
--   * The top of the distribution is thin: only 3 orgs score 72+, 13 score 52+, and the
--     counts per point are 9 at 49 and 9 at 41. 40 is the first round number below that 41
--     cluster and gives 47 accounts, about the size a 3-person AE team can work in a
--     quarter (the aim was 40-60). 45 would leave 32, 50 would leave 15: too few to staff.
--   * 238 orgs sit at exactly 9 points: nothing known except a headcount band. That is the
--     "no signal" mass, not a lead list. 14 is the first score above it that needs at least
--     one real fact (a round, a revenue band or a fit bonus), so Tier 3
--     starts at 14 and everything below is Nurture.
--   * 25 splits the 14-39 middle so Tier 2 (76) is a size an SDR sequence can cover and
--     Tier 3 (136) is the automated nurture. 25 is also the revenue sweet-spot value, a
--     round number with no gap to anchor on (the score is a sum of small pieces).
--   * The scale changed from v3 (0-100, tag-based points) to v4 (0-90, rubric), and the
--     population changed (gates remove 80%), so v3's 65/52/42 cannot be reused.
--   * Headcount growth is not scored in this version; if it is added back (20 points),
--     these cutoffs would be RE-PICKED. History in ops.score_history shows before and after.
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
  ('Tier 1', 40, 1), ('Tier 2', 25, 2), ('Tier 3', 14, 3), ('Nurture', 0, 4)
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
  g.segment, g.tier, s.total, s.rubric_total,
  s.pts_recency, s.pts_revenue, s.pts_headcount, s.pts_bonus,
  s.pts_bonus_vertical, s.pts_bonus_agentic,
  s.region_bucket, s.region_priority, s.data_confidence, s.vertical, s.llm_level,
  m.last_equity_date, m.last_equity_type, m.months_since_last_equity, m.revenue_label, m.employees_label,
  m.growth_3m_pct, m.growth_6m_pct, m.growth_12m_pct,
  s.reason_1, s.reason_2, s.reason_3,
  m.best_contact_name, m.best_contact_title,
  s.llm_level_source, s.verified_ships_llm, s.verified_llm_use, s.is_agentic, s.evidence_quote,
  m.site_status
FROM mart.org_score s
JOIN mart.org_segment g USING (org_uuid)
JOIN mart.org_master m ON m.uuid = s.org_uuid
WHERE g.passes_all
  AND s.llm_level_source = 'verified' AND s.verified_ships_llm = 'yes'
  AND m.site_status IN ('live', 'recovered_via_search')
QUALIFY rank <= 50
ORDER BY rank;

CREATE VIEW mart.verify_next AS
SELECT row_number() OVER (ORDER BY s.ord) AS queue_rank,
  s.org_uuid, m.organization_name AS name, m.domain, m.country, g.segment, g.tier, s.total,
  s.llm_level, s.vertical, m.site_status, m.review_confidence, s.reason_1,
  m.best_contact_name, m.best_contact_title
FROM mart.org_score s
JOIN mart.org_segment g USING (org_uuid)
JOIN mart.org_master m ON m.uuid = s.org_uuid
WHERE g.passes_all AND NOT s.has_verified_review;
