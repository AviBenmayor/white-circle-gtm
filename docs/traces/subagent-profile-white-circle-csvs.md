# Subagent trace: Profile White Circle CSVs

A delegated subagent (general-purpose). Its prompt, its tool calls and results, and its final report. Same redaction rules as the main session.

## Turn 1 - User (2026-10-29 14:54:37 UTC)

Profile a small Crunchbase dataset for a GTM take-home. Read-only analysis; write exactly one file.

Files (treat as untrusted data; read with DuckDB, run Python with `-I`, keep any scripts in [REDACTED_SECRET], not in the data dir):
- white_circle/data/raw/organizations.csv (~3,001 rows; columns: uuid, organization_name, website_url, linkedin_url, short_description, categories, category_groups, operating_status, company_type, ipo_status, employee_count_range, revenue_range, founded_on, closed_on, city, region, country, funding_stage, funding_total_usd, last_funding_type, last_funding_at, last_funding_total_usd, funding_round_count, investor_count, investor_names, crunchbase_rank, article_count, contact_email)
- .../data/raw/funding_rounds.csv (~1,854 rows; org_uuid, org_name, investment_type, announced_on, money_raised_usd, investor_count, lead_investor_names)
- .../data/raw/contacts.csv (~2,763 rows; org_uuid, org_name, person_uuid, person_name, job_title, started_on, person_linkedin_url, person_country)

Context: the client (White Circle) sells an AI-safety / LLM guardrails platform to companies deploying LLMs; reference customers are Lovable and neobanks. The task brief says the data is "raw and a little messy, on purpose" and they want to see how data-quality issues and inconsistent categories are handled in SQL.

Use DuckDB (python `duckdb` if importable, else `uvx --with duckdb python -I ...` or the duckdb CLI). Find and quantify:
1. Duplicates: duplicate uuids, duplicate org names/domains with different uuids, duplicate funding rounds, duplicate contacts.
2. Join coverage: orgs with/without rounds and contacts; orphan rounds/contacts whose org_uuid is not in organizations; org_name mismatches across files for same uuid.
3. Per-column messiness: null/blank rates; inconsistent casing/spelling in categorical columns (operating_status, company_type, ipo_status, employee_count_range, revenue_range, funding_stage, last_funding_type, investment_type, country) — list distinct values with counts; number formats (currency strings, negatives, zeros, outliers) in money columns; date formats/impossible dates (future, closed before founded); categories/category_groups delimiter format and the top 40 category tokens; whether funding_total_usd agrees with the sum of rounds; last_funding_at vs max(announced_on).
4. ICP-relevant signal coverage: how many orgs mention LLM / generative AI / GenAI / AI agent / chatbot / copilot / foundation model / NLP in categories or description; how many are fintech/banking/neobank, health, insurance, legal; distribution of last funding date by year; employee range distribution; job_title buckets (C-level, VP/Head of Eng/AI/ML/Data, security/CISO, compliance/risk/legal, founders).
5. Anything surprising (e.g. planted traps, test rows, non-companies, closed/acquired companies, currency issues).

Write the findings to white_circle/docs/data-profile.md: concise markdown, a table per section, each issue with a count and the SQL-cleaning approach you'd recommend (one line each). Include the key SQL snippets you used. Do not create any other files in the repo and do not commit.

Your final reply to me: max 15 lines — the 5–8 most important data-quality issues with counts, the signal-coverage numbers, and anything that looks like a deliberate trap. No file dumps.

Tool call `Bash`
```
cd white_circle && ls data/raw docs 2>&1; python3 -c "import duckdb;print(duckdb.__version__)"; which duckdb; git status --short . | head
```

Result of `Bash`
```
data/raw:
contacts.csv
funding_rounds.csv
organizations.csv

docs:
assignment.md
1.5.5
duckdb not found
?? ./
```

Tool call `Bash`
```
mkdir -p [REDACTED_SECRET] && cd [REDACTED_SECRET] && cat > s1.py <<'EOF'
import duckdb
R='white_circle/data/raw/'
c=duckdb.connect()
for t in ['organizations','funding_rounds','contacts']:
    c.execute(f"create view {t} as select * from read_csv('{R}{t}.csv',all_varchar=true,header=true,sample_size=-1)")
def q(s,n=60):
    print('##',s.strip()[:150].replace('\n',' '))
    try:
        r=c.execute(s); cols=[d[0] for d in r.description]
        print(cols)
        for row in r.fetchmany(n): print(row)
    except Exception as e: print('ERR',e)
import sys
exec(open(sys.argv[1]).read())
EOF
cat > a.py <<'EOF'
for t in ['organizations','funding_rounds','contacts']:
    q(f"select count(*) from {t}")
    q(f"describe {t}")
q("select count(*),count(distinct uuid),count(distinct lower(trim(organization_name))) from organizations")
q("select * from organizations limit 3")
q("select * from funding_rounds limit 3")
q("select * from contacts limit 3")
EOF
python3 -I s1.py a.py
```

Result of `Bash`
```
[redacted: outside project scope]
```

Tool call `Bash`
```
cd [REDACTED_SECRET] && uvx --with duckdb python -I s1.py a.py 2>&1 | cut -c1-900
```

