-- 55_mart_org_features.sql  ->  mart.org_features  (one row per org, all 3,000)
--
-- Turns the staging tables into the handful of decision-ready attributes the score
-- and the segments use. Nothing is scored here; this file only answers "what do we
-- know about this company". Everything starts FROM stg.organizations with LEFT JOINs:
-- 73% of orgs have no funding round and 65% no contact, and an inner join would
-- silently delete them from the universe.
--
-- llm_level (strong / nlp_only / ml_only / none): how close the product is to LLMs.
--   strong   a category token in stg.llm_signal_token (genai, agentic, chatbot,
--            virtual assistant, foundation model...) OR the description matches the
--            regex below. NOTE: the 'nlp' signal in that table is NOT strong here;
--            plain "Natural Language Processing" is the nlp_only tier (it predates
--            LLMs). Regex uses word boundaries so "gpt" does not hit "egypt" and
--            "agent" alone (real-estate agent, insurance agent) does not count: we
--            require "ai agent" / "agentic".
--   nlp_only NLP / speech / conversational / voice-AI tag or wording, nothing stronger.
--   ml_only  generic AI / ML tag (any 'ai_platform' sector token) or "AI" in text.
-- vertical: the highest-risk sector any category token maps to, in order
--   fintech_banking > insurance > health > legal_compliance > public_sector >
--   education > hr_recruiting > crypto_web3 > finance_ops > security > ecommerce >
--   gaming > creative_tools > consumer_wellness > other (roughly by points, see 50_).
--   A company in several sectors is judged by its riskiest one, because one regulated
--   customer base is enough to need the guardrail. hr_recruiting = the
--   HR / recruiting / staffing tokens (which the shared taxonomy files
--   under business_services).
--   v2: is_regulated is TRUE only for the first four (rank <= 4). Crypto, government,
--   accounting and fitness used to be folded into those and are now separate,
--   non-regulated verticals (see 20_ for why).
-- is_services_firm (v2): agencies, consultancies, dev shops and outsourcers. They
--   build LLM apps FOR clients but do not run them at scale themselves, so they are a
--   weak buyer however AI-heavy their description sounds. 70_ caps them at Tier 3 and
--   keeps them out of the top 50. Matched on the short description (and, for the
--   unambiguous words only, the category tags); the regex was tuned by reading 15
--   flagged and 15 unflagged top candidates, see the comment on the column below.
-- is_competitor: guardrail / AI-safety / red-team / LLM-security vendors. They sell
--   what we sell, so they are partners or competitors, never AE targets.
-- segment_universe: why an org is in or out of the AE list. First match wins:
--   out_closed_acquired > out_nonprofit > enterprise (public) > competitor > core.
--   'enterprise' = publicly listed: a different sales motion, kept visible not deleted.
-- v3.1: "verified" means an accepted review: confidence high or medium AND a live (or
--   search-recovered) site. Unclear / low reviews are NOT verified: they change no label.
--   They can still flag a services firm (see is_services_firm in the last SELECT).
-- v3 VERIFIED OVERRIDES. For the orgs whose own website was checked (stg.company_review,
--   52_), a HIGH or MEDIUM confidence label beats the tag-based guess, because a tag says
--   what a company claims and the site says what it ships:
--     llm_level     ships_customer_facing_llm = 'yes' -> 'strong'. = 'no' -> downgraded:
--                   'ml_only' if the reviewer's own text still mentions AI (or gave no text,
--                   so we are unsure), else 'none'. 'unclear' changes nothing.
--     vertical / is_regulated   taken from the reviewer's true_vertical / is_regulated
--                   when true_vertical is a sector we have weights for.
--   The tag-based answers are kept as tags_llm_level / tags_vertical / tags_is_regulated
--   and llm_level_source / vertical_source say which one is in force ('verified' or
--   'tags'), so nothing is overwritten silently. Low-confidence labels are ignored.
--   Labels from a dead or hijacked site (site_status, see 52_) are ignored too; 70_ caps
--   those orgs at Tier 3 and out of the top 50.
--   is_agentic, verified_llm_use and evidence_quote ride along for the score (agentic
--   bonus in 60_) and for the AE-facing CSV.
-- Funding (v2): recency, last round type/date/amount come from EQUITY rounds only
--   (round_group = 'equity_venture' in 30_): pre_seed, angel, convertible_note,
--   equity_crowdfunding, seed, series_unknown, series_a..series_h. NOT counted: grant,
--   non_equity_assistance (non-dilutive), debt_financing, post_ipo_* (public market),
--   private_equity (buyout/growth, not a venture raise), corporate_round, secondary_market
--   (existing shares changing hands), initial_coin_offering, product_crowdfunding,
--   undisclosed (no type, no amount). A company whose only 2025 event was a loan is
--   therefore NOT "recently funded". Same-day ties take the later stage. Stage is the highest equity
--   round ever raised (grants, debt and PE do not make a company "Series B"); where
--   there are no rounds we fall back to the source's funding_stage (63 orgs).
-- region: eu_uk = EU27 + EEA (Iceland, Liechtenstein, Norway) + Switzerland + UK, the
--   places the EU AI Act or UK rules reach; us_ca = US and Canada.
-- best contact: persona buckets from stg.contacts. technical_or_risk_buyer = CTO/eng,
--   AI/ML, security or compliance person; founder_only = only CEO/founder on file.
--   Board members, advisors and investors never count.
-- data_confidence: share of 6 fields known (funding recency, stage, headcount, country,
--   any contact, description). Separate from the score; used only as a tie-break and
--   to tell an AE how much of the picture is guesswork.
CREATE TABLE mart.org_features AS
WITH
p AS (SELECT as_of FROM mart.params),
txt AS (
  SELECT o.uuid AS org_uuid,
         lower(coalesce(o.short_description, ''))                         AS d,
         lower(coalesce(o.short_description, '') || ' ' || coalesce(o.categories, '')) AS dc
  FROM stg.organizations o),
