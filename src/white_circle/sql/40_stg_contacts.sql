-- 40_stg_contacts.sql  ->  stg.contacts  (one row per org x person)
--
-- FIXES:
--  1. De-duplication. raw.contacts has 66 extra rows where the same person holds
--     several roles at one org (Co-Founder, then CEO). The key is (org_uuid,
--     person_uuid), NOT person_uuid alone: 4 people legitimately appear at two orgs
--     (serial founders). We keep one row per key; job_title is the most recent role
--     (latest started_on), and `roles` keeps every distinct title joined with ' | '.
--  2. title_bucket. 1,005 distinct titles (947 after case-folding) cannot be matched
--     exactly, so each role is classified by ordered regex rules (first match wins):
--        board_advisor_investor  titles that START with board/advisor/investor/...
--        security                CISO, Chief Security Officer, Head/VP/Director of Security
--        compliance_risk_legal   Chief Compliance/Risk/Legal/Privacy, General Counsel, DPO
--        cto_eng_leader          CTO, Chief Technology/Technical, VP/Head/Director of Eng
--        ceo_founder             CEO, Chief Executive, Founder/Co-founder, Owner
--        ai_ml_leader            Chief/Head/VP/Director/Lead of AI, ML, Data
--        product_leader          CPO, Head/VP/Director of Product
--        other_exec              any other C-level, President, VP, Director, Partner...
--        board_advisor_investor  (again, last) any remaining board/advisor/investor word
--        other                   engineers, sales, individual contributors...
--     Security, compliance and CTO rules run BEFORE ceo_founder so "Founder & CISO" or
--     "Co-Founder & CTO" lands on the specialist bucket, not the generic founder one. The rules favour the strong, unambiguous patterns; a rare
--     misfire (e.g. "Advisor to the CEO") is accepted over a fuzzy model.
--     A person with several roles gets the bucket with the best priority (prio).
--  3. is_buyer_persona = bucket in the six roles that could own an AI-safety
--     purchase. is_non_buyer flags board/advisor/investor people (430-515 rows in
--     the profile): they are on the cap table or in the room but do not sign.
--     other_exec (CFO, COO, sales heads) is neither: not a buyer, not excluded.
--  4. Dates: started_on typed; started_date_precision is 'year' for Jan-1 padding,
--     'month' for first-of-month, else 'day'. started_before_founding flags starts
--     more than a year before the org's founded_on (78 rows): flagged, not deleted.
--  5. LinkedIn URLs: http:// upgraded to https://; legacy /pub/ style flagged.
--  6. org_name / person_country kept as given; org_name is dropped (join for it).
CREATE TABLE stg.contacts AS
WITH roles AS (
  SELECT
    c.org_uuid, c.person_uuid, c.person_name,
    trim(c.job_title) AS job_title,
    try_cast(c.started_on AS DATE) AS started_on,
    c.started_on AS started_raw,
    nullif(trim(c.person_linkedin_url), '') AS li,
    nullif(trim(c.person_country), '') AS person_country,
    lower(trim(c.job_title)) AS t
  FROM raw.contacts c),
classified AS (
  SELECT r.*,
    CASE
      WHEN t ~ '^(board|advis|investor|observer|mentor|angel|venture|limited partner)' THEN 'board_advisor_investor'
      WHEN t ~ '\bciso\b|chief (information )?security|(head|vp|director|vice president)[^,]*security' THEN 'security'
      WHEN t ~ 'chief (compliance|risk|legal|privacy)|general counsel|\bdpo\b|data protection officer|(head|vp|director|vice president)[^,]*(compliance|risk|legal|privacy)' THEN 'compliance_risk_legal'
      WHEN t ~ '\bcto\b|chief (technology|technical)|chief architect|(vp|vice president|head|director|lead)[^,]*(engineering|technology|technical)|engineering (manager|lead)' THEN 'cto_eng_leader'
      WHEN t ~ '\bceo\b|chief executive|founder|\bowner\b' THEN 'ceo_founder'
      WHEN t ~ '(chief|head|vp|vice president|director|lead)[^,]*\b(ai|ml|machine learning|data|artificial intelligence)\b|\bcaio\b|chief scientist' THEN 'ai_ml_leader'
      WHEN t ~ 'chief product|\bcpo\b|(vp|vice president|head|director)[^,]*product' THEN 'product_leader'
      WHEN t ~ '\bc[a-z]o\b|chief|president|managing director|\bvp\b|vice president|head of|director|partner|general manager|chairman' THEN 'other_exec'
      WHEN t ~ 'board|advis|investor|observer|mentor' THEN 'board_advisor_investor'
      ELSE 'other' END AS role_bucket
  FROM roles r),
ranked AS (
  SELECT k.*,
    -- lower number = more relevant to the AI-safety purchase; used to pick one bucket per person
    CASE role_bucket WHEN 'security' THEN 1 WHEN 'compliance_risk_legal' THEN 2
      WHEN 'ai_ml_leader' THEN 3 WHEN 'cto_eng_leader' THEN 4 WHEN 'ceo_founder' THEN 5
      WHEN 'product_leader' THEN 6 WHEN 'other_exec' THEN 7 WHEN 'other' THEN 8
      ELSE 9 END AS prio,
    row_number() OVER (PARTITION BY org_uuid, person_uuid
                       ORDER BY started_on DESC NULLS LAST, job_title) AS rn
  FROM classified k),
person AS (
  SELECT org_uuid, person_uuid,
    any_value(person_name)  FILTER (WHERE rn = 1) AS person_name,
    any_value(job_title)    FILTER (WHERE rn = 1) AS job_title,
    string_agg(DISTINCT job_title, ' | ' ORDER BY job_title) AS roles,
    count(*)                                      AS role_count,
    any_value(started_on)   FILTER (WHERE rn = 1) AS started_on,
    any_value(started_raw)  FILTER (WHERE rn = 1) AS started_raw,
    any_value(li)           FILTER (WHERE rn = 1) AS li,
    any_value(person_country) FILTER (WHERE rn = 1) AS person_country,
    arg_min(role_bucket, prio)                    AS title_bucket
  FROM ranked GROUP BY 1, 2)
SELECT
  p.org_uuid, p.person_uuid, p.person_name, p.job_title, p.roles, p.role_count,
  p.title_bucket,
  p.title_bucket IN ('ceo_founder','cto_eng_leader','ai_ml_leader','product_leader',
                     'security','compliance_risk_legal')   AS is_buyer_persona,
  (p.title_bucket = 'board_advisor_investor')              AS is_non_buyer,
  p.started_on,
  CASE WHEN p.started_on IS NULL THEN NULL
       WHEN p.started_raw LIKE '%-01-01' THEN 'year'
       WHEN p.started_raw LIKE '%-01' THEN 'month' ELSE 'day' END AS started_date_precision,
  coalesce(p.started_on < o.founded_on - INTERVAL 1 YEAR, FALSE)  AS started_before_founding,
  regexp_replace(p.li, '^http://', 'https://')             AS person_linkedin_url,
  coalesce(p.li LIKE '%/pub/%', FALSE)                     AS linkedin_is_legacy_pub,
  p.person_country
FROM person p
LEFT JOIN stg.organizations o ON o.uuid = p.org_uuid;

CREATE UNIQUE INDEX stg_contacts_key ON stg.contacts (org_uuid, person_uuid);
