-- 52_stg_company_review.sql  ->  stg.company_review  (one row per website-checked org)
--
-- WHY THIS EXISTS. The Crunchbase tags say what a company SAYS it is; they cannot say
-- whether it actually ships a chatbot or agent to its customers. For the 120 orgs that
-- matter most (the v2 top candidates) an LLM-assisted reviewer opened each company's own
-- website and wrote down what it found, with a quoted sentence and the page it came from.
-- Those labels live in src/white_circle/seeds/company_review.csv (committed, so the
-- evidence travels with the code; `whitecircle merge-reviews` builds it from
-- data/verify/review_part*.csv). This file turns that CSV into a typed staging table.
-- 55_ then lets a confident label override the tag-based guess, and says so in a column.
--
-- Cleaning, in plain words: text is trimmed and the yes/no style fields are lower-cased
-- so 'Yes ' and 'yes' are the same answer; is_agentic / is_regulated become real booleans;
-- blank strings become NULL. If an org appears twice, the most confident row wins
-- (high > medium > low), then the later row.
--
-- site_status (v3 dead-site rule). A top-ranked startup whose homepage is dead usually
-- shut down, was acquired quietly, or pivoted, and a Crunchbase snapshot from June 2026
-- cannot show that. So the reviewer's page check also decides how far we trust the row:
--   live                  page_ok is true: the label rests on the company's own site.
--   recovered_via_search  page_ok is false but search recovered a quote at medium or high
--                         confidence: still eligible, labels apply as normal.
--   dead_or_unverified    page_ok is false and confidence is low/blank or there is no
--                         evidence quote: nothing to stand on.
--   hijacked              the notes say the domain was hijacked / is spam: whatever the
--                         page showed is not the company. Checked first.
-- 55_ ignores labels from the last two; 70_ caps those orgs at Tier 3 and keeps them out
-- of the top 50 until someone confirms the company still exists. Orgs never reviewed
-- have no status (NULL) and are not penalised: missing data is neutral.
--
-- The file may legitimately be missing (a fresh clone, or before the review is run).
-- Then this table is created empty and every org simply falls back to its tags: the
-- first statement below always runs, the second only when the seed file exists. The
-- marker line is read by `whitecircle build`; the path placeholder is filled in there.
CREATE TABLE stg.company_review (
  org_uuid VARCHAR, organization_name VARCHAR, url_checked VARCHAR, page_ok BOOLEAN,
  ships_customer_facing_llm VARCHAR, llm_use VARCHAR, is_agentic BOOLEAN,
  true_vertical VARCHAR, is_regulated BOOLEAN, customer_type VARCHAR,
  evidence_quote VARCHAR, source_url VARCHAR, confidence VARCHAR, notes VARCHAR, site_status VARCHAR);

-- @requires-seed
INSERT INTO stg.company_review
WITH r AS (
  SELECT * FROM read_csv('{{review_seed}}', all_varchar=true, header=true, quote='"', escape='"')),
c AS (
  SELECT
    nullif(trim(org_uuid), '')                                           AS org_uuid,
    nullif(trim(organization_name), '')                                  AS organization_name,
    nullif(trim(url_checked), '')                                        AS url_checked,
    lower(trim(page_ok)) IN ('true','yes','1','y')                       AS page_ok,
    nullif(lower(trim(ships_customer_facing_llm)), '')                   AS ships_customer_facing_llm,
    nullif(trim(llm_use), '')                                            AS llm_use,
    lower(trim(is_agentic)) IN ('true','yes','1','y')                    AS is_agentic,
    nullif(lower(trim(true_vertical)), '')                               AS true_vertical,
    lower(trim(is_regulated)) IN ('true','yes','1','y')                  AS is_regulated,
    nullif(trim(customer_type), '')                                      AS customer_type,
    nullif(trim(evidence_quote), '')                                     AS evidence_quote,
    nullif(trim(source_url), '')                                         AS source_url,
    nullif(lower(trim(confidence)), '')                                  AS confidence,
    nullif(trim(notes), '')                                              AS notes,
    row_number() OVER () AS file_order
  FROM r)
SELECT org_uuid, organization_name, url_checked, page_ok, ships_customer_facing_llm, llm_use, is_agentic,
       true_vertical, is_regulated, customer_type, evidence_quote, source_url, confidence, notes,
       CASE WHEN regexp_matches(lower(coalesce(notes, '')), 'hijack|spam|gambl') THEN 'hijacked'
            WHEN page_ok THEN 'live'
            WHEN confidence IS NULL OR confidence NOT IN ('medium', 'high') OR evidence_quote IS NULL THEN 'dead_or_unverified'
            ELSE 'recovered_via_search' END AS site_status
FROM c
WHERE org_uuid IS NOT NULL
QUALIFY row_number() OVER (PARTITION BY org_uuid ORDER BY
  CASE confidence WHEN 'high' THEN 3 WHEN 'medium' THEN 2 ELSE 1 END DESC, file_order DESC) = 1;