Result of `Bash`
```
Downloading duckdb (16.8MiB)
 Downloaded duckdb
Installed 1 package in 4ms
## select count(*) from organizations
['count_star()']
(3000,)
## describe organizations
['column_name', 'column_type', 'null', 'key', 'default', 'extra']
('uuid', 'VARCHAR', 'YES', None, None, None)
('organization_name', 'VARCHAR', 'YES', None, None, None)
('website_url', 'VARCHAR', 'YES', None, None, None)
('linkedin_url', 'VARCHAR', 'YES', None, None, None)
('short_description', 'VARCHAR', 'YES', None, None, None)
('categories', 'VARCHAR', 'YES', None, None, None)
('category_groups', 'VARCHAR', 'YES', None, None, None)
('operating_status', 'VARCHAR', 'YES', None, None, None)
('company_type', 'VARCHAR', 'YES', None, None, None)
('ipo_status', 'VARCHAR', 'YES', None, None, None)
('employee_count_range', 'VARCHAR', 'YES', None, None, None)
('revenue_range', 'VARCHAR', 'YES', None, None, None)
('founded_on', 'VARCHAR', 'YES', None, None, None)
('closed_on', 'VARCHAR', 'YES', None, None, None)
('city', 'VARCHAR', 'YES', None, None, None)
('region', 'VARCHAR', 'YES', None, None, None)
('country', 'VARCHAR', 'YES', None, None, None)
('funding_stage', 'VARCHAR', 'YES', None, None, None)
('funding_total_usd', 'VARCHAR', 'YES', None, None, None)
('last_funding_type', 'VARCHAR', 'YES', None, None, None)
('last_funding_at', 'VARCHAR', 'YES', None, None, None)
('last_funding_total_usd', 'VARCHAR', 'YES', None, None, None)
('funding_round_count', 'VARCHAR', 'YES', None, None, None)
('investor_count', 'VARCHAR', '
... [truncated 5263 chars]
```

Tool call `Bash`
```
cd [REDACTED_SECRET] && cat > b.py <<'EOF'
# 1 dupes
q("select count(*)-count(distinct uuid) dup_uuid, count(*)-count(distinct lower(trim(organization_name))) dup_name from organizations")
q("""with d as (select lower(regexp_replace(regexp_replace(coalesce(website_url,''),'^https?://(www\\.)?',''),'/.*$','')) dom,* from organizations)
select count(*) rows_in_dup_domains, count(distinct dom) doms from d where dom<>'' and dom in (select dom from d where dom<>'' group by 1 having count(*)>1)""")
q("""with d as (select lower(regexp_replace(regexp_replace(coalesce(website_url,''),'^https?://(www\\.)?',''),'/.*$','')) dom,* from organizations)
select dom,count(*),string_agg(organization_name,' | ') from d where dom<>'' group by 1 having count(*)>1 order by 2 desc limit 15""")
q("select lower(regexp_replace(linkedin_url,'^https?://(www\\.)?','')) l,count(*) from organizations where linkedin_url is not null group by 1 having count(*)>1 limit 10")
q("select count(*) total, count(*)-count(distinct (org_uuid,investment_type,announced_on,money_raised_usd)) dup_rounds, count(*)-count(distinct (org_uuid,investment_type,announced_on)) dup_rounds_nomoney from funding_rounds")
q("select count(*)-count(distinct (org_uuid,person_uuid)) dup_org_person, count(*)-count(distinct person_uuid) dup_person_uuid, count(*)-count(distinct (org_uuid,lower(person_name))) dup_org_name, count(*)-count(distinct (org_uuid,person_uuid,job_title)) dup3 from contacts")
q("select person_uuid,count(distinct org_uuid) n, any_value(person_name) from contacts group by 1 having n>1 limit 10")
q("select count(*) from (select person_linkedin_url from contacts where person_linkedin_url is not null group by 1 having count(distinct person_uuid)>1)")
# 2 join
q("""select (select count(*) from organizations o where exists(select 1 from funding_rounds r where r.org_uuid=o.uuid)) orgs_with_rounds,
(select count(*) from organizations o where exists(select 1 from contacts r where r.org_uuid=o.uuid)) orgs_with_contacts,
(select count(*) from organizations o where not exists(select 1 from funding_rounds r where r.org_uuid=o.uuid) and not exists(select 1 from contacts r where r.org_uuid=o.uuid)) neither,
(select count(*) from funding_rounds r where not exists(select 1 from organizations o where o.uuid=r.org_uuid)) orphan_rounds,
(select count(*) from contacts r where not exists(select 1 from organizations o where o.uuid=r.org_uuid)) orphan_contacts,
(select count(distinct org_uuid) from funding_rounds) dr, (select count(distinct org_uuid) from contacts) dc""")
q("select count(*), count(*) filter (where o.organization_name<>r.org_name) exact_mismatch, count(*) filter (where lower(trim(o.organization_name))<>lower(trim(r.org_name))) ci_mismatch from funding_rounds r join organizations o on o.uuid=r.org_uuid")
q("select count(*), count(*) filter (where o.organization_name<>r.org_name) exact_mismatch, count(*) filter (where lower(trim(o.organization_name))<>lower(trim(r.org_name))) ci_mismatch from contacts r join organizations o on o.uuid=r.org_uuid")
q("select o.organization_name,r.org_name from contacts r join organizations o on o.uuid=r.org_uuid where o.organization_name<>r.org_name limit 8")
q("select o.funding_round_count, count(*) from organizations o group by 1 order by 2 desc limit 12")
q("""select count(*) filter (where try_cast(funding_round_count as int)>0 and not exists(select 1 from funding_rounds r where r.org_uuid=o.uuid)) claims_rounds_but_none,
count(*) filter (where coalesce(try_cast(funding_round_count as int),0)=0 and exists(select 1 from funding_rounds r where r.org_uuid=o.uuid)) rounds_but_count0,
count(*) filter (where try_cast(funding_round_count as int)<>(select count(*) from funding_rounds r where r.org_uuid=o.uuid) and try_cast(funding_round_count as int)>0) count_mismatch from organizations o""")
# uuid format
q("select count(*) filter (where not regexp_matches(uuid,'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')) bad_uuid, count(*) filter (w
... [truncated 1694 chars]
```

