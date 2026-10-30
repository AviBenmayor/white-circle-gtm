-- 50_mart_score_weights.sql  ->  mart.params, mart.vertical_gate, mart.score_weight, mart.fit_bonus_rule
--
-- SCORE v4. THE ONE PLACE the scoring opinion lives. The model has two stages:
--   1. EXCLUSION GATES (58_): yes/no rules. An org that trips ANY gate is out, and the
--      first gate it trips is recorded. Gates never score; they only remove.
--   2. A FIXED POINTS RUBRIC (60_) for the orgs that pass every gate. Every point value
--      is read from this file. No weights are written anywhere else.
-- Re-weighting = edit this file and run `whitecircle build`.
--
-- THE WEIGHTS ARE STATED PRIORS. They encode a hypothesis about who buys an AI-control
-- product, they are NOT fitted to closed-won data (the extract has no customer flag),
-- and they are meant to be RECALIBRATED against realized results.
-- Example of what a recalibration would look like: add headcount growth (a 20-point
-- factor, from Apollo/PDL) and test it against realized meetings and wins; it is left out
-- of this version because there is no enrichment data, not scored as zero.
-- To make that possible, every scoring run is appended to ops.score_history (61_, shown
-- as mart.score_history) with the exact inputs, the points per component and a
-- timestamp, so a past ranking can be reproduced and compared with what happened.
--
-- RUBRIC (80 points) plus FIT BONUS (up to 10) = 90:
--   Funding recency   40  last EQUITY round: money recently raised means budget now
--   Revenue range     25  can they pay for an enterprise tool
--   Headcount         15  big enough to have a product + security team, small enough to buy quickly
-- --   Fit bonus      0-10   White Circle's own landing pages and press, see fit_bonus_rule below
-- REGION earns NO points. White Circle sells in Europe and North America, so region
-- only breaks ties in the ranking (eu_uk and us_ca first, see 60_).
--
-- mart.params: as_of is pinned (not current_date) so the ranking never drifts with the
-- day it is run. The snapshot's latest round is 2026-06-20.
CREATE TABLE mart.params AS
SELECT DATE '2026-10-29' AS as_of, 'v4' AS score_version;

-- mart.vertical_gate: which industries pass gate 9 (industry_not_matched), and why.
-- "Vertical" is the org's industry after the website check (verified) or, if never
-- checked, after the Crunchbase tags (55_). 'ai_native' is not a Crunchbase industry:
-- 57_ assigns it to an org that SHIPS an LLM / agent as its product and sits in a
-- horizontal sector (generic_tech / ai_platform / devtools) instead of an industry,
-- i.e. the Lovable-style builders.
--   regulated core       fintech_banking, insurance, health, legal_compliance
--   AI-native builders   ai_native
--   verticals White Circle markets to (homepage tabs + landing pages, research section 2):
--                        public_sector, education, hr_recruiting, ecommerce, gaming,
--                        creative_tools, real_estate
--   everything else FAILS: crypto_web3, consumer_wellness, finance_ops, security, media,
--                        generic_tech (generic software that does NOT ship an LLM
--                        product), other.
-- Limits of the tags: the shared taxonomy files media, commerce, logistics, travel and
-- real estate under 'other' (55_ keeps only 14 sectors), so an UNVERIFIED org in those
-- sectors lands in 'other' and fails (right for media and other). real_estate is listed
-- so the rule is visible, but no org can reach it because real estate is not separable
-- from physical_economy in the map (20_). Verified orgs carry the reviewer's
-- true_vertical and can land in any row.
CREATE TABLE mart.vertical_gate AS
SELECT * FROM (VALUES
  ('fintech_banking',  'regulated core',     TRUE,  'Banking, payments, lending, neobank: the validated bank wedge (research section 2).'),
  ('insurance',        'regulated core',     TRUE,  'Claims and underwriting decisions are regulated.'),
  ('health',           'regulated core',     TRUE,  'Patient data and clinical advice (HIPAA; White Circle holds a HIPAA attestation).'),
  ('legal_compliance', 'regulated core',     TRUE,  'Hallucinated advice carries professional liability; legal firms appear in the press.'),
  ('ai_native',        'AI-native builder',  TRUE,  'Ships an LLM or agent as the product: the Lovable pattern, the only named customer.'),
  ('public_sector',    'marketed vertical',  TRUE,  'Government is a homepage tab.'),
  ('education',        'marketed vertical',  TRUE,  'Education is a homepage tab.'),
  ('hr_recruiting',    'marketed vertical',  TRUE,  'Has a dedicated landing page.'),
  ('ecommerce',        'marketed vertical',  TRUE,  'Has a dedicated landing page.'),
  ('gaming',           'marketed vertical',  TRUE,  'Has a dedicated landing page.'),
  ('creative_tools',   'marketed vertical',  TRUE,  'Has a dedicated landing page.'),
  ('real_estate',      'marketed vertical',  TRUE,  'Has a dedicated landing page; not separable in the category map, so no org reaches it today.'),
  ('crypto_web3',      'not matched',        FALSE, 'Not a vertical White Circle names; not the neobank profile.'),
  ('consumer_wellness','not matched',        FALSE, 'No regulator or landing page.'),
  ('finance_ops',      'not matched',        FALSE, 'Back-office accounting / billing software, not a regulated institution.'),
  ('security',         'not matched',        FALSE, 'Security vendors build or compete rather than buy.'),
  ('media',            'not matched',        FALSE, 'Not a named vertical.'),
  ('generic_tech',     'not matched',        FALSE, 'Generic software that does not ship an LLM product: nothing to guard.'),
  ('other',            'not matched',        FALSE, 'No industry signal in the passing list.')
) AS t(vertical, grp, passes, rationale);

