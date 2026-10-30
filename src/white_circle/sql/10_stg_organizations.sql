-- 10_stg_organizations.sql  ->  stg.organizations  (one row per company, 3,000)
--
-- Source: raw.organizations (all VARCHAR). Principle: never delete a row here.
-- Every problem becomes a FLAG, so the scoring step later decides what to exclude
-- and the dq log can count exactly what was flagged and why.
--
-- FIXES (each one maps to a check in 90_dq_checks.sql):
--  1. Blank strings -> NULL (nullif/trim). Unknown is NULL, never 0 or ''.
--  2. domain: websites arrive as http://, https://, www., trailing slash, paths and
--     "?utm_source=crunchbase". We reduce to a bare lower-case host so it can be a
--     join key for enrichment. A few "websites" are social or free-hosted pages (linkedin.com,
--     sites.google.com ...): that is not the company's domain, so domain is NULL
--     and website_is_social is TRUE.
--  3. Status flags. operating_status only says active/closed, but 127 companies have
--     funding_stage = 'm_and_a' (acquired); 106 of them are still 'active'. An
--     acquired company is not a buyer, so is_acquired uses BOTH columns and
--     acquired_but_active records the trap. ipo_status is trusted over funding_stage
--     for is_public (3 public companies lack funding_stage = 'ipo').
--     is_operating = none of closed / acquired / public / nonprofit.
--  4. funding_stage mixed two ideas (funding maturity AND exit state). We split it:
--     funding_stage_clean keeps only maturity (seed, early, late, PE); exit state
--     lives in is_acquired / is_public.
--  5. founded_on is year-only data padded to Jan 1 for 53% of rows. We expose
--     founded_year (safe) and founded_date_precision ('year' or 'day'); do not
--     compute month-level ages from 'year' rows. A genuine Jan 1 founding would be
--     mislabelled 'year', which is the safe direction.
--  6. employee_count_range / revenue_range are codes (c_00011_00050, r_00001000).
--     Decoded through lookups below into min/max integers and a readable label.
--     NULL stays NULL (never imputed). r_00000000 is a real band (< $1M), not null.
--     Revenue codes are band lower bounds in thousands of USD; the upper bound of
--     each band is the next band's start (Crunchbase convention, our inference).
--  7. contact_email: 'info@', 'hello@' etc. are shared inboxes, not people
--     (contact_email_is_generic); gmail & co. are freemail. The email's domain
--     differs from the website's on ~330 rows, so we never derive a domain from the
--     email; email_domain_matches_website records agreement (NULL if either side is
--     missing).
--  8. company_type NULL -> 'unknown' (79 rows).
--  9. Geography is null in all three of city/region/country together (375 rows):
--     one has_geo flag.
-- 10. short_description is capped at 140 chars by the source and has non-breaking
--     spaces; we replace U+00A0 with a space and flag description_truncated.
-- 11. categories / category_groups kept raw here; see 20_/25_ for the long form.
CREATE TABLE stg.organizations AS
WITH
emp(code, employees_min, employees_max, employees_label, employees_order) AS (VALUES
  ('c_00001_00010',     1,    10, '1-10',          1),
  ('c_00011_00050',    11,    50, '11-50',         2),
  ('c_00051_00100',    51,   100, '51-100',        3),
  ('c_00101_00250',   101,   250, '101-250',       4),
  ('c_00251_00500',   251,   500, '251-500',       5),
  ('c_00501_01000',   501,  1000, '501-1,000',     6),
  ('c_01001_05000',  1001,  5000, '1,001-5,000',   7),
  ('c_05001_10000',  5001, 10000, '5,001-10,000',  8),
  ('c_10001_max',   10001,  NULL, '10,001+',       9)),
