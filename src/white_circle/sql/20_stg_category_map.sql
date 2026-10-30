-- 20_stg_category_map.sql  ->  stg.category_map, stg.llm_signal_token
--
-- WHY: the 601 raw category tokens are clean typographically (no case/spelling
-- variants) but messy SEMANTICALLY: "Cyber Security", "Security" and the group
-- "Privacy and Security" all mean one thing; "FinTech", "Financial Services" and
-- "Payments" overlap. String-matching the raw column is a trap (LIKE '%AI%' also
-- hits "Fair" and "Retail"), so we map each token to ONE canonical sector through
-- this hand-built table. Reviewers: this table IS the taxonomy; edit it here.
--
-- Covers the ~220 most frequent tokens (everything on >= 12 companies, counting
-- both `categories` and `category_groups`). Anything not listed falls to 'other'
-- in 25_stg_org_category.sql, and dq.checks reports how much of the data that is.
--
-- sector  : the canonical industry bucket.
-- kind    : 'vertical' = tells you who the company's customers are (fintech, health...)
--           'horizontal' = describes the product or service (ai_platform,
--           devtools_infra, data_analytics, martech_sales, business_services,
--           generic_tech). generic_tech holds tags such as Software / Mobile / SaaS
--           that carry no industry information at all.
-- ai_platform is horizontal on purpose: 67% of the extract is AI-tagged, so "AI"
-- cannot separate good from bad fit; the vertical decides the use case.
--
-- v2 CHANGE (score_version 'v2'): "regulated" is now narrow. In v1 five different
-- things were filed under the regulated sectors, so the bonus and the 25 points went
-- to companies that are not our neobank-style buyer. The regulated sectors (the only
-- ones with is_regulated = TRUE, see 55_) are now exactly:
--   fintech_banking   banking, payments, lending, neobank, financial services, wealth, credit
--   insurance         insurance, insurtech
--   health            health care, medical, clinical, pharma, digital health
--   legal_compliance  legal, legaltech, compliance, regtech
-- and these groups MOVED OUT into their own non-regulated sectors:
--   crypto_web3       crypto / blockchain / web3 / defi / nft: real MiCA exposure, but not
--                     the neobank profile of our reference customers (10 pts, no bonus).
--   public_sector     government / public safety / govtech (15 pts, no bonus).
--   consumer_wellness fitness / wellness / sports: consumer apps, no health regulator
--                     in practice (0 pts). Sports used to sit in media.
--   finance_ops       accounting / billing / bookkeeping: a back-office tool, not a
--                     regulated financial institution (8 pts, no bonus).
-- v2b: docs/context/whitecircle-research.md says White Circle's site calls out Government,
-- Healthcare and Education and has landing pages for HR, e-commerce, gaming and
-- creative tools. So education, e-commerce ('ecommerce'), gaming and creative_tools are
-- sectors of their own too (weights in 50_). None of them is "regulated" here.
CREATE TABLE stg.category_map AS
SELECT token, sector,
       CASE WHEN sector IN ('fintech_banking','insurance','health','legal_compliance',
                            'crypto_web3','public_sector','consumer_wellness','finance_ops',
                            'ecommerce','gaming','creative_tools',
                            'security','commerce','media','education','physical_economy')
            THEN 'vertical' ELSE 'horizontal' END AS kind