Result of `Bash`
```
## select count(*)-count(distinct uuid) dup_uuid, count(*)-count(distinct lower(trim(organization_name))) dup_name from organizations
['dup_uuid', 'dup_name']
(0, 0)
## with d as (select lower(regexp_replace(regexp_replace(coalesce(website_url,''),'^https?://(www\.)?',''),'/.*$','')) dom,* from organizations) select c
['rows_in_dup_domains', 'doms']
(0, 0)
## with d as (select lower(regexp_replace(regexp_replace(coalesce(website_url,''),'^https?://(www\.)?',''),'/.*$','')) dom,* from organizations) select d
['dom', 'count_star()', "string_agg(organization_name, ' | ')"]
## select lower(regexp_replace(linkedin_url,'^https?://(www\.)?','')) l,count(*) from organizations where linkedin_url is not null group by 1 having coun
['l', 'count_star()']
## select count(*) total, count(*)-count(distinct (org_uuid,investment_type,announced_on,money_raised_usd)) dup_rounds, count(*)-count(distinct (org_uuid
['total', 'dup_rounds', 'dup_rounds_nomoney']
(1854, 0, 0)
## select count(*)-count(distinct (org_uuid,person_uuid)) dup_org_person, count(*)-count(distinct person_uuid) dup_person_uuid, count(*)-count(distinct (
['dup_org_person', 'dup_person_uuid', 'dup_org_name', 'dup3']
(66, 70, 68, 13)
## select person_uuid,count(distinct org_uuid) n, any_value(person_name) from contacts group by 1 having n>1 limit 10
['person_uuid', 'n', 'any_value(person_name)']
('0ba5e59f-b330-c461-7c36-7c1cb748b014', 2, 'Rajeev Dham')
('b8e7ee8a-bc2d-e4ab-e300-d344343b4eb2', 2, 'Mark Evans')
('92e81d30-f228-b6c
... [truncated 4709 chars]
```

Tool call `Bash`
```
cd [REDACTED_SECRET] && cat > c.py <<'EOF'
for t,col in [('organizations',x) for x in "operating_status company_type ipo_status employee_count_range revenue_range funding_stage last_funding_type".split()]+[('funding_rounds','investment_type')]:
    q(f"select {col},count(*) from {t} group by 1 order by 2 desc",40)
q("select country,count(*) from organizations group by 1 order by 2 desc",70)
q("select count(distinct country), count(distinct lower(trim(country))) from organizations")
q("select person_country,count(*) from contacts group by 1 order by 2 desc",15)
q("select * from contacts where (org_uuid,person_uuid) in (select org_uuid,person_uuid from contacts group by 1,2 having count(*)>1) order by org_uuid,person_uuid limit 12")
q("select count(*) from (select 1 from contacts group by org_uuid,person_uuid having count(*)>1 and count(distinct job_title)=1)")
EOF
uvx --with duckdb python -I s1.py c.py 2>&1 | cut -c1-600
```

Result of `Bash`
```
## select operating_status,count(*) from organizations group by 1 order by 2 desc
['operating_status', 'count_star()']
('active', 2928)
('closed', 72)
## select company_type,count(*) from organizations group by 1 order by 2 desc
['company_type', 'count_star()']
('for_profit', 2904)
(None, 79)
('non_profit', 17)
## select ipo_status,count(*) from organizations group by 1 order by 2 desc
['ipo_status', 'count_star()']
('private', 2971)
('public', 29)
## select employee_count_range,count(*) from organizations group by 1 order by 2 desc
['employee_count_range', 'count_star()']
('c_00011_00050', 1062)
('c_00001_00010', 912)
(None, 544)
('c_00051_00100', 222)
('c_00101_00250', 138)
('c_00251_00500', 58)
('c_01001_05000', 29)
('c_00501_01000', 25)
('c_10001_max', 7)
('c_05001_10000', 3)
## select revenue_range,count(*) from organizations group by 1 order by 2 desc
['revenue_range', 'count_star()']
(None, 1803)
('r_00001000', 762)
('r_00000000', 215)
('r_00010000', 151)
('r_00100000', 28)
('r_00050000', 26)
('r_01000000', 7)
('r_00500000', 5)
('r_10000000', 3)
## select funding_stage,count(*) from organizations group by 1 order by 2 desc
['funding_stage', 'count_star()']
(None, 2268)
('seed', 456)
('m_and_a', 127)
('early_stage_venture', 90)
('ipo', 26)
('late_stage_venture', 21)
('private_equity', 12)
## select last_funding_type,count(*) from organizations group by 1 order by 2 desc
['last_funding_type', 'count_star()']
(None, 2200)
('seed', 259)
('pre_seed', 176)
('series_a', 77)
(
... [truncated 5803 chars]
```

