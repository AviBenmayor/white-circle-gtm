# Subagent trace: Draft Attio CRM data model

A delegated subagent (general-purpose). Its prompt, its tool calls and results, and its final report. Same redaction rules as the main session.

## Turn 1 - User (2026-10-29 15:26:25 UTC)

Draft the CRM data model for a GTM Engineer take-home for White Circle (AI-safety / LLM-guardrails platform; reference customers Lovable and neobanks; they use Attio + Clay; RB2B is on the website; paid ads launching; SDRs will mostly cold call, AEs should only close; qualification is MEDDPICC). Project: white_circle. Read `docs/assignment.md` (deliverable 4 of Part 1: "Design the CRM data-model that you will inject those data into") and skim `src/white_circle/sql/10_stg_organizations.sql`, `40_stg_contacts.sql` for available fields. A parallel agent is building scoring tables (`mart.org_score`, `mart.org_segment`, `mart.top50` with fit_score, component scores, segment, tier, data_confidence, reason_1..3) — design for those fields but don't touch the SQL or run anything that writes the DuckDB.

Verify Attio's actual data model before designing around it: use WebFetch on Attio's docs (docs.attio.com / developers.attio.com) to confirm standard objects (companies, people, deals), custom objects, lists, attribute types (select, status, record-reference, number, currency, date, etc.), and how the REST API upserts records (matching attribute, e.g. companies by domains). Cite what you confirmed vs assumed.

Write `docs/crm-data-model.md` (concise, opinionated, readable by a GTM leader in ~5 minutes):
- Entity diagram (Mermaid erDiagram) — Company, Person, Deal, Signal (custom object: RB2B visit, funding round, hiring post, news, ad engagement…), Enrichment Run (custom object or note — provenance: source, run_id, timestamp, confidence), plus Lists (e.g. SDR call queue, AE pipeline).
- Per object: attribute table (name, Attio type, source system: crunchbase/scoring/clay/tavily/rb2b/human, who writes it, sync direction). Company must carry: domain (match key), crunchbase uuid, segment, tier, fit_score + components, data_confidence, score_version, reasons, ICP flags (llm_level, vertical, region), owner, lifecycle stage. Deal must carry MEDDPICC as structured fields (each: status select + evidence text + last_updated + source e.g. Granola/Attio call note), stage definitions with entry/exit criteria, next step + due date, blocked_by.
- Field ownership rules: which fields automation may overwrite vs human-owned (never overwrite a human-set field; scoring fields are machine-owned and versioned).
- Identity resolution: match keys and dedupe rules (domain normalization, LinkedIn URL for people, the Crunchbase uuid as external id).
- A JSON example of the upsert payload for one company + one person shaped for Attio's API (`docs/deliverables/attio_upsert_example.json`).
- Also write `src/white_circle/sql/80_crm_export.sql` as a VIEW-only file creating `crm.company_upsert` and `crm.person_upsert` views that map mart/stg columns to Attio attribute slugs (it's fine if it references mart tables that don't exist yet — note in the header it runs after 70_). Do not run `whitecircle build`.

Do not commit; touch nothing outside white_circle/. Final reply (max 12 lines): files written, what you verified in Attio's docs vs assumed, and the 3 most debatable design choices.

Tool call `Bash`
```
cd white_circle; cat docs/assignment.md | head -150; ls src/white_circle/sql docs docs/deliverables; cat src/white_circle/sql/10_stg_organizations.sql src/white_circle/sql/40_stg_contacts.sql | head -150
```

Tool call `ToolSearch`
```
{
 "query": "select:WebFetch",
 "max_results": 1
}
```

Result of `ToolSearch`
```
[omitted: tool-schema lookup]
```

