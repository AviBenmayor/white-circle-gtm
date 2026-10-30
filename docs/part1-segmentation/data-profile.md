# Data profile: Crunchbase extract (organizations / funding_rounds / contacts)

Profiled 2026-10-29, read-only, DuckDB 1.5.5. Every column is read as `all_varchar` so nothing is silently coerced, then cast with `try_cast`.
Rows: 3,000 organizations, 1,854 funding rounds, 2,763 contacts.

**Headline.** The data is far cleaner than "raw and a little messy" suggests: no duplicate uuids or names, no orphans, no name drift, no unparseable numbers or dates, categorical values are consistent snake_case codes. The mess is elsewhere: sparsity, coded range columns, `;`-delimited multi-value columns, URL and email inconsistencies, role-level contact duplicates, and snapshot semantics that quietly mislead (acquired companies still `active`, `funding_stage` mixing two meanings). The sample is not a random Crunchbase slice: it is AI-heavy by construction (2,023 of 3,000 are AI-tagged), so "AI" is not a discriminating ICP filter on its own.

Setup used throughout (script harness in the scratchpad):
```sql
CREATE VIEW organizations AS SELECT * FROM read_csv('.../organizations.csv', all_varchar=true, header=true, sample_size=-1);
-- same for funding_rounds, contacts
```

## 1. Duplicates

| Check | Result | Cleaning approach |
|---|---|---|
| Duplicate org uuid | 0 | Still add `PRIMARY KEY (uuid)` in the staging table so a re-pull fails loudly |
| Duplicate org name (case/space-insensitive) | 0 | None; do not dedupe on name (names are not unique in real Crunchbase) |
| Duplicate website domain (scheme/www/path stripped) | 0 | Build `domain` with `regexp_replace`; use it as the secondary match key |
| Duplicate linkedin_url | 0 | None |
| Duplicate funding rounds (org, type, date, amount) | 0 | None; keep composite key `(org_uuid, investment_type, announced_on)` |
| Same org + same announce date, different rows | 21 (2 types same day, e.g. `debt_financing` + `series_a`) | Legitimate; do not dedupe on (org, date). Break ties by a stable type rank when picking "latest round" |
| Contacts: repeated (org_uuid, person_uuid) | 66 extra rows (13 also repeat title); 11 are exact title repeats with different `started_on` or identical | `QUALIFY row_number() OVER (PARTITION BY org_uuid, person_uuid ORDER BY started_on DESC NULLS LAST) = 1`. These are multiple roles (Co-Founder then CEO), so keep a `roles` list if titles matter |
| Contacts: person_uuid in more than one org | 4 people (70 dup person_uuid rows = 66 + 4) | Legitimate (serial founders); key a person on `(org_uuid, person_uuid)` |
| Contacts: same linkedin url, different person_uuid | 0 | None |

```sql
SELECT count(*)-count(DISTINCT (org_uuid,person_uuid)) FROM contacts;                 -- 66
SELECT count(*)-count(DISTINCT (org_uuid,investment_type,announced_on)) FROM funding_rounds; -- 0
```

## 2. Join coverage

| Check | Result | Cleaning approach |
|---|---|---|
| Orgs with >= 1 round | 800 (26.7%) | LEFT JOIN from organizations, never INNER, or 73% of the universe vanishes |
| Orgs with >= 1 contact | 1,047 (34.9%); 1,007 are active | Same; "no contact" is a segment ("needs enrichment"), not an error |
| Orgs with neither rounds nor contacts | 1,697 (56.6%) | Flag `has_contact`, `has_funding` on the org-level model |
| Orgs with 0 contacts / 1 / 8+ | 1,953 / 432 / 86 | 8 looks like a cap on the export per org |
| Orphan rounds / orphan contacts | 0 / 0 | Keep as an assertion test (`NOT EXISTS`) |
| org_name differs from organizations.organization_name for same uuid | 0 / 0 | Drop the denormalised `org_name` from rounds/contacts; join for it |
| `funding_round_count` vs actual round rows | 0 mismatches (null on exactly the 2,200 orgs without rounds) | Recompute from rounds rather than trusting the column |

```sql
SELECT count(*) FILTER (WHERE EXISTS (SELECT 1 FROM funding_rounds r WHERE r.org_uuid=o.uuid)) AS with_rounds FROM organizations o;
```

## 3. Per-column messiness