cat AS (
  SELECT org_uuid,
    bool_or(llm_signal IS NOT NULL AND llm_signal <> 'nlp')               AS cat_strong,
    bool_or(llm_signal = 'nlp' OR category_token IN ('speech recognition', 'voice ai', 'conversational ai')) AS cat_nlp,
    bool_or(sector = 'ai_platform')                                       AS cat_ml,
    min(CASE
          WHEN sector = 'fintech_banking'  THEN 1
          WHEN sector = 'insurance'        THEN 2
          WHEN sector = 'health'           THEN 3
          WHEN sector = 'legal_compliance' THEN 4
          WHEN sector = 'public_sector'    THEN 5
          WHEN sector = 'education'        THEN 6
          WHEN category_token IN ('human resources','recruiting','staffing agency') THEN 7
          WHEN sector = 'crypto_web3'      THEN 8
          WHEN sector = 'finance_ops'      THEN 9
          WHEN sector = 'security'         THEN 10
          WHEN sector = 'ecommerce'        THEN 11
          WHEN sector = 'gaming'           THEN 12
          WHEN sector = 'creative_tools'   THEN 13
          WHEN sector = 'consumer_wellness' THEN 14
        END)                                                              AS vert_rank
  FROM stg.org_category GROUP BY 1),
eq AS (
  SELECT org_uuid, announced_on AS last_equity_date, investment_type AS last_equity_type,
         amount_usd AS last_equity_amount_usd
  FROM stg.funding_rounds
  WHERE round_group = 'equity_venture' AND announced_on IS NOT NULL
  QUALIFY row_number() OVER (PARTITION BY org_uuid ORDER BY announced_on DESC, type_rank DESC) = 1),
stage_rounds AS (
  SELECT org_uuid,
    max(CASE investment_type
          WHEN 'angel' THEN 1 WHEN 'pre_seed' THEN 1 WHEN 'convertible_note' THEN 1
          WHEN 'equity_crowdfunding' THEN 1
          WHEN 'seed' THEN 2
          WHEN 'series_a' THEN 3 WHEN 'series_b' THEN 3 WHEN 'series_c' THEN 3
          WHEN 'series_d' THEN 4 WHEN 'series_e' THEN 4 WHEN 'series_f' THEN 4
          WHEN 'series_g' THEN 4 WHEN 'series_h' THEN 4 END) AS stage_ord
  FROM stg.funding_rounds WHERE round_group = 'equity_venture' AND NOT is_post_ipo
  GROUP BY 1),
