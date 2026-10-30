-- 90_dq_checks.sql  ->  dq.checks  (one row per check, computed live)
--
-- The machine-checked data-quality log. Every number is a SELECT over raw.* or
-- stg.*, so it cannot drift from the data. Each row says what was looked at, how
-- many rows are affected, and what the pipeline did about it. Nothing here is
-- hard-coded: if the CSVs change, the counts change on the next `build`.
--
-- Convention: rows_affected = 0 on a "should never happen" check (duplicate keys,
-- orphans, reconciliation breaks) is the PASS state. A non-zero there means a re-pull
-- broke an assumption and the build output should not be trusted until looked at.
--
-- Sections: 1 keys & joins | 2 organizations | 3 funding | 4 contacts | 5 categories
CREATE TABLE dq.checks AS
WITH
o AS (SELECT * FROM stg.organizations),
raw_o AS (SELECT * FROM raw.organizations),
r AS (SELECT * FROM stg.funding_rounds),
f AS (SELECT * FROM stg.org_funding),
c AS (SELECT * FROM stg.contacts),
oc AS (SELECT * FROM stg.org_category),
checks(ord, check_name, description, rows_affected, action_taken) AS (
  -- 1. keys & joins ----------------------------------------------------------
  SELECT 101, 'org_duplicate_uuid', 'Companies sharing a uuid',
    (SELECT count(*) - count(DISTINCT uuid) FROM raw_o),
    'None needed (0 = pass). Unique index on stg.organizations(uuid) fails the build if a re-pull duplicates'
  UNION ALL SELECT 102, 'org_duplicate_domain', 'Companies sharing a normalised website domain',
    (SELECT coalesce(sum(n), 0) FROM (SELECT count(*) n FROM o WHERE domain IS NOT NULL GROUP BY domain HAVING count(*) > 1)),
    'None needed (0 = pass). Names are not unique keys in real Crunchbase, so we never dedupe on name'
  UNION ALL SELECT 103, 'orphan_rounds', 'Funding rounds whose org_uuid is not in organizations',
    (SELECT count(*) FROM raw.funding_rounds x WHERE NOT EXISTS (SELECT 1 FROM raw_o WHERE uuid = x.org_uuid)),
    'None needed (0 = pass); kept as an assertion'
  UNION ALL SELECT 104, 'orphan_contacts', 'Contacts whose org_uuid is not in organizations',
    (SELECT count(*) FROM raw.contacts x WHERE NOT EXISTS (SELECT 1 FROM raw_o WHERE uuid = x.org_uuid)),
    'None needed (0 = pass); kept as an assertion'
  UNION ALL SELECT 105, 'org_without_funding_round', 'Companies with no funding round (join coverage gap)',
    (SELECT count(*) FROM f WHERE round_count + post_ipo_round_count = 0),
    'LEFT JOIN from organizations everywhere; "no funding data" is a segment, never dropped'
  UNION ALL SELECT 106, 'org_without_contact', 'Companies with no contact row (join coverage gap)',
    (SELECT count(*) FROM o WHERE NOT EXISTS (SELECT 1 FROM c WHERE c.org_uuid = o.uuid)),
    'Kept; becomes the "needs enrichment" segment'
  UNION ALL SELECT 107, 'org_round_count_mismatch', 'Source funding_round_count differs from the actual number of round rows (NULL counted as 0)',
    (SELECT count(*) FROM o JOIN f ON f.org_uuid = o.uuid
      WHERE coalesce(o.reported_funding_round_count, 0) <> (f.round_count + f.post_ipo_round_count)),
    'Recomputed from rounds; the source column is ignored'

  -- 2. organizations ---------------------------------------------------------
  UNION ALL SELECT 201, 'org_website_not_clean', 'Raw website_url was not already a bare https://domain (scheme, www, trailing slash, path, query or upper case)',
    (SELECT count(*) FROM o WHERE website_url IS NOT NULL AND domain IS NOT NULL AND website_url <> 'https://' || domain),
    'domain column = lower-case host with scheme, www, path, query and port stripped'
  UNION ALL SELECT 202, 'org_website_tracking_params', 'Website URLs carrying utm_* tracking parameters',
    (SELECT count(*) FROM o WHERE website_url ILIKE '%utm_%'),
    'Query string stripped when building domain'
  UNION ALL SELECT 203, 'org_website_social_profile', 'Website is a social / free-hosted profile page, not the company domain',
    (SELECT count(*) FROM o WHERE website_is_social),
    'domain set to NULL, website_is_social = TRUE (so it cannot be used as an enrichment key)'
  UNION ALL SELECT 204, 'org_website_missing', 'No website at all',
    (SELECT count(*) FROM raw_o WHERE nullif(trim(website_url), '') IS NULL),
    'domain NULL; enrichment must fall back to name + linkedin_url'
  UNION ALL SELECT 205, 'org_acquired_but_active', 'funding_stage = m_and_a while operating_status still says active (acquired, not a buyer)',
    (SELECT count(*) FROM o WHERE acquired_but_active),
    'is_acquired = TRUE, so is_operating = FALSE; excluded from outreach'
  UNION ALL SELECT 206, 'org_acquired_total', 'All acquired companies (m_and_a stage)',
    (SELECT count(*) FROM o WHERE is_acquired),
    'Flagged is_acquired'
  UNION ALL SELECT 207, 'org_closed', 'operating_status = closed',
    (SELECT count(*) FROM o WHERE is_closed),
    'is_closed = TRUE, excluded from is_operating'
  UNION ALL SELECT 208, 'org_closed_without_closed_on', 'Closed companies with no closed_on date',
    (SELECT count(*) FROM o WHERE is_closed AND closed_on IS NULL),
    'Use operating_status, never closed_on, to find dead companies'
  UNION ALL SELECT 209, 'org_nonprofit', 'company_type = non_profit',
    (SELECT count(*) FROM o WHERE is_nonprofit),
    'is_nonprofit = TRUE, excluded from is_operating'
  UNION ALL SELECT 210, 'org_public', 'ipo_status = public (enterprise incumbents, post-IPO rounds)',
    (SELECT count(*) FROM o WHERE is_public),
    'is_public = TRUE, excluded from is_operating; kept so an enterprise segment is possible'
  UNION ALL SELECT 211, 'org_public_without_ipo_stage', 'ipo_status = public but funding_stage is not ipo',
    (SELECT count(*) FROM o WHERE is_public AND coalesce(funding_stage_raw, '') <> 'ipo'),
    'Trust ipo_status over funding_stage'
  UNION ALL SELECT 212, 'org_funding_stage_mixed_meaning', 'funding_stage holds an exit state (m_and_a / ipo) instead of a maturity',
    (SELECT count(*) FROM o WHERE funding_stage_raw IN ('m_and_a', 'ipo')),
    'Split: funding_stage_clean = maturity only; exit state lives in is_acquired / is_public'
  UNION ALL SELECT 213, 'org_funding_stage_without_rounds', 'funding_stage is set but the company has no funding rounds',
    (SELECT count(*) FROM o JOIN f ON f.org_uuid = o.uuid
      WHERE o.funding_stage_raw IS NOT NULL AND f.round_count + f.post_ipo_round_count = 0),
    'Kept as reported; stage is not used as proof of funding. Funding facts come from rounds only'
  UNION ALL SELECT 214, 'org_company_type_null', 'company_type is NULL',
    (SELECT count(*) FROM raw_o WHERE nullif(trim(company_type), '') IS NULL),
    'Mapped to the explicit value ''unknown'''
  UNION ALL SELECT 215, 'org_founded_year_only', 'founded_on is Jan 1 (year-only precision padded to a full date)',
    (SELECT count(*) FROM o WHERE founded_date_precision = 'year'),
    'founded_date_precision = ''year''; use founded_year only, no month-level ages'
  UNION ALL SELECT 216, 'org_founded_missing', 'founded_on is NULL',
    (SELECT count(*) FROM o WHERE founded_on IS NULL),
    'Left NULL; never imputed'
  UNION ALL SELECT 217, 'org_founded_before_1900', 'founded_on before 1900 (old incumbents, not startups)',
    (SELECT count(*) FROM o WHERE founded_year < 1900),
    'Kept; age-based scoring must not treat these as startups'
  UNION ALL SELECT 218, 'org_unparseable_dates_or_numbers', 'Non-empty founded_on / closed_on / funding_total_usd values that failed try_cast',
    (SELECT count(*) FROM raw_o WHERE (nullif(trim(founded_on), '') IS NOT NULL AND try_cast(founded_on AS DATE) IS NULL)
        OR (nullif(trim(closed_on), '') IS NOT NULL AND try_cast(closed_on AS DATE) IS NULL)
        OR (nullif(trim(funding_total_usd), '') IS NOT NULL AND try_cast(funding_total_usd AS DOUBLE) IS NULL)),
    'None needed (0 = pass)'
  UNION ALL SELECT 219, 'org_employee_range_null', 'employee_count_range is NULL',
    (SELECT count(*) FROM o WHERE employee_count_range IS NULL),
    'employees_min/max stay NULL (never imputed)'
  UNION ALL SELECT 220, 'org_employee_range_unknown_code', 'employee_count_range holds a code the lookup does not know',
    (SELECT count(*) FROM o WHERE employee_count_range IS NOT NULL AND employees_min IS NULL),
    'None needed (0 = pass); add the code to the lookup in 10_stg_organizations.sql'
  UNION ALL SELECT 221, 'org_revenue_range_null', 'revenue_range is NULL',
    (SELECT count(*) FROM o WHERE revenue_range IS NULL),
    'Left NULL; revenue must not be a hard filter. r_00000000 is a real band (< $1M), not null'
  UNION ALL SELECT 222, 'org_revenue_range_unknown_code', 'revenue_range holds a code the lookup does not know',
    (SELECT count(*) FROM o WHERE revenue_range IS NOT NULL AND revenue_min_usd IS NULL),
    'None needed (0 = pass)'
  UNION ALL SELECT 223, 'org_small_team_high_revenue', 'Headcount 1-10 but revenue band $10M or more (implausible)',
    (SELECT count(*) FROM o WHERE employees_max <= 10 AND revenue_min_usd >= 10000000),
    'Kept, low confidence; not used for scoring'
  UNION ALL SELECT 224, 'org_geo_missing', 'city, region and country all NULL (always null together)',
    (SELECT count(*) FROM o WHERE NOT has_geo),
    'has_geo = FALSE'
  UNION ALL SELECT 225, 'org_email_generic', 'contact_email is a shared inbox (info@, hello@, ...), not a person',
    (SELECT count(*) FROM o WHERE contact_email_is_generic),
    'contact_email_is_generic = TRUE; never used as a person contact'
  UNION ALL SELECT 226, 'org_email_freemail', 'contact_email is on a freemail domain (gmail, yahoo, ...)',
    (SELECT count(*) FROM o WHERE contact_email_is_freemail),
    'contact_email_is_freemail = TRUE'
  UNION ALL SELECT 227, 'org_email_domain_mismatch', 'contact_email domain differs from the website domain',
    (SELECT count(*) FROM o WHERE email_domain_matches_website = FALSE),
    'email_domain_matches_website = FALSE; the website domain is the key, never derive it from the email'
  UNION ALL SELECT 228, 'org_description_truncated', 'short_description cut at the source''s 140-char cap',
    (SELECT count(*) FROM o WHERE description_truncated),
    'description_truncated = TRUE; description is a hint, not a source'
  UNION ALL SELECT 229, 'org_description_nbsp', 'short_description contains non-breaking spaces',
    (SELECT count(*) FROM raw_o WHERE short_description LIKE '%' || chr(160) || '%'),
    'Replaced with normal spaces'
  UNION ALL SELECT 230, 'org_not_operating', 'Companies excluded from is_operating (closed, acquired, public or non-profit; overlaps allowed)',
    (SELECT count(*) FROM o WHERE NOT is_operating),
    'Flag only; scoring decides the exclusion'

  -- 3. funding ---------------------------------------------------------------
  UNION ALL SELECT 301, 'round_duplicate_key', 'Rounds sharing (org_uuid, investment_type, announced_on)',
    (SELECT count(*) - count(DISTINCT (org_uuid, investment_type, announced_on)) FROM raw.funding_rounds),
    'None needed (0 = pass). Unique index enforces it'
  UNION ALL SELECT 302, 'round_same_day_multiple', 'Org + announce-date pairs holding more than one round',
    (SELECT count(*) FROM (SELECT 1 FROM r GROUP BY org_uuid, announced_on HAVING count(*) > 1)),
    'Legitimate, not deduped. "Latest round" breaks ties by type_rank'
  UNION ALL SELECT 303, 'round_amount_zero', 'money_raised_usd = 0 (means undisclosed)',
    (SELECT count(*) FROM r WHERE money_raised_raw_usd = 0),
    'amount_usd = NULL; raw value kept for reconciliation'
  UNION ALL SELECT 304, 'round_amount_missing', 'Rounds with no disclosed amount',
    (SELECT count(*) FROM r WHERE amount_usd IS NULL),
    'NULL = unknown; excluded from sums, counted in rounds_with_amount'
  UNION ALL SELECT 305, 'round_unparseable', 'Non-empty announced_on / money_raised_usd that failed try_cast',
    (SELECT count(*) FROM raw.funding_rounds
      WHERE (nullif(trim(announced_on), '') IS NOT NULL AND try_cast(announced_on AS DATE) IS NULL)
         OR (nullif(trim(money_raised_usd), '') IS NOT NULL AND try_cast(money_raised_usd AS DOUBLE) IS NULL)),
    'None needed (0 = pass)'
  UNION ALL SELECT 306, 'round_unknown_type', 'investment_type missing from the round-group lookup',
    (SELECT count(*) FROM r WHERE type_rank = 0),
    'None needed (0 = pass); add the type to the lookup in 30_stg_funding_rounds.sql'
  UNION ALL SELECT 307, 'round_post_ipo', 'Post-IPO rounds (public-market transactions, up to $3.2B)',
    (SELECT count(*) FROM r WHERE is_post_ipo),
    'is_post_ipo = TRUE; excluded from every stg.org_funding aggregate'
  UNION ALL SELECT 308, 'round_year_only_date', 'announced_on is Jan 1 (year-only precision)',
    (SELECT count(*) FROM r WHERE announced_date_precision = 'year'),
    'announced_date_precision = ''year''; no month-level recency from these'
  UNION ALL SELECT 309, 'round_before_founding', 'Round announced more than a year before the company''s founded_on',
    (SELECT count(*) FROM r WHERE round_before_founding),
    'Flagged, not deleted'
  UNION ALL SELECT 310, 'round_after_close', 'Round announced after the company''s closed_on',
    (SELECT count(*) FROM r WHERE round_after_close),
    'Flagged, not deleted'
  UNION ALL SELECT 311, 'org_total_reconciliation_break', 'Source funding_total_usd differs from the sum of round amounts',
    (SELECT count(*) FROM f WHERE total_matches_reported = FALSE),
    'None needed (0 = pass); a non-zero means the source totals can no longer be trusted'
  UNION ALL SELECT 312, 'org_total_null_with_rounds', 'Companies with venture rounds but no disclosed amount in any',
    (SELECT count(*) FROM f WHERE round_count > 0 AND total_funding_usd IS NULL),
    'total_funding_usd = NULL, not 0'
  UNION ALL SELECT 313, 'org_last_type_disagrees', 'Source last_funding_type differs from the type of the latest round (same-day tie)',
    (SELECT count(*) FROM o JOIN f ON f.org_uuid = o.uuid
      WHERE o.reported_last_funding_type IS NOT NULL AND f.post_ipo_round_count = 0
        AND f.last_round_type IS DISTINCT FROM o.reported_last_funding_type),
    'last_round_type recomputed from rounds with a deterministic tie-break'

  -- 4. contacts --------------------------------------------------------------
  UNION ALL SELECT 401, 'contact_duplicate_org_person', 'Extra raw rows for the same (org_uuid, person_uuid): one person, several roles',
    (SELECT count(*) - (SELECT count(*) FROM c) FROM raw.contacts),
    'Collapsed to one row per org x person; latest role kept as job_title, all titles in roles'
  UNION ALL SELECT 402, 'contact_person_in_multiple_orgs', 'People appearing at more than one org (serial founders)',
    (SELECT count(*) FROM (SELECT 1 FROM c GROUP BY person_uuid HAVING count(DISTINCT org_uuid) > 1)),
    'Legitimate; person keyed on (org_uuid, person_uuid)'
  UNION ALL SELECT 403, 'contact_non_buyer_board_advisor', 'Contacts whose bucket is board / advisor / investor',
    (SELECT count(*) FROM c WHERE is_non_buyer),
    'is_non_buyer = TRUE, is_buyer_persona = FALSE'
  UNION ALL SELECT 404, 'contact_not_buyer_persona', 'Contacts outside the six buyer-persona buckets',
    (SELECT count(*) FROM c WHERE NOT is_buyer_persona),
    'is_buyer_persona = FALSE (other_exec and other included)'
  UNION ALL SELECT 405, 'contact_started_year_only', 'started_on is Jan 1 (year-only precision)',
    (SELECT count(*) FROM c WHERE started_date_precision = 'year'),
    'started_date_precision = ''year'''
  UNION ALL SELECT 406, 'contact_started_before_founding', 'Contact started more than a year before the company was founded',
    (SELECT count(*) FROM c WHERE started_before_founding),
    'Flagged, not deleted'
  UNION ALL SELECT 407, 'contact_linkedin_http', 'Person LinkedIn URLs using http://',
    (SELECT count(*) FROM raw.contacts WHERE person_linkedin_url LIKE 'http://%'),
    'Upgraded to https:// in person_linkedin_url'
  UNION ALL SELECT 408, 'contact_linkedin_legacy_pub', 'Person LinkedIn URLs in the legacy /pub/ style',
    (SELECT count(*) FROM c WHERE linkedin_is_legacy_pub),
    'linkedin_is_legacy_pub = TRUE (may not resolve)'

  -- 5. categories ------------------------------------------------------------
  UNION ALL SELECT 501, 'category_org_without_categories', 'Companies with no category tokens at all',
    (SELECT count(*) FROM o WHERE NOT EXISTS (SELECT 1 FROM oc WHERE oc.org_uuid = o.uuid)),
    'No rows in stg.org_category; sector unknown'
  UNION ALL SELECT 502, 'category_tokens_unmapped_rows', 'org x token rows whose token is not in stg.category_map',
    (SELECT count(*) FROM oc WHERE NOT is_mapped),
    'Sector defaults to ''other'' with is_mapped = FALSE'
  UNION ALL SELECT 503, 'category_tokens_unmapped_distinct', 'Distinct tokens not in stg.category_map (long tail)',
    (SELECT count(DISTINCT category_token) FROM oc WHERE NOT is_mapped),
    'Left in the long tail; review the top of this list if a sector looks thin'
  UNION ALL SELECT 504, 'category_org_llm_signal', 'Companies carrying at least one LLM-era category token (genai / agentic / chatbot / nlp)',
    (SELECT count(DISTINCT org_uuid) FROM oc WHERE llm_signal IS NOT NULL),
    'stg.org_category.llm_signal; separate from sector'
)
SELECT ord, check_name, description, rows_affected::BIGINT AS rows_affected, action_taken
FROM checks;