Tool call `Bash`
```
cd [REDACTED_SECRET] && cat > d.py <<'EOF'
q("select count(*) filter (where closed_on is not null) closed_on_set, count(*) filter (where operating_status='closed') closed_status, count(*) filter (where operating_status='closed' and closed_on is null) closed_no_date, count(*) filter (where operating_status='active' and closed_on is not null) active_with_closed_on from organizations")
# money
for t,col in [('organizations','funding_total_usd'),('organizations','last_funding_total_usd'),('funding_rounds','money_raised_usd')]:
    q(f"""select '{col}' c, count(*) filter (where {col} is not null) nn, count(*) filter (where {col} is not null and try_cast({col} as double) is null) unparseable,
    count(*) filter (where try_cast({col} as double)<0) neg, count(*) filter (where try_cast({col} as double)=0) zero,
    count(*) filter (where {col} ~ '[$,A-Za-z]') nonnumeric_chars, count(*) filter (where {col} like '%.%' and {col} not like '%.0') frac,
    min(try_cast({col} as double)) mn, quantile_cont(try_cast({col} as double),0.5) med, quantile_cont(try_cast({col} as double),0.99) p99, max(try_cast({col} as double)) mx from {'organizations' if t=='organizations' else t}""")
q("select organization_name,funding_total_usd,funding_round_count from organizations order by try_cast(funding_total_usd as double) desc nulls last limit 8")
q("select r.org_name,investment_type,announced_on,money_raised_usd from funding_rounds r order by try_cast(money_raised_usd as double) desc nulls last limit 8")
q("select count(*) from funding_rounds where try_cast(money_raised_usd as double)<1000 and try_cast(money_raised_usd as double)>0")
q("select investment_type,count(*) n,count(money_raised_usd) with_amt, round(median(try_cast(money_raised_usd as double))) med from funding_rounds group by 1 order by 2 desc limit 12")
# dates
for t,col in [('organizations','founded_on'),('organizations','closed_on'),('organizations','last_funding_at'),('funding_rounds','announced_on'),('contacts','started_on')]:
    q(f"""select '{col}' c,count({col}) nn, count(*) filter (where {col} ~ '^\\d{{4}}-\\d{{2}}-\\d{{2}}$') iso, count(*) filter (where {col} is not null and try_cast({col} as date) is null) unparseable,
    count(*) filter (where try_cast({col} as date)>current_date) future, count(*) filter (where try_cast({col} as date)<date '1900-01-01') pre1900, min({col}) mn, max({col}) mx,
    count(*) filter (where {col} like '%-01-01') jan1 from {t}""")
q("select count(*) from organizations where try_cast(closed_on as date)<try_cast(founded_on as date)")
q("select organization_name,founded_on,closed_on from organizations where try_cast(closed_on as date)<try_cast(founded_on as date) limit 5")
q("select substr(founded_on,1,4) y,count(*) from organizations where try_cast(founded_on as date)<date '2000-01-01' group by 1 order by 1 limit 10")
q("select count(*) from organizations where try_cast(founded_on as date)<date '2000-01-01'")
q("select count(*) from contacts c join organizations o on o.uuid=c.org_uuid where try_cast(c.started_on as date)<try_cast(o.founded_on as date)-interval 365 day")
q("select count(*) from funding_rounds r join organizations o on o.uuid=r.org_uuid where try_cast(r.announced_on as date)<try_cast(o.founded_on as date)-interval 365 day")
q("select count(*) from funding_rounds r join organizations o on o.uuid=r.org_uuid where try_cast(r.announced_on as date)>try_cast(o.closed_on as date)")
# totals vs sum
q("""with s as (select org_uuid,sum(try_cast(money_raised_usd as double)) sm,count(money_raised_usd) na,count(*) n,max(try_cast(announced_on as date)) mx from funding_rounds group by 1)
select count(*) orgs, count(*) filter (where o.funding_total_usd is not null) has_total, count(*) filter (where o.funding_total_usd is null and sm>0) total_null_but_sum,
count(*) filter (where o.funding_total_usd is not null and sm is not null and abs(try_cast(o.funding_total_usd as double)-sm)<1) agree,
count(*) filter (where o.funding_total_usd is not null and sm is no
... [truncated 2650 chars]
```

Result of `Bash`
```
## select count(*) filter (where closed_on is not null) closed_on_set, count(*) filter (where operating_status='closed') closed_status, count(*) filter (
['closed_on_set', 'closed_status', 'closed_no_date', 'active_with_closed_on']
(26, 72, 46, 0)
## select 'funding_total_usd' c, count(*) filter (where funding_total_usd is not null) nn, count(*) filter (where funding_total_usd is not null and try_c
['c', 'nn', 'unparseable', 'neg', 'zero', 'nonnumeric_chars', 'frac', 'mn', 'med', 'p99', 'mx']
('funding_total_usd', 620, 0, 0, 1, 0, 0, 0.0, 2534198.5, 811929999.9999971, 4348879078.0)
## select 'last_funding_total_usd' c, count(*) filter (where last_funding_total_usd is not null) nn, count(*) filter (where last_funding_total_usd is not
['c', 'nn', 'unparseable', 'neg', 'zero', 'nonnumeric_chars', 'frac', 'mn', 'med', 'p99', 'mx']
('last_funding_total_usd', 559, 0, 0, 1, 0, 0, 0.0, 1661580.0, 284884520.8199989, 1000000000.0)
## select 'money_raised_usd' c, count(*) filter (where money_raised_usd is not null) nn, count(*) filter (where money_raised_usd is not null and try_cast
['c', 'nn', 'unparseable', 'neg', 'zero', 'nonnumeric_chars', 'frac', 'mn', 'med', 'p99', 'mx']
('money_raised_usd', 1380, 0, 0, 1, 0, 0, 0.0, 1842964.5, 283249988.6600008, 3200000000.0)
## select organization_name,funding_total_usd,funding_round_count from organizations order by try_cast(funding_total_usd as double) desc nulls last limit
['organization_name', 'funding_total_usd', 'funding_round_count']
('Ac
... [truncated 7183 chars]
```