ct AS (
  SELECT org_uuid,
    count(*) AS contact_count,
    bool_or(title_bucket IN ('cto_eng_leader','ai_ml_leader','security','compliance_risk_legal')) AS has_tech_risk,
    bool_or(title_bucket = 'ceo_founder') AS has_founder
  FROM stg.contacts GROUP BY 1),
best_ct AS (
  SELECT org_uuid, person_name AS best_contact_name, job_title AS best_contact_title,
         title_bucket AS best_contact_bucket
  FROM stg.contacts
  WHERE title_bucket IN ('security','compliance_risk_legal','ai_ml_leader','cto_eng_leader','ceo_founder')
  QUALIFY row_number() OVER (PARTITION BY org_uuid ORDER BY
      CASE title_bucket WHEN 'security' THEN 1 WHEN 'compliance_risk_legal' THEN 2
        WHEN 'ai_ml_leader' THEN 3 WHEN 'cto_eng_leader' THEN 4 ELSE 5 END,
      started_on DESC NULLS LAST, person_name) = 1),
base AS (
  SELECT o.uuid AS org_uuid, o.organization_name, o.domain, o.country, o.short_description,
    o.operating_status, o.is_closed, o.is_acquired, o.is_nonprofit, o.is_public,
    o.employees_label, o.employees_min,
    f.round_count,
    eq.last_equity_date                                                    AS last_round_date,
    eq.last_equity_type                                                    AS last_round_type,
    eq.last_equity_amount_usd                                              AS last_round_amount_usd,
    date_diff('month', eq.last_equity_date, p.as_of)                       AS months_since_last_round,
    CASE
      WHEN c.cat_strong OR regexp_matches(t.d,
           '\bllms?\b|large language|generative ai|\bgenai\b|gen ai|ai agent|agentic|chatbot|copilot|\bgpt\b|\bgpt-?[0-9]|conversational ai')
        THEN 'strong'
      WHEN c.cat_nlp OR regexp_matches(t.d, '\bnlp\b|natural language|speech|voice ai|voice assistant|conversational')
        THEN 'nlp_only'
      WHEN c.cat_ml OR regexp_matches(t.d, '\bai\b|artificial intelligence|machine learning|\bml\b|deep learning')
        THEN 'ml_only'
      ELSE 'none' END                                                      AS tags_llm_level,
    CASE c.vert_rank WHEN 1 THEN 'fintech_banking' WHEN 2 THEN 'insurance' WHEN 3 THEN 'health'
      WHEN 4 THEN 'legal_compliance' WHEN 5 THEN 'public_sector' WHEN 6 THEN 'education'
      WHEN 7 THEN 'hr_recruiting' WHEN 8 THEN 'crypto_web3' WHEN 9 THEN 'finance_ops'
      WHEN 10 THEN 'security' WHEN 11 THEN 'ecommerce' WHEN 12 THEN 'gaming'
      WHEN 13 THEN 'creative_tools' WHEN 14 THEN 'consumer_wellness'
      ELSE 'other' END                                                     AS tags_vertical,
    coalesce(c.vert_rank, 99) <= 4                                         AS tags_is_regulated,
-- is_services_firm (v2). Two tests, either is enough. (1) The description says so:
    -- agency, consultancy / consulting, dev shop, software development company or
    -- studio, outsourcing, "we build", IT services, staff augmentation, bespoke or custom
    -- web / mobile / software development, law firm, translation services. (2) A category
    -- tag that is unambiguous on its own (outsourcing, creative agency, management
    -- consulting; 'staffing agency' was dropped because HR-tech PRODUCTS carry it). The generic tags 'consulting', 'professional services'
    -- and 'web development' are NOT used alone: they also sit on product companies
    -- (Spellbook, Drapp). Tuned by reading 15 flagged and 15 unflagged top-scoring orgs:
    -- early drafts missed dev shops that say "software solutions in AI, custom web &
    -- mobile development" or "engineering as a service" (added) and caught nothing
    -- wrong; 'custom software' alone was dropped because it flagged a payments vendor.
    (regexp_matches(t.d,
      '\bagenc(y|ies)\b|consultanc|consulting|\bconsultants?\b|\bdev(elopment)? shop|software development (company|firm|services)|ai development company|development (studio|agency|company|services|partner|firm)|outsourc|\bwe build\b|\bwe design\b|\bit services\b|digital studio|product studio|venture studio|design studio|app development|software house|systems integrator|staff augmentation|staffing (agency|firm|services|company)|remote staffing|nearshore|offshore|engineering as a service|bespoke (mvp|software|apps?)|custom (web|mobile|software|app)[a-z ,&]{0,20}(development|solutions)|(web|mobile)( app)?s? ?(&|and) ?(mobile|web|software)? ?development|software solutions in|mobile apps, games|\blaw firm\b|translation services|professional services (firm|company)')
     OR regexp_matches(t.dc, 'outsourcing|creative agency|management consulting'))
                                                                           AS is_services_firm,
    regexp_matches(t.dc,
      'guardrail|ai safety|red team|red-team|llm security|prompt injection|ai governance|model monitoring|hallucination detection') AS is_competitor,
    CASE
      WHEN sr.stage_ord = 1 THEN 'pre_seed_angel'
      WHEN sr.stage_ord = 2 THEN 'seed'
      WHEN sr.stage_ord = 3 THEN 'series_a_c'
      WHEN sr.stage_ord = 4 THEN 'late_d_plus'
      WHEN o.funding_stage_clean = 'seed' THEN 'seed'
      WHEN o.funding_stage_clean = 'early_stage_venture' THEN 'series_a_c'
      WHEN o.funding_stage_clean IN ('late_stage_venture','private_equity') THEN 'late_d_plus'
      ELSE 'unknown' END                                                   AS stage_bucket,
    CASE
      WHEN o.country IS NULL THEN 'unknown'
      WHEN o.country IN ('Austria','Belgium','Bulgaria','Croatia','Cyprus','Czech Republic','Denmark',
           'Estonia','Finland','France','Germany','Greece','Hungary','Ireland','Italy','Latvia',
           'Lithuania','Luxembourg','Malta','The Netherlands','Poland','Portugal','Romania',
           'Slovakia (Slovak Republic)','Slovenia','Spain','Sweden',
           'Iceland','Liechtenstein','Norway','Switzerland','United Kingdom') THEN 'eu_uk'
      WHEN o.country IN ('United States','Canada') THEN 'us_ca'
      ELSE 'other' END                                                     AS region_bucket,
    CASE WHEN o.employees_min IS NULL THEN 'unknown'
         WHEN o.employees_min >= 1001 THEN '1000+'
         WHEN o.employees_min >= 501  THEN '501-1000'
         WHEN o.employees_min >= 51   THEN '51-500'
         WHEN o.employees_min >= 11   THEN '11-50'
         ELSE '1-10' END                                                   AS size_bucket,
    CASE WHEN coalesce(ct.has_tech_risk, FALSE) THEN 'technical_or_risk_buyer'
         WHEN coalesce(ct.has_founder, FALSE)   THEN 'founder_only'
         ELSE 'none' END                                                   AS persona_bucket,
    coalesce(ct.contact_count, 0)                                          AS contact_count,
    b.best_contact_name, b.best_contact_title, b.best_contact_bucket
  FROM stg.organizations o
  CROSS JOIN p
  LEFT JOIN txt t         ON t.org_uuid  = o.uuid
  LEFT JOIN cat c         ON c.org_uuid  = o.uuid
  LEFT JOIN stg.org_funding f ON f.org_uuid = o.uuid
  LEFT JOIN eq            ON eq.org_uuid = o.uuid
  LEFT JOIN stage_rounds sr ON sr.org_uuid = o.uuid
  LEFT JOIN ct            ON ct.org_uuid = o.uuid
  LEFT JOIN best_ct b     ON b.org_uuid  = o.uuid)