Result of `Bash`
```
# GTM Engineer — Take-Home Exercise

> Source: https://whitecircle.notion.site/GTM-Engineer-Take-Home-Exercise-38fc3dbe97908031bd22cb2d027b3f23 (copied 2026-10-29)


We’re at a critical juncture - revenue and customers, but no repeatability or playbook. Right now we have customers like Lovable and neobanks. Sales were founder-led till recently. We have started using Attio, Clay and are open to other tools as they become needed (eg. Granola for meetings where Attio cannot record, but don’t fixate on this).

Customer segmentation is not defined and we have SDRs and AEs joining soon. SDRs will be almost solely focused on cold calling, other channels should be automated for them. We want to prevent AEs from having to hunt so they can just focus on closing. Paid ads will be running in a few weeks and RB2B has been installed on our website.


---


#### Part 1 - Segmentation
*(Attachment: gtm-takehome-dataset.zip — the three CSVs in `data/raw/`)*
We've given you a slice of Crunchbase company data. It's raw and a little messy, on purpose.

Load it using the tool/tech of your choice, explore it, and use SQL to answer one question: *which companies should our AEs prioritize, and how would you group them into segments?*

- This is open-ended. You decide what "good fit" means for an AI-safety platform sold to companies deploying LLMs, and you defend it. There is no answer key.
- We want to see your SQL, not just conclusions. Show how you handle data quality issues, inconsistent categori
... [truncated 11320 chars]
```

Tool call `WebFetch`
```
{
 "url": "https://docs.attio.com/docs/objects-and-lists",
 "prompt": "List standard objects, custom objects, lists, attribute types (select, status, record-reference, currency, etc.), and any matching/unique attributes."
}
```

Tool call `WebFetch`
```
{
 "url": "https://docs.attio.com/rest-api/endpoint-reference/records/assert-a-record",
 "prompt": "How does the assert (PUT) record endpoint work? matching_attribute, request body shape, which attributes are allowed for people and companies, example payload."
}
```

Tool call `WebFetch`
```
{
 "url": "https://docs.attio.com/rest-api/guides/attribute-types",
 "prompt": "List every attribute type with the value shape for writing via API (text, number, checkbox, currency, date, timestamp, rating, status, select, record-reference, actor-reference, location, domain, email-address, phone-number, interaction). Note which can be multiselect."
}
```

Result of `WebFetch`
```
The server returned HTTP 404 Not Found.

The response body was not retrieved. If this URL requires authentication, use an authenticated tool (e.g. `gh` for GitHub, or an MCP-provided fetch tool) instead of WebFetch.
```

Result of `WebFetch`
```
The server returned HTTP 404 Not Found.

The response body was not retrieved. If this URL requires authentication, use an authenticated tool (e.g. `gh` for GitHub, or an MCP-provided fetch tool) instead of WebFetch.
```

Result of `WebFetch`
```
**Standard objects:** People and companies are enabled by default. Deal, user, and workspace are optional objects.

**Custom objects:** The page says you can define custom objects but doesn't explain how. It states that attributes are "defined yourself" in the UI or over the API.

**Lists:** Lists contain rows called "entries," and each entry corresponds to a single record. Lists can model a business process, such as a "Sales" list of companies. Lists can also have their own attributes, separate from the object's attributes.

**Attribute types:** The page names text, number, select, and currency, describing them as "one of many types." It does not mention status or record-reference.

**Matching/unique attributes:** The page doesn't cover these.
```

Tool call `WebFetch`
```
{
 "url": "https://docs.attio.com/rest-api/endpoint-reference/records/assert-a-record",
 "prompt": "x"
}
```

Tool call `WebFetch`
```
{
 "url": "https://docs.attio.com/llms.txt",
 "prompt": "List all URLs related to attribute types, assert record, matching attribute, deals, custom objects, lists entries, status attributes."
}
```

Result of `WebFetch`
```
The server returned HTTP 404 Not Found.

The response body was not retrieved. If this URL requires authentication, use an authenticated tool (e.g. `gh` for GitHub, or an MCP-provided fetch tool) instead of WebFetch.
```

Result of `WebFetch`
```
[redacted: outside project scope]
```

Tool call `WebFetch`
```
{
 "url": "https://docs.attio.com/rest-api/endpoint-reference/records/upsert-a-record.md",
 "prompt": "Full detail: matching_attribute, request body, which attributes are valid matching ones for companies and people, multiselect behavior on overwrite, example."
}
```

Tool call `WebFetch`
```
{
 "url": "https://docs.attio.com/rest-api/attribute-types/attribute-types.md",
 "prompt": "Summarize every type and its write value shape; note which are unique/immutable constraints."
}
```

Tool call `WebFetch`
```
{
 "url": "https://docs.attio.com/rest-api/attribute-types/attribute-types-record-reference.md",
 "prompt": "Write value shape for record reference, including how to reference by matching attribute (e.g. domain) instead of record_id."
}
```