### 3a. Null / blank rates (% of rows, `NULL` or `''`)

| Table | Column | % null |
|---|---|---|
| organizations | closed_on 99.1, funding_stage 75.6, funding_total_usd 79.3, last_funding_* 73.3, funding_round_count 73.3, investor_count/names 77.6, article_count 70.9, revenue_range 60.1, contact_email 19.4, employee_count_range 18.1, founded_on 14.0, city/region/country 12.5 (identical rows), linkedin_url 11.3, company_type 2.6, website_url 0.7 | |
| funding_rounds | lead_investor_names 51.1, money_raised_usd 25.6, investor_count 21.0 | |
| contacts | started_on 22.4, person_country 10.0, person_linkedin_url 9.0 | |

Approach: treat null as "unknown", never 0. `NULLIF(trim(col),'')` at staging. Never impute revenue or employees; carry an `is_known` flag. Geography nulls are all-or-nothing (city, region, country null together, 375 rows), so one `has_geo` flag suffices.

### 3b. Categorical columns (all clean, no casing or spelling variants)

| Column | Distinct values and counts | Issue / approach |
|---|---|---|
| operating_status | active 2,928; closed 72 | Clean. Note 46 of 72 closed have no `closed_on` |
| company_type | for_profit 2,904; non_profit 17; null 79 | Map null to `'unknown'` |
| ipo_status | private 2,971; public 29 | Clean |
| employee_count_range | c_00011_00050 1,062; c_00001_00010 912; null 544; c_00051_00100 222; c_00101_00250 138; c_00251_00500 58; c_01001_05000 29; c_00501_01000 25; c_10001_max 7; c_05001_10000 3 | Coded strings; sorts lexically only by luck. Map to `emp_min`, `emp_max`, `emp_bucket_order` via a lookup CTE |
| revenue_range | null 1,803; r_00001000 762; r_00000000 215; r_00010000 151; r_00100000 28; r_00050000 26; r_01000000 7; r_00500000 5; r_10000000 3 | Codes are lower bounds, not labels (r_00001000 = $1M+, per Crunchbase). Treat as an ordinal bound; `r_00000000` is a real band (<$1M), not null. 60% null: do not use as a hard filter |
| funding_stage | null 2,268; seed 456; m_and_a 127; early_stage_venture 90; ipo 26; late_stage_venture 21; private_equity 12 | Mixes two ideas: funding maturity and exit state. 63 non-null stage rows have no rounds. Split into `funding_stage` and `exit_flag` |
| last_funding_type | null 2,200; seed 259; pre_seed 176; series_a 77; series_unknown 65; grant 30; non_equity_assistance 27; angel 23; series_b 19; private_equity 17; convertible_note 16; debt_financing 15; corporate_round 13; equity_crowdfunding 12; series_d 10; series_c 9; post_ipo_debt 9; undisclosed 6; post_ipo_equity 5; secondary_market 4; series_f 3; series_e/post_ipo_secondary/series_g/initial_coin_offering/product_crowdfunding 1 each | Group into `equity_venture` (pre_seed..series_*), `non_dilutive` (grant, non_equity_assistance), `debt`, `public_market`, `other`. Do not treat `series_unknown` as unfunded |
| investment_type (rounds) | seed 581; pre_seed 348; series_a 172; series_unknown 161; grant 94; series_b 81; angel 69; non_equity_assistance 60; debt_financing 47; series_c 41; convertible_note 33; private_equity 25; post_ipo_equity 21; series_d 21; corporate_round 19; equity_crowdfunding 16; post_ipo_debt 15; secondary_market 12; undisclosed 10; series_e 9; series_f 7; post_ipo_secondary/initial_coin_offering/series_g 3 each; series_h 2; product_crowdfunding 1 | Same vocabulary as `last_funding_type` (good); one shared lookup table |
| country | 105 distinct, no case variants; US 949, null 375, UK 327, India 197, Canada 116, Germany 80, France 54, Spain 52, Brazil 46, China 45 | Crunchbase names, not ISO: "The Netherlands", "Russian Federation", "Slovakia (Slovak Republic)". Join to an ISO table with a small alias map. contacts.person_country uses the same style (null 277) |

### 3c. Money columns