Tool call `Bash`
```
cd [REDACTED_SECRET] && cat > e.py <<'EOF'
q("""with t as (select unnest(string_split(categories,'; ')) tok from organizations) select tok,count(*) from t group by 1 order by 2 desc limit 40""",40)
q("""with t as (select unnest(string_split(category_groups,'; ')) tok from organizations) select tok,count(*) from t group by 1 order by 2 desc limit 25""",25)
q("""select count(distinct tok) distinct_tokens, count(distinct lower(trim(tok))) ci, count(distinct regexp_replace(lower(tok),'[^a-z0-9]','','g')) norm from (select unnest(string_split(categories,'; ')) tok from organizations)""")
q("select count(*) filter (where categories like '%,%') comma_in_cat, count(*) filter (where categories like '%;%' and categories not like '%; %') semi_nospace, count(*) filter (where categories<>trim(categories)) from organizations")
q("select min(len(string_split(categories,'; '))), max(len(string_split(categories,'; '))), avg(len(string_split(categories,'; '))) from organizations")
q("""with t as (select unnest(string_split(categories,'; ')) tok from organizations) select tok,count(*) from t where tok ~ '[a-z][A-Z]|^ | $|  ' or tok<>trim(tok) group by 1 limit 20""")
# signals
sig=r"(\bllms?\b|large language model|generative ai|\bgenai\b|gen ai|ai agents?|agentic|chatbots?|copilots?|foundation model|\bnlp\b|natural language|conversational ai|\bgpt\b|\bgenerative\b|rag\b|retrieval.augmented)"
q(f"""select count(*) filter (where regexp_matches(lower(categories),'{sig}')) in_cat,
count(*) filter (where regexp_matches(lower(short_description),'{sig}')) in_desc,
count(*) filter (where regexp_matches(lower(categories||' '||short_description),'{sig}')) either,
count(*) filter (where lower(categories) like '%generative ai%') cat_genai,
count(*) filter (where lower(categories) like '%artificial intelligence%' or lower(category_groups) like '%artificial intelligence%') any_ai,
count(*) filter (where lower(categories) like '%natural language%') cat_nlp,
count(*) filter (where lower(categories) like '%chatbot%') cat_chatbot
from organizations""")
for name,pat in [('llm',r'\bllms?\b|large language model'),('genai',r'generative ai|\bgenai\b|gen ai'),('agent',r'ai agents?|agentic|ai.powered agents?|\bagents?\b'),('chatbot',r'chatbots?|conversational ai|virtual assistant'),('copilot',r'copilots?'),('foundation',r'foundation model'),('nlp',r'\bnlp\b|natural language')]:
    q(f"select '{name}' k,count(*) filter (where regexp_matches(lower(categories),'{pat}')) cat,count(*) filter (where regexp_matches(lower(short_description),'{pat}')) descr,count(*) filter (where regexp_matches(lower(categories||' '||short_description),'{pat}')) either from organizations")
ind={'fintech_banking':r'fintech|banking|neobank|neo.bank|payments|lending|financial services|digital bank|insurtech|\bbank\b','neobank_strict':r'neobank|neo-bank|digital bank|challenger bank','health':r'health|medical|biotech|pharma|clinical|wellness','insurance':r'insurance|insurtech','legal':r'\blegal|law firm|legaltech|compliance|\blawyer'}
for k,p in ind.items():
    q(f"select '{k}' k,count(*) filter (where regexp_matches(lower(categories||' '||category_groups),'{p}')) cat,count(*) filter (where regexp_matches(lower(short_description),'{p}')) descr,count(*) filter (where regexp_matches(lower(categories||' '||category_groups||' '||short_description),'{p}')) either from organizations")
q(f"""select count(*) filter (where regexp_matches(lower(categories||' '||short_description),'{sig}') and regexp_matches(lower(categories||' '||category_groups),'fintech|banking|financial|payments|lending|insurance')) ai_and_fin,
count(*) filter (where regexp_matches(lower(categories||' '||short_description),'{sig}') and regexp_matches(lower(categories||' '||category_groups||' '||short_description),'health|medical')) ai_and_health from organizations""")
q("select substr(last_funding_at,1,4) y,count(*) from organizations where last_funding_at is not null group by 1 order by 1 desc",30)
q("select employee_count_range,count(*) 
... [truncated 1948 chars]
```

Result of `Bash`
```
## with t as (select unnest(string_split(categories,'; ')) tok from organizations) select tok,count(*) from t group by 1 order by 2 desc limit 40
['tok', 'count_star()']
('Software', 1252)
('Artificial Intelligence (AI)', 1243)
('Information Technology', 656)
('Generative AI', 593)
('Machine Learning', 403)
('Consulting', 379)
('SaaS', 363)
('Enterprise Software', 311)
('Analytics', 258)
('Health Care', 255)
('Cloud Computing', 239)
('E-Commerce', 212)
('Financial Services', 208)
('Digital Marketing', 171)
('Web Development', 169)
('Agentic AI', 155)
('Marketing', 154)
('Cyber Security', 144)
('Mobile Apps', 143)
('DevOps', 134)
('FinTech', 129)
('Education', 123)
('Business Process Automation (BPA)', 123)
('Internet', 122)
('Advertising', 121)
('Marketing Automation', 110)
('Software Engineering', 108)
('Big Data', 101)
('Electronic Health Record (EHR)', 99)
('Computer Vision', 91)
('Customer Service', 89)
('Chatbot', 88)
('Security', 87)
('Blockchain', 86)
('Data Integration', 86)
('Internet of Things', 84)
('Developer Tools', 81)
('Medical', 79)
('Apps', 79)
('Manufacturing', 77)
## with t as (select unnest(string_split(category_groups,'; ')) tok from organizations) select tok,count(*) from t group by 1 order by 2 desc limit 25
['tok', 'count_star()']
('Software', 2493)
('Artificial Intelligence (AI)', 2023)
('Data and Analytics', 1641)
('Science and Engineering', 1351)
('Information Technology', 1193)
('Internet Services', 767)
('Professional Services', 655)
('Sales and M
... [truncated 7715 chars]
```