-- mart.score_weight: the rubric. component, level, points, rationale. Levels are the
-- bucket names 60_ derives. The rationale text is shown on the dashboard. Every row is a
-- STATED PRIOR to be recalibrated against realized results (see the header).
CREATE TABLE mart.score_weight AS
SELECT * FROM (VALUES
  -- Funding recency (max 40): months since the last EQUITY round, as_of 2026-10-29 -------
  ('funding_recency', 'le_6m',   40, 'Stated prior. Last equity round within 6 months: the money is new, the AI roadmap is funded now.'),
  ('funding_recency', 'le_12m',  32, 'Stated prior. Equity round 6-12 months ago: budget still fresh.'),
  ('funding_recency', 'le_18m',  24, 'Stated prior. Equity round 12-18 months ago.'),
  ('funding_recency', 'le_24m',  16, 'Stated prior. Equity round 18-24 months ago: budget probably still there.'),
  ('funding_recency', 'le_36m',   8, 'Stated prior. Equity round 2-3 years ago: may be running down cash.'),
  ('funding_recency', 'gt_36m',   2, 'Stated prior. Equity round over 3 years ago.'),
  ('funding_recency', 'unknown',  0, 'No equity round on file (73% of companies have none) or no date: unknown, scored 0.'),
  -- Revenue range (max 25): decoded Crunchbase bands (10_) -------------------------------
  ('revenue', 'lt_1m',      5, 'Stated prior. Under $1M: little to spend on tooling.'),
  ('revenue', '1m_10m',    15, 'Stated prior. $1M-$10M: real budgets, founder-led buying.'),
  ('revenue', '10m_50m',   25, 'Stated prior. $10M-$50M: the sweet spot for a platform purchase.'),
  ('revenue', '50m_100m',  25, 'Stated prior. $50M-$100M: same, with a security function.'),
  ('revenue', 'ge_100m',   20, 'Stated prior. $100M and up: can pay, but enterprise procurement drag slows the deal.'),
  ('revenue', 'unknown',    0, 'Revenue band not on file (60% of orgs): unknown, scored 0.'),
  -- Headcount (max 15): employee_count_range decoded (10_) -------------------------------
  ('headcount', '1-10',      3, 'Stated prior. Too small to have a budget line for this.'),
  ('headcount', '11-50',     8, 'Stated prior. Small team; founder-led buying.'),
  ('headcount', '51-200',   15, 'Stated prior. Product team and security review, quick to buy.'),
  ('headcount', '201-500',  15, 'Stated prior. Same. The Crunchbase band 101-250 straddles the 200 line; both sides score 15, so the band edge does not matter.'),
  ('headcount', '501-1000', 12, 'Stated prior. Larger: slower to buy.'),
  ('headcount', '1001+',     8, 'Stated prior. Enterprise-size: long cycles, likely to build in-house.'),
  ('headcount', 'unknown',   0, 'Headcount not on file: unknown, scored 0.'),
  -- Fit bonus cap ---------------------------------------------------------------------------
  ('fit_bonus_cap', 'cap',    10, 'The bonus from fit_bonus_rule is capped at 10.')
) AS w(component, level, points, rationale);

