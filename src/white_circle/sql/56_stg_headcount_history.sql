-- 56_stg_headcount_history.sql  ->  stg.headcount_history  (one row per ENRICHED org)
--
-- Headcount over time is NOT in the Crunchbase extract (only a size band). It comes from
-- Apollo via `whitecircle enrich-headcount-apollo` (enrich_apollo.py; PDL, enrich_pdl.py, was the first choice), which writes the
-- committed seed src/white_circle/seeds/headcount_history.csv. This file turns that CSV
-- into a typed table. There is no key yet, so today the seed does not exist: the table
-- is created EMPTY and every org simply has unknown growth (not scored in this version).
-- Same pattern as 52_: the first statement always runs, the second only when the seed
-- file exists (the marker line is read by `whitecircle build`).
--
-- Columns: hc_current and hc_Nm_ago are employee counts (current and N months before the
-- fetch month); growth_Nm_pct is the percentage change (25.0 means +25%), as PDL
-- reports it times 100; hc_source names the provider; hc_fetched_at is when it was pulled.
CREATE TABLE stg.headcount_history (
  org_uuid VARCHAR, pdl_id VARCHAR, likelihood INTEGER,
  hc_current INTEGER, hc_3m_ago INTEGER, hc_6m_ago INTEGER, hc_12m_ago INTEGER,
  growth_3m_pct DOUBLE, growth_6m_pct DOUBLE, growth_12m_pct DOUBLE,
  hc_source VARCHAR, hc_fetched_at TIMESTAMP);

-- @requires-hc-seed
INSERT INTO stg.headcount_history
SELECT nullif(trim(org_uuid), ''), nullif(trim(pdl_id), ''), try_cast(likelihood AS INTEGER),
       try_cast(hc_current AS INTEGER), try_cast(hc_3m_ago AS INTEGER), try_cast(hc_6m_ago AS INTEGER),
       try_cast(hc_12m_ago AS INTEGER),
       try_cast(growth_3m_pct AS DOUBLE), try_cast(growth_6m_pct AS DOUBLE), try_cast(growth_12m_pct AS DOUBLE),
       nullif(trim(hc_source), ''), try_cast(hc_fetched_at AS TIMESTAMP)
FROM read_csv('{{hc_seed}}', all_varchar=true, header=true, quote='"', escape='"')
WHERE nullif(trim(org_uuid), '') IS NOT NULL
QUALIFY row_number() OVER (PARTITION BY org_uuid ORDER BY hc_fetched_at DESC) = 1;