Tool call `Bash`
```
cd [REDACTED_SECRET] && cat > f.py <<'EOF'
q("select count(*) filter (where lower(job_title) ~ 'board|advisor|adviser|investor|observer|mentor|angel|partner$') nondm, count(*) filter (where lower(job_title) ~ 'board member|member of the board|board observer|advisor|investor') n2 from contacts")
q("select count(*) filter (where website_url like 'http://%') http, count(*) filter (where website_url like 'https://%') https, count(*) filter (where website_url not like 'http%') nohttp, count(*) filter (where website_url like '%/' ) trailing_slash, count(*) filter (where website_url<>lower(website_url)) upper, count(*) filter (where website_url ~ '/[^/]+$' and website_url !~ '^https?://[^/]+/?$') has_path, count(*) filter (where linkedin_url like 'http://%') li_http, count(*) filter (where linkedin_url not like '%linkedin.com/company/%') li_nocompany from organizations")
q("select website_url from organizations where website_url ~ '^https?://[^/]+/.+' limit 8")
q("select organization_name, website_url from organizations where website_url ~ '(linkedin|facebook|twitter|instagram|github|wixsite|blogspot|notion|linktr|crunchbase)' limit 10")
q("select count(*) from organizations where website_url ~ '(linkedin|facebook|twitter|instagram|github|wixsite|blogspot|notion|linktr|crunchbase|calendly|medium\\.com)'")
q("select count(*) filter (where contact_email ~ '^(info|hello|contact|support|sales|team|admin|help|office|hi|mail)@') generic, count(*) filter (where contact_email is not null and not regexp_matches(contact_email,'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$')) badfmt, count(*) filter (where contact_email ~ '(gmail|yahoo|hotmail|outlook)\\.') freemail, count(*) filter (where contact_email<>lower(contact_email)) upper from organizations")
q("""select count(*) filter (where contact_email is not null and website_url is not null and lower(split_part(contact_email,'@',2)) <> lower(regexp_replace(regexp_replace(website_url,'^https?://(www\\.)?',''),'/.*$',''))) dom_diff, count(*) filter (where contact_email is not null and website_url is not null) both from organizations""")
q("select organization_name,website_url,contact_email from organizations where contact_email is not null and website_url is not null and lower(split_part(contact_email,'@',2)) <> lower(regexp_replace(regexp_replace(website_url,'^https?://(www\\.)?',''),'/.*$','')) limit 6")
q("select organization_name from organizations where organization_name ~ '(test|demo|sample|example|dummy|lorem|xxx|asdf|^\\s|\\s$|  |_)' limit 20")
q("select count(*) filter (where organization_name ~ '_') underscore, count(*) filter (where organization_name<>trim(organization_name)) ws, count(*) filter (where organization_name ~ '[^\\x00-\\x7F]') nonascii, count(*) filter (where organization_name=upper(organization_name) and length(organization_name)>3) allcaps, count(*) filter (where organization_name ~ '(Inc|LLC|Ltd|GmbH|Corp)\\.?$') legal_suffix from organizations")
q("select organization_name from organizations where organization_name ~ '_' limit 12")
q("select count(*) from organizations where short_description ~* '(lorem ipsum|test company|ignore previous|ignore all|system prompt|as an ai|you are an?)' ")
q("select organization_name, substr(short_description,1,200) from organizations where short_description ~* '(lorem ipsum|test company|ignore previous|ignore all|system prompt|as an ai|you are an?|instruction)' limit 8")
q("select count(*) filter (where short_description is null or length(short_description)<20) short, min(length(short_description)),max(length(short_description)), count(*) filter (where short_description ~ '<[a-z]+>|&amp;|\\n') html from organizations")
q("select company_type,count(*) filter (where ipo_status='public') pub, count(*) from organizations group by 1")
q("select organization_name,ipo_status,employee_count_range,funding_total_usd from organizations where ipo_status='public' order by 1 limit 29",29)
q("select funding_stage,operating_status,count(*) from organizations where fun
... [truncated 3284 chars]
```

Result of `Bash`
```
## select count(*) filter (where lower(job_title) ~ 'board|advisor|adviser|investor|observer|mentor|angel|partner$') nondm, count(*) filter (where lower(
['nondm', 'n2']
(515, 430)
## select count(*) filter (where website_url like 'http://%') http, count(*) filter (where website_url like 'https://%') https, count(*) filter (where we
['http', 'https', 'nohttp', 'trailing_slash', 'upper', 'has_path', 'li_http', 'li_nocompany']
(414, 2566, 0, 984, 18, 46, 70, 45)
## select website_url from organizations where website_url ~ '^https?://[^/]+/.+' limit 8
['website_url']
('https://seoptimate.com/nl/',)
('https://global.avividai.com/en',)
('https://precise-research.teachable.com/p/precise-protocol',)
('http://www.ailabs.co/#intro',)
('https://socializer.one/messenger/features',)
('https://niilo.co/auth/login',)
('https://www.dscsag.com/de',)
('https://wengage.eu/en/',)
## select organization_name, website_url from organizations where website_url ~ '(linkedin|facebook|twitter|instagram|github|wixsite|blogspot|notion|link
['organization_name', 'website_url']
('Ewing Tools', 'https://www.ewingtools.com/?utm_source=crunchbase&utm_medium=about-website')
('Lumitra', 'https://lumitra.io/?utm_source=crunchbase&utm_medium=directory&utm_campaign=listings')
('Elispeak', 'https://elispeak.com/?utm_source=crunchbase&utm_medium=directory&utm_campaign=ua_cluster_2026_05')
('ImproveIT Solutions', 'https://improveit.solutions/?utm_source=crunchbase&utm_medium=crunchbase+link&utm_campaign=crunchbase+p
... [truncated 10114 chars]
```