| Column | Non-null | Unparseable | Negative | Zero | Min / median / p99 / max | Approach |
|---|---|---|---|---|---|---|
| funding_total_usd | 620 | 0 | 0 | 1 | 0 / 2.53M / 812M / 4.35B (Accor) | Plain doubles, no currency strings, no `$`/commas. Cast with `try_cast(... AS DOUBLE)` and assert |
| last_funding_total_usd | 559 | 0 | 0 | 1 | 0 / 1.66M / 285M / 1.0B | Name is misleading: it is the amount of the last round |
| money_raised_usd | 1,380 | 0 | 0 | 1 (Adzact pre_seed) | 0 / 1.84M / 283M / 3.2B | Zero is "undisclosed" not "raised $0": `NULLIF(x,0)` |

Outliers are real and come from public companies (Accor 3.2B `post_ipo_equity`, Sinch 1.13B, Wix 1.0B `post_ipo_debt`): exclude `post_ipo_*` and debt from "venture raised" metrics, and use `log10` or percentile bands for size. No sub-$1,000 amounts, so no unit (thousands vs units) problem was detectable. All amounts are USD by column name; no currency field exists, so currency cannot be verified.

### 3d. Dates

| Column | Non-null | Format | Unparseable | Future (> today) | Notes |
|---|---|---|---|---|---|
| founded_on | 2,579 | all ISO `YYYY-MM-DD` | 0 | 0 | 1,371 (53%) are `-01-01`: year-only precision padded to Jan 1. 5 before 1900 (earliest 1833); 193 before 2000 (old incumbents, not startups) |
| closed_on | 26 | ISO | 0 | 0 | 0 closed before founded |
| last_funding_at | 800 | ISO | 0 | 0 | max 2026-06-20 (snapshot ~June 2026; 9 rounds after 2026-06-01) |
| announced_on | 1,854 | ISO | 0 | 0 | 95 are `-01-01` (year-only) |
| contacts.started_on | 2,144 | ISO | 0 | 0 | 588 are `-01-01`; 1,870 are first-of-month (month precision). 78 contacts "started" more than a year before the org was founded |

Other date checks: 11 rounds announced more than a year before the org's `founded_on`; 4 rounds announced after `closed_on`. Approach: add `founded_precision` ('year' when `-01-01`), compute ages in years only; flag impossible rows rather than deleting them.

### 3e. Delimited multi-value columns

`categories`, `category_groups`, `investor_names` are `'; '`-separated (semicolon + space, consistently: 0 rows with a bare `;`, 0 with untrimmed ends). 4 category strings contain commas (inside names such as "Gaming, ..."), so do **not** split on commas. `lead_investor_names` is free text with legal-suffix commas ("Little Bug Ventures, LLC", "..., Co., Ltd."), so it cannot be split safely. 601 distinct category tokens, no case or spelling collisions (601 raw = 601 normalised). 1-21 categories per org (mean 5.25). `investor_count` disagrees with the count of names on 440 of 672 orgs (the name list is truncated to a few names): do not recount from names.

Top 40 category tokens: Software 1,252; Artificial Intelligence (AI) 1,243; Information Technology 656; Generative AI 593; Machine Learning 403; Consulting 379; SaaS 363; Enterprise Software 311; Analytics 258; Health Care 255; Cloud Computing 239; E-Commerce 212; Financial Services 208; Digital Marketing 171; Web Development 169; Agentic AI 155; Marketing 154; Cyber Security 144; Mobile Apps 143; DevOps 134; FinTech 129; Education 123; Business Process Automation (BPA) 123; Internet 122; Advertising 121; Marketing Automation 110; Software Engineering 108; Big Data 101; Electronic Health Record (EHR) 99; Computer Vision 91; Customer Service 89; Chatbot 88; Security 87; Blockchain 86; Data Integration 86; Internet of Things 84; Developer Tools 81; Medical 79; Apps 79; Manufacturing 77.

The "inconsistent categories" are therefore semantic, not typographic: overlap and synonyms (`Cyber Security` 144 vs `Security` 87 vs `Privacy and Security` group; `Chatbot`, `Generative AI`, `Agentic AI`, `Machine Learning` overlap; `FinTech` 129 vs `Financial Services` 208 vs `Payments` 122). Approach: unnest to a bridge table `org_category(uuid, token)` and map tokens to a small curated taxonomy with a lookup table; never string-match the raw column (`LIKE '%AI%'` also hits "Fair", "Retail").

```sql
CREATE TABLE org_category AS
SELECT uuid, trim(unnest(string_split(categories, '; '))) AS category FROM organizations;
```

