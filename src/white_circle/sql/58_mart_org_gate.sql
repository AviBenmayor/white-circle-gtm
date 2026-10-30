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
       WHEN is_competitor THEN 'is_competitor' WHEN is_services_firm THEN 'is_services_firm'
       WHEN dead_or_hijacked_site THEN 'dead_or_hijacked_site' WHEN not_ai THEN 'not_ai'
       WHEN industry_not_matched THEN 'industry_not_matched' END              AS first_failed_gate,
  (NOT (is_closed OR is_acquired OR is_nonprofit OR is_public OR is_competitor OR is_services_firm
        OR dead_or_hijacked_site OR not_ai OR industry_not_matched))           AS passes_all
FROM g;

CREATE UNIQUE INDEX mart_org_gate_org ON mart.org_gate (org_uuid);

CREATE TABLE mart.gate_funnel AS
WITH order_(step, gate) AS (VALUES
  (1,'is_closed'), (2,'is_acquired'), (3,'is_nonprofit'), (4,'is_public'), (5,'is_competitor'),
  (6,'is_services_firm'), (7,'dead_or_hijacked_site'), (8,'not_ai'), (9,'industry_not_matched')),
r AS (
  SELECT o.step, o.gate,
    (SELECT count(*) FROM mart.org_gate g
      WHERE g.first_failed_gate IS NULL
         OR (SELECT step FROM order_ x WHERE x.gate = g.first_failed_gate) > o.step) AS remaining
  FROM order_ o)
SELECT 0 AS step, 'all orgs' AS gate, (SELECT count(*) FROM mart.org_gate) AS remaining, 0 AS removed_here
UNION ALL
SELECT step, gate, remaining,
       lag(remaining, 1, (SELECT count(*) FROM mart.org_gate)) OVER (ORDER BY step) - remaining
FROM r
ORDER BY step;