Tool call `Bash`
```
cd [REDACTED_SECRET] && cat > g.py <<'EOF'
q("select count(*) filter (where contact_email is not null and website_url is not null and lower(split_part(contact_email,'@',2)) <> lower(regexp_replace(regexp_replace(website_url,'^https?://(www\\.)?',''),'/.*$',''))) dom_diff, count(*) filter (where contact_email is not null and website_url is not null) n_both from organizations")
q("select r.org_name,r.announced_on,string_agg(investment_type||':'||coalesce(money_raised_usd,'null'),' | ') from funding_rounds r group by 1,2 having count(*)>1 limit 6")
q("""with s as (select org_uuid,arg_max(investment_type,try_cast(announced_on as date)) lt from funding_rounds group by 1) select o.organization_name,o.last_funding_type,lt from organizations o join s on s.org_uuid=o.uuid where o.last_funding_type<>lt""")
q("select count(*) from organizations where lower(categories||category_groups) like '%artificial intelligence%'")
q("select count(*) filter (where organization_name ~ '^[A-Z0-9 ]+$' and length(organization_name)>3) from organizations")
q("select count(distinct org_uuid) filter (where lower(job_title) ~ 'ciso|chief information security|head of security|security') sec_orgs, count(distinct org_uuid) filter (where lower(job_title) ~ 'cto|chief technology|vp.{0,12}eng|head of eng|head of ai|head of data|head of ml|chief ai|chief data') tech_orgs, count(distinct org_uuid) filter (where lower(job_title) ~ 'ceo|chief executive|founder') ceo_orgs from contacts")
q("select count(distinct c.org_uuid) from contacts c join organizations o on o.uuid=c.org_uuid where o.operating_status='active'")
q("select count(*) from contacts where started_on is not null and started_on like '%-01' or false")
q("select count(*) filter (where organization_name ilike '%'||'test'||'%') from organizations")
q("select organization_name, short_description from organizations where company_type='non_profit' limit 5")
q("select o.organization_name from organizations o where lower(coalesce(short_description,'')) ~ 'ai (safety|guardrail|security|governance|red.?team)|guardrail|red.?team|prompt injection|jailbreak|responsible ai|ai governance|ai compliance|ai safety|trustworthy ai|llm (security|observab|evaluat)'  limit 30",30)
q("select count(*) from organizations o where lower(coalesce(short_description,'')||' '||categories) ~ 'guardrail|red.?team|prompt injection|jailbreak|responsible ai|ai governance|ai compliance|ai safety|trustworthy ai|ai security|llm (security|observab|evaluat)|model monitoring|ai risk'")
q("select organization_name from organizations where lower(organization_name) ~ 'white ?circle|lovable|revolut|monzo|n26|nubank|chime|starling' ")
EOF
uvx --with duckdb python -I s1.py g.py 2>&1 | cut -c1-400
```

Result of `Bash`
```
## select count(*) filter (where contact_email is not null and website_url is not null and lower(split_part(contact_email,'@',2)) <> lower(regexp_replace
['dom_diff', 'n_both']
(333, 2415)
## select r.org_name,r.announced_on,string_agg(investment_type||':'||coalesce(money_raised_usd,'null'),' | ') from funding_rounds r group by 1,2 having c
['org_name', 'announced_on', "string_agg(((investment_type || ':') || COALESCE(money_raised_usd, 'null')), ' | ')"]
('CRS', '2021-04-27', 'debt_financing:null | pre_seed:1000005.0')
('Observe', '2020-10-07', 'debt_financing:null | series_a:35000000.0')
('SumX', '2025-08-14', 'debt_financing:null | seed:1100000.0')
('Prolific Machines', '2020-05-25', 'pre_seed:null | convertible_note:null')
('Nagomi Security', '2024-04-23', 'seed:7000000.0 | series_a:23000000.0')
('ObservePoint', '2021-09-30', 'series_b:246380.0 | secondary_market:null')
## with s as (select org_uuid,arg_max(investment_type,try_cast(announced_on as date)) lt from funding_rounds group by 1) select o.organization_name,o.las
['organization_name', 'last_funding_type', 'lt']
('Nagomi Security', 'series_a', 'seed')
('Breaking Change', 'pre_seed', 'grant')
('SumX', 'seed', 'debt_financing')
('LogicMonitor', 'private_equity', 'debt_financing')
## select count(*) from organizations where lower(categories||category_groups) like '%artificial intelligence%'
['count_star()']
(2023,)
## select count(*) filter (where organization_name ~ '^[A-Z0-9 ]+$' and length(organization_name)>3) from
... [truncated 2420 chars]
```

Tool call `Bash`
```
cd [REDACTED_SECRET] && cat > h.py <<'EOF'
q("select count(*) filter (where length(short_description)>=139) near_cap, count(*) filter (where short_description ~ '\\xa0') nbsp, count(*) filter (where short_description !~ '[.!?)\"]$') no_terminal_punct from organizations")
EOF
uvx --with duckdb python -I s1.py h.py 2>&1 | tail -2
```

Result of `Bash`
```
['near_cap', 'nbsp', 'no_terminal_punct']
(214, 7, 515)
```