### 3f. Cross-column consistency

| Check | Result | Approach |
|---|---|---|
| funding_total_usd = SUM(rounds.money_raised_usd) | 620/620 agree exactly; 180 orgs with rounds have null total (all their round amounts are null); 0 disagreements | Safe to trust; for the 180, report `NULL` not 0 |
| last_funding_at = MAX(announced_on) | 800/800 agree | Safe |
| last_funding_type = type of latest round | 4 of 800 disagree (Nagomi Security series_a vs seed; Breaking Change; SumX; LogicMonitor) because two rounds share one date | Recompute from rounds with a deterministic tie-break |
| operating_status vs closed_on | 72 closed, only 26 have `closed_on`; 0 active with closed_on | Do not rely on `closed_on` to find dead companies; use `operating_status` |
| funding_stage = m_and_a but operating_status = active | 106 (plus 21 closed) | Acquired but still listed active: exclude or flag as `acquired`; they are not buyers |
| ipo_status = public but funding_stage not ipo | 3 | Trust `ipo_status` |
| tiny headcount but high revenue (1-10 emp, >= $10M band) | 7 | Low-confidence; ignore for scoring |

```sql
WITH s AS (SELECT org_uuid, sum(try_cast(money_raised_usd AS DOUBLE)) sm, max(announced_on::DATE) mx FROM funding_rounds GROUP BY 1)
SELECT count(*) FILTER (WHERE abs(o.funding_total_usd::DOUBLE - sm) >= 1) AS total_disagree,
       count(*) FILTER (WHERE o.last_funding_at::DATE <> mx) AS date_disagree
FROM organizations o JOIN s ON s.org_uuid = o.uuid;   -- 0, 0
```

## 4. ICP-relevant signal coverage (3,000 orgs)

Regex on lower-cased `categories` and `short_description`; counts are orgs, not mentions.

| Signal | in categories | in description | either |
|---|---|---|---|
| Generative AI (`generative ai`, `genai`) | 593 | 80 | 605 |
| AI agent / agentic | 155 | 112 | 236 (pattern includes bare "agent", so an upper bound) |
| Chatbot / conversational AI / virtual assistant | 98 | 76 | 117 |
| LLM / large language model | 0 | 21 | 21 |
| NLP / natural language | 37 | 10 | 43 |
| Copilot | 0 | 7 | 7 |
| Foundation model | 0 | 0 | 0 |
| **Any of the above (union)** | 820 | 262 | **871 (29%)** |
| Any AI tag (AI in categories or category_groups) | | | 2,023 (67%) |
| Fintech / banking / payments / lending (cat, groups) | 420 | 72 | 429 |
| Neobank / digital bank (strict) | 0 | 6 | 6 |
| Health / medical / biotech / pharma | 363 | 221 | 383 |
| Insurance / insurtech | 47 | 28 | 50 |
| Legal / compliance | 73 | 64 | 95 |
| GenAI-signal AND fintech-signal | | | 46 |
| GenAI-signal AND health-signal | | | 40 |
| Direct guardrail / AI safety / red-team / prompt injection / responsible AI language | | | 3 (RATIONAL AI SRL, HumanLens, AceUp, per a loose match) |

Few firms say "LLM" outright (21); the vocabulary is "Generative AI" and "Agentic AI". LLM is an under-count by text, so tier on category tokens first, description second.

Last funding date by year (800 funded orgs): 2026 77; 2025 138; 2024 117; 2023 111; 2022 76; 2021 66; 2020 54; 2019 34; 2018 33; 2017 24; 2016 25; 2015 19; 2014 and earlier 36. Funded since 2024-01-01: 332; since 2025-01-01: 215; within 12 months of 2026-10-29: 98. Funding recency is coverage-limited (73% have no round at all).

Employee range (all 3,000; active-only differs by < 5%): 1-10 912; 11-50 1,062; 51-100 222; 101-250 138; 251-500 58; 501-1,000 25; 1,001-5,000 29; 5,001-10,000 3; 10,001+ 7; null 544. 66% of orgs are under 50 people, a small-company universe.

Contact titles (2,763 rows; regexes on lower-cased `job_title`, rows can match several):