FROM (VALUES
  -- fintech_banking -----------------------------------------------------------
  ('financial services','fintech_banking'), ('fintech','fintech_banking'),
  ('payments','fintech_banking'), ('lending and investments','fintech_banking'),
  ('finance','fintech_banking'), ('banking','fintech_banking'),
  ('mobile payments','fintech_banking'), ('trading platform','fintech_banking'),
  ('asset management','fintech_banking'), ('fraud detection','fintech_banking'),
  ('neobank','fintech_banking'), ('wealth management','fintech_banking'),
  ('credit','fintech_banking'), ('credit cards','fintech_banking'),
  -- crypto_web3 (v2: moved out of fintech_banking) ----------------------------
  ('blockchain and cryptocurrency','crypto_web3'), ('blockchain','crypto_web3'),
  ('cryptocurrency','crypto_web3'), ('web3','crypto_web3'), ('defi','crypto_web3'),
  ('nft','crypto_web3'), ('decentralized finance','crypto_web3'),
  -- finance_ops (v2: moved out of fintech_banking) -----------------------------
  ('accounting','finance_ops'), ('billing','finance_ops'), ('bookkeeping','finance_ops'),
  -- insurance -----------------------------------------------------------------
  ('insurance','insurance'), ('insurtech','insurance'),
  -- health --------------------------------------------------------------------
  ('health care','health'), ('electronic health record (ehr)','health'), ('medical','health'),
  ('medical device','health'), ('health diagnostics','health'), ('biotechnology','health'),
  ('personal health','health'), ('telehealth','health'),
  ('hospital','health'), ('clinical trials','health'), ('pharmaceutical','health'),
  ('life science','health'), ('digital health','health'), ('clinical','health'),
  -- consumer_wellness (v2: fitness / wellness / sports moved out of health / media) --
  ('fitness','consumer_wellness'), ('wellness','consumer_wellness'),
  ('sports','consumer_wellness'),
  -- legal_compliance -----------------------------------------------------------
  ('legal tech','legal_compliance'), ('legal','legal_compliance'),
  ('compliance','legal_compliance'), ('risk management','legal_compliance'),
  ('regtech','legal_compliance'), ('legaltech','legal_compliance'),
  -- public_sector (v2: government moved out of legal_compliance) ----------------
  ('government and military','public_sector'), ('government','public_sector'),
  ('public safety','public_sector'), ('govtech','public_sector'),
  -- security ------------------------------------------------------------------
  ('privacy and security','security'), ('cyber security','security'), ('security','security'),
  ('network security','security'), ('cloud security','security'),
  ('identity management','security'),
  -- devtools_infra ------------------------------------------------------------
  ('devops','devtools_infra'), ('developer tools','devtools_infra'),
  ('developer platform','devtools_infra'), ('developer apis','devtools_infra'),
  ('cloud computing','devtools_infra'), ('cloud infrastructure','devtools_infra'),
  ('it infrastructure','devtools_infra'), ('software engineering','devtools_infra'),
  ('paas','devtools_infra'), ('cloud management','devtools_infra'),
  ('application performance management','devtools_infra'), ('database','devtools_infra'),
  ('cloud data services','devtools_infra'), ('web hosting','devtools_infra'),
  ('data center','devtools_infra'), ('it management','devtools_infra'),
  -- ai_platform ---------------------------------------------------------------
  ('artificial intelligence (ai)','ai_platform'), ('machine learning','ai_platform'),
  ('generative ai','ai_platform'), ('agentic ai','ai_platform'),
  ('ai infrastructure','ai_platform'), ('computer vision','ai_platform'),
  ('image recognition','ai_platform'), ('natural language processing','ai_platform'),
  ('chatbot','ai_platform'), ('virtual assistant','ai_platform'),
  ('intelligent systems','ai_platform'), ('foundational ai','ai_platform'),
  ('data collection and labeling','ai_platform'), ('speech recognition','ai_platform'),
  ('predictive analytics','ai_platform'),
  -- data_analytics ------------------------------------------------------------
  ('data and analytics','data_analytics'), ('analytics','data_analytics'),
  ('big data','data_analytics'), ('business intelligence','data_analytics'),
  ('data visualization','data_analytics'), ('data management','data_analytics'),
  ('data integration','data_analytics'), ('data mining','data_analytics'),
  ('market research','data_analytics'), ('geospatial','data_analytics'),
  -- commerce ------------------------------------------------------------------
  ('commerce and shopping','commerce'), ('e-commerce','ecommerce'),
  ('e-commerce platforms','ecommerce'), ('retail','commerce'),
  ('retail technology','commerce'), ('marketplace','commerce'),
  ('consumer goods','commerce'), ('consumer electronics','commerce'),
  ('clothing and apparel','commerce'), ('fashion','commerce'),
  ('food and beverage','commerce'),
  -- martech_sales -------------------------------------------------------------
  ('sales and marketing','martech_sales'), ('digital marketing','martech_sales'),
  ('marketing','martech_sales'), ('advertising','martech_sales'),
  ('marketing automation','martech_sales'), ('seo','martech_sales'),
  ('content marketing','martech_sales'), ('social media marketing','martech_sales'),
  ('brand marketing','martech_sales'), ('sales automation','martech_sales'),
  ('lead generation','martech_sales'), ('crm','martech_sales'),
  ('email marketing','martech_sales'), ('advertising platforms','martech_sales'),
  ('personalization','martech_sales'), ('sales','martech_sales'),
  -- media ---------------------------------------------------------------------
  ('media and entertainment','media'), ('content and publishing','media'),
  ('video','creative_tools'), ('digital media','media'), ('music and audio','media'),
  ('music','media'), ('gaming','gaming'), ('video games','gaming'),
  ('social media','media'), ('social network','media'), ('content','media'),
  ('content creators','creative_tools'), ('photography','creative_tools'), ('publishing','media'),
  ('metaverse','media'), ('augmented reality','media'),
  ('virtual reality','media'),
  -- education -----------------------------------------------------------------
  ('education','education'), ('edtech','education'), ('e-learning','education'),
  ('training','education'), ('corporate training','education'),
  -- business_services (agencies, HR, support: services, not product companies) --
  ('consulting','business_services'), ('management consulting','business_services'),
  ('professional services','business_services'), ('administrative services','business_services'),
  ('outsourcing','business_services'), ('creative agency','business_services'),
  ('staffing agency','business_services'), ('business development','business_services'),
  ('environmental consulting','business_services'), ('web development','business_services'),
  ('web design','business_services'), ('ux design','business_services'),
  ('design','business_services'), ('graphic design','creative_tools'),
  ('product design','business_services'), ('human resources','business_services'),
  ('recruiting','business_services'), ('customer service','business_services'),
  ('technical support','business_services'), ('call center','business_services'),
  ('translation service','business_services'), ('service industry','business_services'),
  -- physical_economy (real estate, industry, logistics, travel, energy, telco) --
  ('manufacturing','physical_economy'), ('industrial automation','physical_economy'),
  ('industrial','physical_economy'), ('energy','physical_economy'),
  ('sustainability','physical_economy'), ('automotive','physical_economy'),
  ('autonomous vehicles','physical_economy'), ('robotics','physical_economy'),
  ('logistics','physical_economy'), ('supply chain management','physical_economy'),
  ('transportation','physical_economy'), ('construction','physical_economy'),
  ('real estate','physical_economy'), ('property management','physical_economy'),
  ('proptech','physical_economy'), ('agriculture and farming','physical_economy'),
  ('agriculture','physical_economy'), ('agtech','physical_economy'),
  ('natural resources','physical_economy'), ('travel and tourism','physical_economy'),
  ('travel','physical_economy'), ('hospitality','physical_economy'),
  ('events','physical_economy'), ('telecommunications','physical_economy'),
  ('messaging and telecommunications','physical_economy'),
  -- generic_tech (product-type tags with no industry information) ---------------
  ('software','generic_tech'), ('information technology','generic_tech'),
  ('internet services','generic_tech'), ('internet','generic_tech'),
  ('apps','generic_tech'), ('mobile','generic_tech'), ('mobile apps','generic_tech'),
  ('saas','generic_tech'), ('enterprise software','generic_tech'),
  ('science and engineering','generic_tech'), ('hardware','generic_tech'),
  ('computer','generic_tech'), ('b2b','generic_tech'), ('productivity tools','generic_tech'),
  ('collaboration','generic_tech'), ('platforms','generic_tech'),
  ('online portals','generic_tech'), ('web apps','generic_tech'), ('real time','generic_tech'),
  ('small and medium businesses','generic_tech'), ('information services','generic_tech'),
  ('project management','generic_tech'), ('business process automation (bpa)','generic_tech'),
  ('robotic process automation (rpa)','generic_tech'),
  ('enterprise resource planning (erp)','generic_tech'),
  ('document management','generic_tech'), ('business information systems','generic_tech'),
  ('navigation and mapping','generic_tech'), ('search engine','generic_tech'),
  ('electronics','generic_tech'), ('messaging','generic_tech'),
  ('product management','generic_tech'), ('3d technology','generic_tech'),
  ('simulation','generic_tech'),
  -- other (named explicitly so the choice is visible) ----------------------------
  ('other','other'), ('non profit','other'), ('community and lifestyle','other'),
  ('social impact','other'), ('advice','other')
) AS m(token, sector);

-- LLM / GenAI signal. Deliberately separate from sector: it answers "does this
-- company build on LLMs?", which cuts across every sector. Only 21 companies say
-- "LLM" in their description and none in categories; the vocabulary in this data is
-- "Generative AI" / "Agentic AI", so those carry the signal. Plain "Machine
-- Learning" and "Artificial Intelligence" are NOT included: they predate LLMs and
-- would flag 67% of the sample. Rows marked (*) do not occur in this extract but are
-- listed so a refreshed pull is picked up.
CREATE TABLE stg.llm_signal_token AS
SELECT * FROM (VALUES
  ('generative ai',               'genai'),
  ('agentic ai',                  'agentic'),
  ('ai agents',                   'agentic'),       -- (*)
  ('chatbot',                     'chatbot'),
  ('virtual assistant',           'chatbot'),
  ('conversational ai',           'chatbot'),       -- (*)
  ('natural language processing', 'nlp'),
  ('nlp',                         'nlp'),           -- (*)
  ('large language model',        'llm'),           -- (*)
  ('llm',                         'llm'),           -- (*)
  ('copilot',                     'copilot'),       -- (*)
  ('foundational ai',             'foundation_model')
) AS t(token, signal);