rev(code, revenue_min_usd, revenue_max_usd, revenue_label, revenue_order) AS (VALUES
  ('r_00000000',           0,    1000000, 'under $1M',     1),
  ('r_00001000',     1000000,   10000000, '$1M-$10M',      2),
  ('r_00010000',    10000000,   50000000, '$10M-$50M',     3),
  ('r_00050000',    50000000,  100000000, '$50M-$100M',    4),
  ('r_00100000',   100000000,  500000000, '$100M-$500M',   5),
  ('r_00500000',   500000000, 1000000000, '$500M-$1B',     6),
  ('r_01000000',  1000000000,10000000000, '$1B-$10B',      7),
  ('r_10000000', 10000000000,       NULL, '$10B+',         8)),
-- local parts that mean "a shared mailbox", not a person
generic_local(lp) AS (VALUES
  ('info'),('hello'),('hi'),('hey'),('contact'),('contactus'),('support'),('sales'),
  ('team'),('admin'),('office'),('mail'),('enquiries'),('enquiry'),('inquiries'),
  ('inquiry'),('help'),('marketing'),('press'),('media'),('careers'),('jobs'),
  ('hr'),('general'),('service'),('services'),('billing'),('accounts'),('business'),
  ('partners'),('partnerships'),('founders'),('welcome'),('ask'),('connect'),('hola'),
  ('contacto'),('kontakt'),('mailbox'),('reception'),('privacy'),('legal'),('feedback'),
  ('customerservice'),('customersupport'),('bonjour'),('ciao'),('post'),
  ('contato'),('comercial'),('information'),('orders'),('cs'),('pr'),('bd')),
freemail(d) AS (VALUES
  ('gmail.com'),('googlemail.com'),('yahoo.com'),('hotmail.com'),('outlook.com'),
  ('live.com'),('msn.com'),('icloud.com'),('me.com'),('aol.com'),('proton.me'),
  ('protonmail.com'),('gmx.com'),('gmx.de'),('mail.com'),('yandex.com'),('yandex.ru'),
  ('qq.com'),('163.com'),('126.com'),('yahoo.co.uk'),('hotmail.co.uk'),('web.de')),
social(d) AS (VALUES
  ('linkedin.com'),('facebook.com'),('instagram.com'),('twitter.com'),('x.com'),
  ('youtube.com'),('tiktok.com'),('linktr.ee'),('medium.com'),('github.com'),
  ('crunchbase.com'),('sites.google.com'),('notion.site'),('wixsite.com'),('carrd.co')),
-- step 1: blanks to NULL; step 2: peel the URL one layer at a time
base AS (
  SELECT o.*,
         nullif(trim(website_url), '')                         AS website_raw,
         nullif(trim(contact_email), '')                       AS email_raw
  FROM raw.organizations o),
dom AS (
  SELECT b.*,
    -- lower-case -> drop scheme -> drop www. -> drop path/query/fragment -> drop port
    regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace(lower(website_raw), '^[a-z][a-z0-9+.-]*://', ''),
          '^www[0-9]*\.', ''),
        '[/?#].*$', ''),
      ':[0-9]+$', '')                                          AS host
  FROM base b)