Tool call `WebFetch`
```
{
 "url": "https://docs.attio.com/docs/standard-objects/standard-objects-deals.md",
 "prompt": "Deal standard attributes (name, stage, owner, value, associated people/company) and notes on required fields."
}
```

Result of `WebFetch`
```
**Deal standard attributes** (writeable, slug in parentheses):

- **Name** (`name`): Text. **Required.**
- **Deal stage** (`stage`): Status. **Required.** Defaults to Lead, In Progress, Won, and Lost, but workspaces can configure these options.
- **Deal owner** (`owner`): Actor reference. **Required.**
- **Deal value** (`value`): Currency. Defaults to USD, which can be changed.
- **Associated people** (`associated_people`): Record reference. A relationship that is the inverse of `Person -> associated_deals`.
- **Associated company** (`associated_company`): Record reference. A relationship that is the inverse of `Company -> associated_deals`.

**Notes on required fields:** Name, Deal stage, and Deal owner must be set. The other attributes are optional.

**Other notes:**
- The Deal object is disabled by default. A workspace admin must enable it in the objects settings.
- Deals have no unique attribute by default. Docs recommend adding one, such as an ID from your own system, to use as the matching attribute. A non-unique matching attribute also works, but a value that matches more than one deal is rejected.
```

Result of `WebFetch`
```
Record reference values can be written in four shapes:

**1. By record ID.** Pass `target_object` and `target_record_id`. The write fails if the target record doesn't exist.

`` `json
{
  "associated_company": [
    {
      "target_object": "companies",
      "target_record_id": "99a03ff3-0435-47da-95cc-76b2caeb4dab"
    }
  ]
}
`` `

**2. By a standard-object shortcut.** These only work when the attribute allows a single standard object. Like the ID form, the write fails if no match exists.
- Company: `domains`
- Person: `email_addresses`
- User: `user_id`
- Workspace: `workspace_id`

`` `json
{
  "associated_company": [
    {
      "domains": [{"domain": "company.com"}],
      "target_object": "companies"
    }
  ]
}
`` `

**3. By plain string.** Strings are interpreted based on the allowed object: a domain for companies, an email address for people, and a `user_id` or `workspace_id` text value for users or workspaces.

`` `json
{
  "associated_company": "company.com",
  "team": ["jane@company.com"]
}
`` `

**4. By matching an attribute with `target_record_reference`.** This form lets you match on any attribute, such as a domain, email, or your own system's ID, and choose what happens when nothing matches or several records match.

`` `json
{
  "associated_company": [
    {
      "target_object": "companies",
      "target_record_reference": {
        "match": {"domains": ["company.com"]},
        "if_unmatched": "create",
        "if_multiple_matches": "error",
        "create": 
... [truncated 541 chars]
```

Result of `WebFetch`
```
The page lists the 17 attribute types but doesn't describe their write value shapes or any per-type unique or immutable constraints. Those details are on the linked type-specific pages, which aren't included here.

**Attribute types (17):**
- Actor reference
- Checkbox
- Currency
- Date
- Domain
- Email address
- Interaction
- Location
- (Personal) name
- Number
- Phone number
- Rating
- Record reference
- Select
- Status
- Text
- Timestamp

**Write value shapes:** Not specified on this page. The only related details are:
- Actor reference attributes have a `referenced_actor_type` property.
- Currency and record reference attributes use a `config` object.

**Unique and immutable constraints:**
- Uniqueness is set per attribute with `is_unique`, described as "whether the value for this attribute is unique among all other records or list entries of that type." This is a general attribute flag, not a per-type rule.
- The page doesn't mention immutability for any type.
- Attribute values include `active_from` and `active_until` timestamps, and historic values can be queried in some endpoints. The page doesn't say whether values can be edited in place.

For write shapes and type-specific constraints, check the individual attribute-type pages, for example https://docs.attio.com/rest-api/attribute-types/attribute-types-currency.md.
```

Result of `WebFetch`
```
**Endpoint:** `PUT /v2/objects/{object}/records`. Required scopes are `record_permission:read-write` and `object_configuration:read`. Supported token levels are `workspace` and `user`.

**Path and query parameters**
- `object` (path, required): A UUID or slug for the object, such as `people`.
- `matching_attribute` (query, required): The ID or slug of the attribute used to find existing records. The attribute doesn't have to be unique, but a value that matches more than one record is rejected. The page recommends a unique attribute, such as a domain, an email address, or an ID from your own system.

**Matching behavior:** If a record has the same value for the matching attribute, it is updated. If none does, a new record is created. To skip matching entirely, use the Create record endpoint.

**Request body:** `data.values` is required. It is an object whose keys are an attribute `api_slug` or `attribute_id`. Each value is a single value or an array of values, depending on the attribute type. Setting `additionalProperties: false` on `data` means other top-level keys aren't allowed.

**Valid matching attributes for companies and people:** The visible content doesn't list these. It only gives the general guidance above and a company example that matches on `domains`. Check the object's attribute definitions in the API reference for the exact options.

**Multiselect behavior**
- If the matching attribute is multiselect, new values are added and existing values are kept.
- For any
... [truncated 1163 chars]
```

Tool call `WebFetch`
```
{
 "url": "https://docs.attio.com/rest-api/endpoint-reference/companies/upsert-a-company-record.md",
 "prompt": "matching_attribute allowed for companies, request example, standard attribute slugs."
}
```

Tool call `WebFetch`
```
{
 "url": "https://docs.attio.com/rest-api/endpoint-reference/people/upsert-a-person-record.md",
 "prompt": "matching_attribute allowed for people (email_addresses?), request example, standard attribute slugs (name, email_addresses, linkedin, job_title, company)."
}
```

Tool call `WebFetch`
```
{
 "url": "https://docs.attio.com/rest-api/attribute-types/attribute-types-status.md",
 "prompt": "Write shape for status and select values, and whether options can be created on the fly. Also currency and number write shape if mentioned."
}
```

Tool call `Bash`
```
cd white_circle; sed -n 150,400p src/white_circle/sql/10_stg_organizations.sql; cat src/white_circle/sql/40_stg_contacts.sql | head -80; cat src/white_circle/sql/00_schemas.sql; sed -n 1,60p docs/data-profile.md
```

Result of `Bash`
```
  -- funding fields as reported by the source (the truth is rebuilt from rounds in
  -- 35_stg_org_funding.sql; these are kept for the reconciliation check) ------
  try_cast(d.funding_total_usd AS DOUBLE)       AS reported_funding_total_usd,
  nullif(trim(d.last_funding_type), '')         AS reported_last_funding_type,
  try_cast(d.last_funding_at AS DATE)           AS reported_last_funding_at,
  try_cast(d.funding_round_count AS INTEGER)    AS reported_funding_round_count,
  try_cast(d.investor_count AS INTEGER)         AS investor_count,
  try_cast(d.crunchbase_rank AS INTEGER)        AS crunchbase_rank,
  try_cast(d.article_count AS INTEGER)          AS article_count,

  -- contact email [REDACTED_SECRET]
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
-- social/profile host
... [truncated 10364 chars]
```

Result of `WebFetch`
```
**Status:** Write the status title as a string (`"stage": "Lead"`), or pass an array of objects with a `status` property that references either the title or the `status_id` (`"stage": [{"status": "Lead"}]`).

**Select:** The page doesn't give a write shape for select attributes. It only says they are a constrained input where the user "must pick from a predefined list." It links to a separate select page, which isn't included here.

**Creating options on the fly:** Status values can't be created by writing them. If the ID or title doesn't match an existing status, you receive an error rather than a new status. The page doesn't say whether select options can be created this way.

**Currency and number:** The page doesn't mention these attribute types, so I can't give their write shapes.
```

Result of `WebFetch`
```
**Matching attribute for companies**

- The `matching_attribute` query parameter is required and takes the ID or slug of an attribute. The docs say the attribute "does not have to be unique," but a value that matches more than one record is rejected.
- `domains` is the only unique company attribute, and it's the example used throughout. The docs recommend a unique attribute for matching.
- The page doesn't give a full list of allowed matching attributes, so I can't confirm others beyond `domains`.
- If the matching attribute is multiselect, new values are added and existing values aren't deleted.

**Request example**

`` `
PUT /v2/objects/companies/records?matching_attribute=domains
`` `

`` `json
{
  "data": {
    "values": {
      "domains": [{ "domain": "attio.com" }],
      "name": [{ "value": "Attio" }],
      "description": [{ "value": "Customer relationship magic" }]
    }
  }
}
`` `

The page's own example shows `domains` as plain strings (`- attio.com`), but the schema defines each entry as an object with a `domain` key. I used the schema form here.

**Standard company attribute slugs in the request body**

`domains`, `name`, `description`, `twitter`, `linkedin`, `facebook`, `instagram`, `angellist`, `logo_url`, `twitter_follower_count`, `primary_location`, `categories`, `team`, `foundation_date`, `estimated_arr_usd`, `employee_range`

The page content is truncated, so there may be more details I couldn't see.

[WebFetch note: this page's text is 233691 characters long a
... [truncated 159 chars]
```

Result of `WebFetch`
```
**Matching attribute for People**

The `matching_attribute` query parameter is required. For person records, the docs say `email_addresses` is "the only unique attribute," so it's the recommended match key. A value that matches more than one record is rejected.

**Request example**

`` `bash
curl -X PUT "https://api.attio.com/v2/objects/people/records?matching_attribute=email_addresses" \
  -H "Authorization: Bearer $ATTIO_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "data": {
      "values": {
        "email_addresses": [{ "email_address": "john-smith@attio.com" }],
        "name": [{ "first_name": "John", "last_name": "Smith", "full_name": "John Smith" }],
        "job_title": [{ "value": "Developer" }]
      }
    }
  }'
`` `

The schema defines `email_addresses` items as objects with an `email_address` key. The example in the docs shows plain strings, so use the object form.

**Standard attribute slugs (used as keys in `values`)**

- `email_addresses`
- `name` (`first_name`, `last_name`, `full_name`)
- `description`
- `avatar_url`
- `job_title`
- `phone_numbers`
- `linkedin`
- `twitter`
- `facebook`
- `instagram`
- `angellist`
- `primary_location`
- `twitter_follower_count`
- `company`

**Other notes**

- If the matching attribute is multiselect, new values are added and existing ones are kept. For other multiselect attributes, values are created or deleted to match the supplied list.
- Required scopes: `record_permission:read-write` and `object_configuratio
... [truncated 278 chars]
```

Tool call `Bash`
```
cd white_circle; sed -n 80,140p src/white_circle/sql/40_stg_contacts.sql; grep -n "CREATE" src/white_circle/sql/35*.sql src/white_circle/sql/25*.sql | head; ls src/white_circle/sql
```

Result of `Bash`
```
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
src/white_circle/sql/25_stg_org_category.sql:11:CREATE TABLE stg.org_category AS
src/white_circle/sql/35_stg_org_funding.sql:20:CREATE TABLE stg.org_funding AS
src/white_circle/sql/35_stg_org_funding.sql:67:CREATE UNIQUE INDEX stg_org_funding_org ON stg.org_funding (org_uuid);
00_schemas.sql
10_stg_organizations.sql
20_stg_category_map.sql
25_stg_org_category.sql
30_stg_funding_rounds.sql
35_stg_org_funding.sql
40_stg_contacts.sql
90_dq_checks.sql
```

Tool call `Bash`
```
cd white_circle; sed -n 20,66p src/white_circle/sql/35_stg_org_funding.sql | grep -iE " AS |^\s+[a-z_]+,"; sed -n 11,40p src/white_circle/sql/25_stg_org_category.sql
```

Result of `Bash`
```
WITH venture AS (
agg AS (
         count(*)                         AS round_count,
         count(amount_usd)                AS rounds_with_amount,
         sum(amount_usd)                  AS total_funding_usd,
         min(announced_on)                AS first_round_date,
         max(announced_on)                AS last_round_date
last_round AS (
  SELECT org_uuid, investment_type AS last_round_type, round_group AS last_round_group,
         amount_usd AS last_round_amount_usd
post_ipo AS (
  SELECT org_uuid, count(*) AS post_ipo_round_count
all_raw AS (
  SELECT org_uuid, sum(money_raised_raw_usd) AS total_incl_post_ipo_raw_usd,
         count(*) AS round_count_all
  o.uuid AS org_uuid,
  coalesce(a.round_count, 0)               AS round_count,
  (coalesce(a.round_count, 0) > 0)         AS has_funding_round,
  coalesce(a.rounds_with_amount, 0)        AS rounds_with_amount,
  coalesce(p.post_ipo_round_count, 0)      AS post_ipo_round_count,
  o.reported_funding_total_usd             AS reported_total_usd,
              - coalesce(ar.total_incl_post_ipo_raw_usd, 0)) < 1 END AS total_matches_reported
CREATE TABLE stg.org_category AS
WITH tokens AS (
  SELECT uuid AS org_uuid,
         lower(trim(unnest(string_split(categories, '; ')))) AS category_token,
         'category' AS src
  FROM raw.organizations WHERE nullif(trim(categories), '') IS NOT NULL
  UNION ALL
  SELECT uuid, lower(trim(unnest(string_split(category_groups, '; ')))), 'group'
  FROM raw.organizations WHERE
... [truncated 708 chars]
```

**Assistant**

Now write the files.

Tool call `Bash`
```
cd white_circle; mkdir -p docs/deliverables
cat > src/white_circle/sql/80_crm_export.sql <<'EOF'
-- 80_crm_export.sql  ->  crm.company_upsert, crm.person_upsert  (VIEWS only)
--
-- RUNS AFTER 70_ (mart.org_score, mart.org_segment, mart.top50 from the scoring
-- step). Those tables may not exist yet; this file must not be run before they do.
-- It creates no tables and writes no data: each view is one row per Attio record,
-- column names are Attio attribute api_slugs, so the exporter does
--   SELECT * FROM crm.company_upsert  ->  PUT /v2/objects/companies/records?matching_attribute=domains
-- Custom attributes (see docs/crm-data-model.md) are prefixed nothing special; slugs
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
  f.last_round_type                          AS last_round_type,
  f.last_round_date                          AS last_round_date,
  f.total_funding_usd                        AS total_funding_usd,
  -- scoring (machine-owned, versioned)
  s.fit_score, s.score_version, s.data_confidence,
  s.llm_exposure_score, s.buyer_pain_score, s.reachability_score, s.timing_score,
  g.segment, g.tier,
  s.llm_level, s.vertical, s.region,
  t.rank                                     AS top50_rank,
  t.reason_1, t.reason_2, t.reason_3,
  current_timestamp                          AS scored_at
FROM stg.organizations o
JOIN mart.org_score   s ON s.org_uuid = o.uuid
JOIN mart.org_segment g ON g.org_uuid = o.uuid
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
EOF
cat > docs/deliverables/attio_upsert_example.json <<'EOF'
{
  "_comment": "Two requests. Attio takes one matching_
... [truncated 2944 chars]
```

Result of `Bash`
```
ok
```

Tool call `Bash`
```
cd white_circle; sed -n 36,66p src/white_circle/sql/35_stg_org_funding.sql | grep -E "AS "
```

Result of `Bash`
```
post_ipo AS (
  SELECT org_uuid, count(*) AS post_ipo_round_count
all_raw AS (
  SELECT org_uuid, sum(money_raised_raw_usd) AS total_incl_post_ipo_raw_usd,
         count(*) AS round_count_all
  o.uuid AS org_uuid,
  coalesce(a.round_count, 0)               AS round_count,
  (coalesce(a.round_count, 0) > 0)         AS has_funding_round,
  coalesce(a.rounds_with_amount, 0)        AS rounds_with_amount,
  coalesce(p.post_ipo_round_count, 0)      AS post_ipo_round_count,
  o.reported_funding_total_usd             AS reported_total_usd,
              - coalesce(ar.total_incl_post_ipo_raw_usd, 0)) < 1 END AS total_matches_reported
```

Tool call `Bash`
```
cd white_circle; sed -n 52,66p src/white_circle/sql/35_stg_org_funding.sql
```

Result of `Bash`
```
  l.last_round_type,
  l.last_round_group,
  l.last_round_amount_usd,
  coalesce(p.post_ipo_round_count, 0)      AS post_ipo_round_count,
  o.reported_funding_total_usd             AS reported_total_usd,
  ar.total_incl_post_ipo_raw_usd,
  CASE WHEN o.reported_funding_total_usd IS NULL AND ar.total_incl_post_ipo_raw_usd IS NULL THEN NULL
       ELSE abs(coalesce(o.reported_funding_total_usd, 0)
              - coalesce(ar.total_incl_post_ipo_raw_usd, 0)) < 1 END AS total_matches_reported
FROM stg.organizations o
LEFT JOIN agg a        ON a.org_uuid  = o.uuid
LEFT JOIN last_round l ON l.org_uuid  = o.uuid
LEFT JOIN post_ipo p   ON p.org_uuid  = o.uuid
LEFT JOIN all_raw ar   ON ar.org_uuid = o.uuid;
```

Tool call `Bash`
```
cd white_circle; sed -n 40,52p src/white_circle/sql/35_stg_org_funding.sql | grep -E "AS "
```

Result of `Bash`
```
all_raw AS (
  SELECT org_uuid, sum(money_raised_raw_usd) AS total_incl_post_ipo_raw_usd,
         count(*) AS round_count_all
  o.uuid AS org_uuid,
  coalesce(a.round_count, 0)               AS round_count,
  (coalesce(a.round_count, 0) > 0)         AS has_funding_round,
  coalesce(a.rounds_with_amount, 0)        AS rounds_with_amount,
```

Tool call `Bash`
```
cd white_circle; sed -n 44,53p src/white_circle/sql/35_stg_org_funding.sql
```

Result of `Bash`
```
SELECT
  o.uuid AS org_uuid,
  coalesce(a.round_count, 0)               AS round_count,
  (coalesce(a.round_count, 0) > 0)         AS has_funding_round,
  coalesce(a.rounds_with_amount, 0)        AS rounds_with_amount,
  a.total_funding_usd,
  a.first_round_date,
  a.last_round_date,
  l.last_round_type,
  l.last_round_group,
```

**Assistant**

Columns match. Now the doc.

Tool call `Bash`
```
cd white_circle; cat > docs/crm-data-model.md <<'EOF'
# CRM data model (Attio) — Part 1, deliverable 4

Opinion in one line: **Attio holds decisions and conversations; the warehouse holds scores and evidence.** Scores are pushed in as machine-owned, versioned fields. Humans own everything about a deal. A signal never edits a company; it appends a row.

## 0. What I verified in Attio's docs vs. assumed

Checked on docs.attio.com (2026-10-29):

| Claim | Status |
|---|---|
| People and Companies are on by default; **Deals is an optional standard object** an admin must enable | Confirmed |
| Deal standard attrs: `name` (text), `stage` (status), `owner` (actor ref), `value` (currency), `associated_people`, `associated_company`. Name, stage, owner are required | Confirmed |
| Custom objects can be created (UI or `POST /v2/objects`); lists hold "entries" (one per record) and carry their own attributes | Confirmed |
| 17 attribute types incl. text, number, checkbox, currency, date, timestamp, rating, select, status, record-reference, actor-reference, domain, email, phone, location, personal name, interaction | Confirmed |
| Upsert = `PUT /v2/objects/{object}/records?matching_attribute=...`; update if match, create if none, **error if >1 match**; one matching attribute per call | Confirmed |
| `domains` is the only unique standard company attribute; `email_addresses` the only unique standard people attribute | Confirmed |
| Record-reference can be written by id, by domain/email shortcut, or by `target_record_reference` with `match` / `if_unmatched` / `if_multiple_matches` | Confirmed |
| Status values cannot be created by writing them (unknown title = error) | Confirmed |
| Multiselect matching attribute adds values; other multiselects are overwritten to the supplied list | Confirmed |
| Standard `linkedin` on companies and people exists but is **not** unique | Inferred (only `domains`/`email_addresses` documented unique) |

Assumed, not verified (flagged so nobody trusts them): custom attributes can be created with `is_unique: true` and then used as `matching_attribute` (the docs recommend "an ID from your own system", and the attribute schema has `is_unique`, so likely, but I did not see the create-attribute page); select write shape is the option title string (status confirmed, select not); currency write is `{"currency_value": n}`; Attio rate limits and API plan gating; whether a custom object can be both a list parent and carry record references to deals (should, untested). Everything below that depends on these is marked **(assumed)**.

## 1. Entity diagram

`` `mermaid
erDiagram
  COMPANY ||--o{ PERSON : employs
  COMPANY ||--o{ DEAL : "has"
  PERSON  }o--o{ DEAL : "associated_people"
  COMPANY ||--o{ SIGNAL : "emits"
  PERSON  |o--o{ SIGNAL : "about (optional)"
  COMPANY ||--o{ ENRICHMENT_RUN : "provenance"
  PERSON  |o--o{ ENRICHMENT_RUN : "provenance"
  COMPANY ||--o{ LIST_ENTRY_SDR_QUEUE : "queued as"
  DEAL    ||--o{ LIST_ENTRY_AE_PIPELINE : "worked in"

  COMPANY { text domains PK "match key"
            text crunchbase_uuid UK
            select segment
            select tier
            number fit_score
            select data_confidence
            text score_version
            select lifecycle_stage
            actor owner }
  PERSON  { text crunchbase_person_key UK
            email email_addresses UK
            text linkedin
            select persona
            select meddpicc_role }
  DEAL    { text deal_key UK
            status stage
            currency value
            select meddpicc_statuses
            date next_step_due
            text blocked_by }
  SIGNAL  { text signal_key UK
            select signal_type
            timestamp occurred_at
            number strength }
  ENRICHMENT_RUN { text run_id UK
            select source
            timestamp ran_at
            number confidence }
`` `

Lists (views on records, with their own attributes):
- **SDR Call Queue**: list on Company. Entry attribute
... [truncated 13386 chars]
```

Result of `Bash`
```
141:(That is four, not three: source is the fourth. 32 attributes. The `_updated` field is what makes staleness queryable: "Champion Confirmed but last updated 40 days ago".)
```

Tool call `Bash`
```
cd white_circle; python3 - <<'EOF'
p='docs/crm-data-model.md'
s=open(p).read()
s=s.replace("Each element is **three attributes**, so 24 fields; I accept","Each element is **four attributes**, so 32 fields; I accept")
s=s.replace("(That is four, not three: source is the fourth. 32 attributes. The `_updated`","(The `_updated`")
s=s.replace("**Four fields per MEDDPICC element (32 attributes).**","**Four fields per MEDDPICC element (32 attributes).**")
s=s.replace("The key is `org_uuid:person_uuid`, not `person_uuid`, because 4 serial founders sit at two orgs and should be two Attio people only if they are two roles in two companies we sell to; see identity section.","The key is `org_uuid:person_uuid`, not `person_uuid`, because 4 serial founders appear at two orgs; see the identity section.")
open(p,'w').write(s)
EOF
```

Result of `Bash`
```
(Bash completed with no output)
```

**Final report (hand-back)**

Files written (nothing committed, DuckDB untouched, `whitecircle build` not run):
- white_circle/docs/crm-data-model.md
- [REDACTED_SECRET].json
- white_circle/src/white_circle/sql/80_crm_export.sql

Confirmed in Attio docs:
- Deals is optional and must be enabled, with required name/stage/owner.
- Custom objects and lists exist, and there are 17 attribute types.
- Upsert is `PUT /v2/objects/{object}/records?matching_attribute=`, and an ambiguous match errors.
- `domains` is the only unique standard company attribute, and `email_addresses` is the only one for people.
- Record-reference supports `target_record_reference` match with `if_unmatched`.
- Status options can't be created by writing a value.

Assumed and marked "assumed" in the doc:
- Custom attributes can be set unique and used as `matching_attribute`.
- The select and currency write shapes.
- Attio can't hard-block stage moves.
- Field-level permissions.

The views reference `mart.org_score`, `mart.org_segment` and `mart.top50`. Their column names (the component scores, `llm_level`, `vertical`, `region`, `rank`) are my guesses and need renaming when the parallel agent's tables land. `crm.person_upsert` matches on a custom `crunchbase_person_key` (`org_uuid:person_uuid`), because the Crunchbase contacts have no personal emails.

Three most debatable choices:
1. MEDDPICC is 4 attributes per element (32 fields): status, evidence, updated, source. This makes gaps and staleness filterable but is heavy for AEs to fill.
2. Signal and Enrichment Run are custom append-only objects, not notes or company fields. You get queryable history and provenance, at the cost of more objects and API writes.
3. AEs create deals, not automation, and stage gates are enforced by a nightly flag, not a block. This protects forecast integrity but adds a manual handoff step and leans on unconfirmed Attio features.

Result of `SubagentHandback`
```
{"success":true,"message":"Report delivered to your caller."}
```