-- mart.fit_bonus_rule: the small fit bonus (0-10). From the v4 brief: "small fit bonus to
-- have white circle have already signaled by their landing pages and public messaging. we
-- want to use what they have already done as baseline for how we shape our response."
-- EVERY row below is derived ONLY from docs/context/whitecircle-research.md; the evidence column
-- cites the section and source numbers (S1.. = the source list at the bottom of that file).
-- Tiers: named customer / case-study category 6; homepage-tab vertical 5; dedicated
-- landing-page vertical 3; press-only mention 3; +4 for verified agentic (it positions on
-- agents taking actions). The bonus is the best vertical tier PLUS the agentic add-on,
-- capped at 10. A vertical the research does not support earns 0 and is listed with 0 so
-- that is visible. These tiers are stated priors, like the rubric.
-- kind = 'vertical' (matches the org's vertical) or 'feature' (adds on top).
CREATE TABLE mart.fit_bonus_rule AS
SELECT * FROM (VALUES
  ('vertical', 'ai_native',        6, 'named customer category',
   'Research s2 "Named customers": Lovable, a vibe-coding platform, is the only named logo and has a full case study with a CISO quote (S1, S3).'),
  ('vertical', 'fintech_banking',  6, 'named customer category',
   'Research s2: "two of the world''s largest digital banks" and "multiple neobanks" are customers, unnamed (S5, S6, S7). Category confirmed, no named logo.'),
  ('vertical', 'health',           5, 'homepage tab',
   'Research s2 "Industries marketing calls out": homepage tabs Government, Healthcare, Education (S1); HIPAA attestation in s1.'),
  ('vertical', 'public_sector',    5, 'homepage tab',
   'Research s2: Government is a homepage tab (S1).'),
  ('vertical', 'education',        5, 'homepage tab',
   'Research s2: Education is a homepage tab (S1).'),
  ('vertical', 'insurance',        3, 'dedicated landing page',
   'Research s2 and s3: insurance landing page, GDPR mention on it (S11, S12).'),
  ('vertical', 'hr_recruiting',    3, 'dedicated landing page',
   'Research s2: HR landing page (S11).'),
  ('vertical', 'ecommerce',        3, 'dedicated landing page',
   'Research s2: e-commerce landing page (S11).'),
  ('vertical', 'gaming',           3, 'dedicated landing page',
   'Research s2: gaming landing page (S11).'),
  ('vertical', 'creative_tools',   3, 'dedicated landing page',
   'Research s2: creative tools landing page (S11).'),
  ('vertical', 'real_estate',      3, 'dedicated landing page',
   'Research s2: real estate landing page (S11). No org reaches this vertical today (see vertical_gate).'),
  ('vertical', 'legal_compliance', 3, 'press-only mention',
   'Research s2: Fortune says "several fintech and legal companies" are customers (S6); no legal landing page found, so the press-only tier.'),
  ('vertical', 'crypto_web3',      0, 'not supported',
   'The research does not mention crypto anywhere. 0 (and it fails the industry gate anyway).'),
  ('vertical', 'other',            0, 'not supported',
   'No mapping in the research. 0.'),
  ('feature',  'verified_agentic', 4, 'positioning on agent actions',
   'Research s1 "Threats covered: tool abuse and destructive agent actions" (S1, S3, S8, S9) and s6 signal 2: "Agentic action-taking ... higher blast radius". Needs a website check that found an action-taking agent (is_agentic).')
) AS t(kind, key, points, tier, evidence);
