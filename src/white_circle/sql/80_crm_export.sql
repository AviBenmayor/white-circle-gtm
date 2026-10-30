-- 80_crm_export.sql  ->  crm.company_upsert, crm.person_upsert  (VIEWS only)
--
-- RUNS AFTER 70_ (mart.org_score, mart.org_segment, mart.top50 from the scoring
-- step). Those tables may not exist yet; this file must not be run before they do.
-- It creates no tables and writes no data: each view is one row per Attio record,
-- column names are Attio attribute api_slugs, so the exporter does
--   SELECT * FROM crm.company_upsert  ->  PUT /v2/objects/companies/records?matching_attribute=domains
-- Custom attributes (see docs/part1-crm-model/crm-data-model.md) are prefixed nothing special; slugs
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
  s.total                                    AS fit_score,          -- v4: out of 90
  s.rubric_total, s.score_version, s.scored_at, s.data_confidence,
  s.pts_recency                              AS score_component_funding_recency,
  s.pts_revenue                              AS score_component_revenue,
  s.pts_headcount                            AS score_component_headcount,
  s.pts_bonus                                AS score_component_fit_bonus,
  s.llm_level_source, s.verified_llm_use,
  g.segment, g.tier, g.first_failed_gate,
  s.llm_level, s.vertical, x.region_bucket   AS region,
  x.is_services_firm,
  t.rank                                     AS top50_rank,
  s.reason_1, s.reason_2, s.reason_3
FROM stg.organizations o
JOIN mart.org_score   s ON s.org_uuid = o.uuid          -- v4: gate-passers only
JOIN mart.org_segment g ON g.org_uuid = o.uuid
JOIN mart.org_features x ON x.org_uuid = o.uuid
LEFT JOIN stg.org_funding f ON f.org_uuid = o.uuid
LEFT JOIN mart.top50  t ON t.org_uuid = o.uuid
WHERE o.is_operating;   -- closed / acquired / public / nonprofit never reach the CRM

CREATE OR REPLACE VIEW crm.person_upsert AS
SELECT
  -- Crunchbase export has no person emails: match on the custom unique key until
  -- Clay supplies one, then the exporter switches to email_addresses.
  'crunchbase_person_key'                    AS match_attribute,
  c.org_uuid || ':' || c.person_uuid         AS crunchbase_person_key,  -- custom, unique
  c.person_name                              AS name,
  c.job_title                                AS job_title,
  c.roles                                    AS roles_all,
  c.title_bucket                             AS persona,                -- select
  c.is_buyer_persona                         AS is_buyer_persona,
  c.person_linkedin_url                      AS linkedin,
  c.person_country                           AS country,
  o.domain                                   AS company_domain          -- Attio: record-ref via match
FROM stg.contacts c
JOIN stg.organizations o ON o.uuid = c.org_uuid
WHERE o.is_operating
  AND NOT c.is_non_buyer;
