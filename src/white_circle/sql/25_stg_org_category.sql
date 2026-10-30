-- 25_stg_org_category.sql  ->  stg.org_category  (long form: one row per org x token)
--
-- `categories` and `category_groups` are '; '-separated strings (never split on
-- commas: four tokens contain commas inside the name). We unnest both columns,
-- trim, lower-case to a canonical form, and de-duplicate, because a token such as
-- "Software" appears in both columns for the same company.
--
-- Each row then picks up its sector and LLM-signal from the maps in 20_. A token
-- missing from the map gets sector 'other' with is_mapped = FALSE, so "mapped to a
-- real sector" and "fell through to the default" stay distinguishable.
CREATE TABLE stg.org_category AS
WITH tokens AS (
  SELECT uuid AS org_uuid,
         lower(trim(unnest(string_split(categories, '; ')))) AS category_token,
         'category' AS src
  FROM raw.organizations WHERE nullif(trim(categories), '') IS NOT NULL
  UNION ALL
  SELECT uuid, lower(trim(unnest(string_split(category_groups, '; ')))), 'group'
  FROM raw.organizations WHERE nullif(trim(category_groups), '') IS NOT NULL),
dedup AS (
  SELECT org_uuid, category_token,
         bool_or(src = 'category') AS in_categories,
         bool_or(src = 'group')    AS in_groups
  FROM tokens WHERE category_token <> ''
  GROUP BY 1, 2)
SELECT d.org_uuid, d.category_token, d.in_categories, d.in_groups,
       coalesce(m.sector, 'other')           AS sector,
       coalesce(m.kind, 'horizontal')        AS sector_kind,
       (m.token IS NOT NULL)                 AS is_mapped,
       l.signal                              AS llm_signal   -- NULL = not an LLM-era tag
FROM dedup d
LEFT JOIN stg.category_map m ON m.token = d.category_token
LEFT JOIN stg.llm_signal_token l ON l.token = d.category_token;