| Bucket | Rows |
|---|---|
| Any C-level (`chief` or `c?o`) | 1,369 |
| Founder / co-founder / owner | 1,058 |
| CEO | 715 |
| CTO / chief technology | 270 |
| VP / Head / Director of eng, AI, ML, data, product, technology | 139 |
| AI / ML / data specific leaders (head/VP/chief) | 17 |
| Engineers / developers | 97 |
| Product | 75 |
| Sales / growth / marketing / revenue | 131 |
| Compliance / risk / legal / counsel / privacy / DPO | 26 |
| Security / CISO | 7 (orgs: 7) |
| Non-operators (board member/observer, advisor, investor) | 430-515 |

Orgs with a CEO or founder contact: 898; with a CTO or technical head: 399; with any security title: 7. The security and compliance buyer is essentially absent from this extract, so route by founder/CTO. Titles: 1,005 distinct, 947 after case-fold (58 case-only duplicates), so bucket with regex or a lookup, not exact match.

## 5. Surprises and likely traps

| Finding | Count | Approach |
|---|---|---|
| Sample is AI-heavy by construction; "AI" tag is not discriminating | 2,023 AI-tagged | Score on specific signals (genai/agentic/chatbot) plus vertical, not "has AI" |
| Wrong-ICP incumbents / public majors in the list | 29 public (Accor 10k+ staff, McKesson, Experian, Dräger, Wix, Sinch, ZipRecruiter, Teledyne FLIR, Freshworks); 39 orgs with 1,000+ staff | Keep but segment as enterprise, or exclude from a startup-led model; their funding is `post_ipo_*` and distorts averages |
| Acquired companies still `operating_status = active` | 106 (127 with `m_and_a`) | Exclude from outreach: `WHERE funding_stage IS DISTINCT FROM 'm_and_a'` |
| Closed companies, some with contacts | 72 closed; 40 have contacts; 46 lack `closed_on` | Exclude by `operating_status`; no closed org has a round after 2024 |
| Non-profits | 17 | Exclude |
| `contact_email` is a generic inbox | 1,657 of 2,420 non-null (info@, hello@, contact@...); 53 freemail | Not a person: never use as a contact; flag `is_generic_inbox`. Email domain differs from the website domain on 333 of 2,415 (e.g. itadviser.dev vs itadviser.org): mismatched, so do not derive the domain from the email |
| Website URLs are inconsistent | 414 `http://`; 984 trailing slash; 46 with a path; 18 with uppercase; 4 social/profile sites; 4 with `utm_source=crunchbase` tracking | Normalise to a bare lower-case registrable domain (strip scheme, `www.`, path, query) before any dedupe or enrichment join. linkedin_url: 70 `http://`, 45 not `/company/` URLs. Contacts: 191 `http://` LinkedIn URLs, many legacy `/pub/` style |
| Truncated descriptions | 214 at 139-140 chars (cap is 140); 515 lack terminal punctuation; 7 contain non-breaking spaces | Regex on text is low-recall; strip `\xa0` and treat description as a hint, not a source |
| Name oddities | 2 with underscores (`open200_software company`, `thewall_`); 305 all-caps; 38 non-ASCII; 84 end in a legal suffix; 78 look like domains | `lower(trim(...))`, strip legal suffixes for fuzzy matching only; do not use names as keys |
| Year-only dates stored as Jan 1 | 1,371 founded_on; 588 contact starts | Add precision flag; do not compute months-since on these |
| Dates relative to snapshot | max date 2026-06-20 vs today 2026-10-29 | Pin an `as_of` constant, do not use `current_date` for recency or the answers drift every day |
| No test/placeholder rows, no injected instructions | 0 test rows ("Playtest" is a real name; two descriptions match "instruction" benignly) | None needed; keep untrusted-text handling for any LLM step that reads descriptions |
| Reference-customer lookalikes | No Lovable, no named neobanks (Revolut, Monzo, N26, Nubank, Chime, Starling all absent) | The extract is a lookalike pool, not a customer list; there is no "customer" flag to train on |

**Deliberate-trap candidates** (inference, not provable): (1) acquired-but-`active` (106) and `funding_stage` doubling as exit state; (2) generic inboxes presented as `contact_email`; (3) NULL-heavy funding/revenue so INNER JOINs silently drop 73% of orgs; (4) role-level contact duplicates (66) that inflate headcount of decision makers; (5) public giants with huge `post_ipo_*` rounds skewing money aggregates; (6) coded `r_`/`c_` ranges that look numeric but are lower bounds. The otherwise-clean keys suggest the messiness was mostly left natural rather than injected.