SELECT
  d.uuid,
  d.organization_name,
  d.website_url,
  CASE WHEN s.d IS NOT NULL THEN NULL
       ELSE nullif(d.host, '') END                             AS domain,
  (s.d IS NOT NULL)                                            AS website_is_social,
  nullif(trim(d.linkedin_url), '')                             AS linkedin_url,
  replace(nullif(trim(d.short_description), ''), chr(160), ' ') AS short_description,
  length(d.short_description) >= 139                           AS description_truncated,
  d.categories,
  d.category_groups,

  -- status flags ------------------------------------------------------------
  d.operating_status,
  coalesce(nullif(trim(d.company_type), ''), 'unknown')        AS company_type,
  d.ipo_status,
  (d.funding_stage = 'm_and_a' OR d.operating_status = 'acquired')            AS is_acquired,
  (d.funding_stage = 'm_and_a' AND d.operating_status = 'active')             AS acquired_but_active,
  (d.operating_status = 'closed')                              AS is_closed,
  (d.ipo_status = 'public')                                    AS is_public,
  (d.company_type = 'non_profit')                              AS is_nonprofit,
  NOT ( coalesce(d.funding_stage = 'm_and_a' OR d.operating_status = 'acquired', FALSE)
     OR coalesce(d.operating_status = 'closed', FALSE)
     OR coalesce(d.ipo_status = 'public', FALSE)
     OR coalesce(d.company_type = 'non_profit', FALSE) )       AS is_operating,
  -- maturity only; exit states are the flags above
  CASE WHEN d.funding_stage IN ('m_and_a', 'ipo') THEN NULL
       ELSE nullif(trim(d.funding_stage), '') END              AS funding_stage_clean,
  nullif(trim(d.funding_stage), '')                            AS funding_stage_raw,

  -- dates -------------------------------------------------------------------
  try_cast(d.founded_on AS DATE)                               AS founded_on,
  year(try_cast(d.founded_on AS DATE))                         AS founded_year,
  CASE WHEN d.founded_on IS NULL THEN NULL
       WHEN d.founded_on LIKE '%-01-01' THEN 'year' ELSE 'day' END AS founded_date_precision,
  try_cast(d.closed_on AS DATE)                                AS closed_on,

  -- size and revenue (decoded, never imputed) --------------------------------
  d.employee_count_range,
  e.employees_min, e.employees_max, e.employees_label, e.employees_order,
  d.revenue_range,
  r.revenue_min_usd, r.revenue_max_usd, r.revenue_label, r.revenue_order,

  -- geography ---------------------------------------------------------------
  nullif(trim(d.city), '')    AS city,
  nullif(trim(d.region), '')  AS region,
  nullif(trim(d.country), '') AS country,
  (nullif(trim(d.country), '') IS NOT NULL) AS has_geo,

  -- funding fields as reported by the source (the truth is rebuilt from rounds in
  -- 35_stg_org_funding.sql; these are kept for the reconciliation check) ------
  try_cast(d.funding_total_usd AS DOUBLE)       AS reported_funding_total_usd,
  nullif(trim(d.last_funding_type), '')         AS reported_last_funding_type,
  try_cast(d.last_funding_at AS DATE)           AS reported_last_funding_at,
  try_cast(d.funding_round_count AS INTEGER)    AS reported_funding_round_count,
  try_cast(d.investor_count AS INTEGER)         AS investor_count,
  try_cast(d.crunchbase_rank AS INTEGER)        AS crunchbase_rank,
  try_cast(d.article_count AS INTEGER)          AS article_count,

  -- contact email -----------------------------------------------------------
  d.email_raw                                   AS contact_email,
  lower(split_part(d.email_raw, '@', 1)) IN (SELECT lp FROM generic_local) AS contact_email_is_generic,
  lower(split_part(d.email_raw, '@', 2)) IN (SELECT d FROM freemail)       AS contact_email_is_freemail,
  lower(split_part(d.email_raw, '@', 2))        AS email_domain,
  CASE WHEN d.email_raw IS NULL OR d.host IS NULL OR d.host = '' THEN NULL
       ELSE lower(split_part(d.email_raw, '@', 2)) = d.host
         OR lower(split_part(d.email_raw, '@', 2)) LIKE '%.' || d.host
         OR d.host LIKE '%.' || lower(split_part(d.email_raw, '@', 2)) END AS email_domain_matches_website
FROM dom d
LEFT JOIN emp e ON e.code = d.employee_count_range
LEFT JOIN rev r ON r.code = d.revenue_range
-- social/profile hosts: exact match or any subdomain of one
LEFT JOIN (SELECT DISTINCT dd.uuid, sc.d FROM dom dd JOIN social sc
           ON dd.host = sc.d OR dd.host LIKE '%.' || sc.d) s ON s.uuid = d.uuid;

-- A re-pull with a duplicate uuid must fail loudly, not silently double-count.
CREATE UNIQUE INDEX stg_organizations_uuid ON stg.organizations (uuid);