Tool call `Bash`
```
cat > white_circle/docs/data-profile.md <<'EOF'
# Data profile: Crunchbase extract (organizations / funding_rounds / contacts)

Profiled 2026-10-29, read-only, DuckDB 1.5.5. Every column is read as `all_varchar` so nothing is silently coerced, then cast with `try_cast`.
Rows: 3,000 organizations, 1,854 funding rounds, 2,763 contacts.

**Headline.** The data is far cleaner than "raw and a little messy" suggests: no duplicate uuids or names, no orphans, no name drift, no unparseable numbers or dates, categorical values are consistent snake_case codes. The mess is elsewhere: sparsity, coded range columns, `;`-delimited multi-value columns, URL and email inconsistencies, role-level contact duplicates, and snapshot semantics that quietly mislead (acquired companies still `active`, `funding_stage` mixing two meanings). The sample is not a random Crunchbase slice: it is AI-heavy by construction (2,023 of 3,000 are AI-tagged), so "AI" is not a discriminating ICP filter on its own.

Setup used throughout (script harness in the scratchpad):
`` `sql
CREATE VIEW organizations AS SELECT * FROM read_csv('.../organizations.csv', all_varchar=true, header=true, sample_size=-1);
-- same for funding_rounds, contacts
`` `

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

`` `sql
SELECT count(*)-count(DISTINCT (org_uuid,person_uuid)) FROM contacts;                 -- 66
SELECT count(*)-count(DISTINCT (org_uuid,investment_type,announced_on)) FROM funding_rounds; -- 0
`` `

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

`` `sql
SELECT count(*) FILTER (WHERE EXISTS (SELECT 1 FROM funding_rounds r WHERE r.org_uuid=o.uuid)) AS with_rounds FROM organizations o;
`` `

## 3. Per-column messiness

### 3a. Null / blank rates (% of rows, `NULL` or `''`)

| Table |
... [truncated 15518 chars]
```

Result of `Bash`
```
[redacted: outside project scope]
```

Tool call `Bash`
```
cd white_circle/docs && sed -i 's/ (inside names such as "Gaming, ...")//; s/4 category strings contain commas (inside names such as "Gaming, ...")/4 category strings contain commas/' data-profile.md && grep -n "contain commas" data-profile.md | cut -c1-160
```

**Final report (hand-back)**

Profile written to white_circle/docs/data-profile.md. It is the only file written in the repo, and nothing is committed. Scripts are in the scratchpad.

The data is much cleaner than "messy on purpose" implies. There are 0 duplicate uuids, names or domains, 0 duplicate rounds, 0 orphans and 0 org_name drift. Every date is ISO and every money value is a plain double. Categorical values are consistent snake_case codes with no casing variants. funding_total_usd matches the sum of rounds on 620/620 orgs, and last_funding_at matches max(announced_on) on 800/800.

Top issues:
1. Sparsity: only 800 orgs (27%) have rounds and 1,047 (35%) have contacts. 1,697 (57%) have neither. An inner join silently drops about 73% of orgs. revenue_range is 60% null, funding_stage 76%, closed_on 99%.
2. Contacts: 66 repeated (org, person) rows, mostly multiple roles for one person. 430-515 contacts are board members, advisors or investors, not buyers.
3. Acquired companies still `active`: 106 (127 with funding_stage `m_and_a`). 72 are closed, 46 of those with no closed_on. Also 17 non-profits and 29 public companies (Accor, McKesson, Experian, Wix). Their `post_ipo_*` rounds up to $3.2B skew money aggregates.
4. contact_email: 1,657 of about 2,420 are generic inboxes (info@, hello@). 333 of 2,415 have a domain that differs from the website. Website URLs vary: 414 `http://`, 984 trailing slash, 46 with paths, 4 with utm tracking.
5. Descriptions are capped at 140 characters (214 truncated). Categories are `; `-delimited (601 distinct tokens). The inconsistency is semantic overlap (Security vs Cyber Security, FinTech vs Financial Services vs Payments), not typos.
6. Year-only dates are padded to Jan 1: 1,371 founded_on. funding_stage mixes maturity and exit state. Range columns (c_/r_) are coded lower bounds.

Signal coverage (3,000 orgs):
- 2,023 (67%) carry an AI tag, so the sample is AI-heavy by construction and "AI" doesn't discriminate.
[redacted line: outside-scope]
- 429 are fintech/banking and 6 neobank-strict. 383 are health, 50 insurance, 95 legal.
- 46 orgs have both a GenAI and a fintech signal; 40 have GenAI and health.
- 3 orgs use guardrail/AI-safety/red-team language.
- 332 orgs were last funded since 2024.
- 66% of orgs have under 50 employees.
- Buyer titles: 715 CEO, 1,058 founder, 270 CTO, 139 VP/Head of eng/data/product, 17 AI/ML leaders, 26 compliance/legal, only 7 security.

Probable traps (my inference, not provable): acquired-but-active, generic inboxes as contact_email, NULL-heavy joins, role-level contact duplicates, public giants skewing sums, and coded ranges. There are no test rows or injected instructions. Lovable and the named neobanks (Revolut, Monzo, N26, Nubank, Chime, Starling) are absent, so this is a lookalike pool with no customer flag. Data runs to 2026-06-20 against today's 2026-10-29, so pin an as_of date.

Caveat: the title-bucket and keyword counts are regex-based, so treat them as approximate.

Result of `Bash`
```
Exit code 1
sed: 1: "data-profile.md
": extra characters at the end of d command
```

Result of `SubagentHandback`
```
[redacted: outside project scope]
```