SELECT b.* EXCLUDE (is_services_firm, is_competitor),
  -- v3.1: a reviewer's note can reveal a competitor the tags missed: the company's OWN product
  -- is a guardrail / AI-gateway / AI-governance / agent control plane / AI-safety tool
  -- (Guild.ai, TrueFoundry, GENUM). They sell what we sell, so they move to the Competitor
  -- segment (partner or competitor, never an AE target). Read from all reviews, any
  -- confidence. 'AI cost governance' (FinOps) and plain 'governance' do NOT match.
  (b.is_competitor OR regexp_matches(lower(coalesce(rs.notes, '') || ' ' || coalesce(rs.llm_use, '')),
     'competitor|control plane|\bai governance\b|guardrail|ai safety|llm security|red.?team|prompt injection|ai gateway'))
                                                                           AS is_competitor,
  -- v3.1: a reviewer's note can reveal a services firm that the description regex missed
  -- (MediaGuru, Aurionpro: "IT services", "integrator", "bespoke"). ALL reviews count here,
  -- even low-confidence ones: spotting a consultancy needs no verified label.
  (b.is_services_firm OR regexp_matches(lower(coalesce(rs.notes, '') || ' ' || coalesce(rs.llm_use, '')),
     'consultanc|consulting|\bagency\b|\bit services\b|software services|dev(elopment)? shop|outsourc|integrator|builds? (\w+ )?for (its )?clients|for clients'))
                                                                           AS is_services_firm,
  -- verified overrides (see header). rv = accepted reviews only.
  coalesce(rv.org_uuid IS NOT NULL, FALSE)                                 AS has_verified_review,
  CASE WHEN rv.ships_customer_facing_llm = 'yes' THEN 'strong'
       WHEN rv.ships_customer_facing_llm = 'no' THEN
         CASE WHEN regexp_matches(regexp_replace(lower(coalesce(rv.llm_use, '') || ' ' || coalesce(rv.notes, '') || ' ' || coalesce(rv.evidence_quote, '')),
                    '\b(no|not|without|zero|none)\b[^.;]{0,25}(\bai\b|\bllm|machine learning|artificial intelligence)', '', 'g'),
                    '\bai\b|artificial intelligence|machine learning|\bml\b|\bllm|gpt|chatbot|copilot|generative')
                   OR (coalesce(rv.llm_use, '') = '' AND b.tags_llm_level <> 'none')
              THEN 'ml_only' ELSE 'none' END
       ELSE b.tags_llm_level END                                           AS llm_level,
  CASE WHEN rv.ships_customer_facing_llm IN ('yes', 'no') THEN 'verified' ELSE 'tags' END AS llm_level_source,
  CASE WHEN rv.true_vertical IN (SELECT vertical FROM mart.vertical_gate)
       THEN rv.true_vertical ELSE b.tags_vertical END                      AS vertical,
  CASE WHEN rv.true_vertical IN (SELECT vertical FROM mart.vertical_gate)
       THEN 'verified' ELSE 'tags' END                                     AS vertical_source,
  CASE WHEN rv.true_vertical IN (SELECT vertical FROM mart.vertical_gate)
       THEN coalesce(rv.is_regulated, b.tags_is_regulated) ELSE b.tags_is_regulated END AS is_regulated,
  rv.ships_customer_facing_llm                                             AS verified_ships_llm,
  rv.llm_use                                                               AS verified_llm_use,
  coalesce(rv.is_agentic, FALSE)                                           AS is_agentic,
  rv.evidence_quote                                                        AS evidence_quote,
  rv.confidence                                                            AS review_confidence,
  rs.site_status                                                           AS site_status,   -- NULL = never reviewed
  CASE WHEN is_closed OR is_acquired THEN 'out_closed_acquired'
       WHEN is_nonprofit THEN 'out_nonprofit'
       WHEN is_public    THEN 'enterprise'
       WHEN b.is_competitor OR regexp_matches(lower(coalesce(rs.notes, '') || ' ' || coalesce(rs.llm_use, '')),
            'competitor|control plane|\bai governance\b|guardrail|ai safety|llm security|red.?team|prompt injection|ai gateway')
                                                                           THEN 'competitor'
       ELSE 'core' END                                                     AS segment_universe,
  ( (last_round_date IS NOT NULL)::INT + (stage_bucket <> 'unknown')::INT
  + (size_bucket <> 'unknown')::INT + (region_bucket <> 'unknown')::INT
  + (contact_count > 0)::INT + (short_description IS NOT NULL)::INT ) / 6.0 AS data_confidence
FROM base b
LEFT JOIN (SELECT * FROM stg.company_review
           WHERE confidence IN ('high', 'medium') AND site_status IN ('live', 'recovered_via_search')) rv
       ON rv.org_uuid = b.org_uuid
LEFT JOIN stg.company_review rs ON rs.org_uuid = b.org_uuid;

CREATE UNIQUE INDEX mart_org_features_org ON mart.org_features (org_uuid);
