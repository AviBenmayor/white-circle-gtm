-- 00_schemas.sql
-- Rebuilds the derived schemas from scratch on every `whitecircle build`.
--
--   raw  : untouched copy of the CSVs, every column VARCHAR (made by `whitecircle load`)
--   stg  : cleaned, typed, flagged tables (this folder)
--   dq   : data-quality check log, computed live from raw + stg
--   mart : the answer layer: v4 weights, org master, gates, rubric score, segments, top 50
--   ops  : audit trail of CLI runs and API calls, and ops.score_history, the append-only
--          record of every scoring run (NOT dropped here; see obs.py and 61_)
--
-- Dropping stg, dq and mart makes the build idempotent: the result depends only on raw
-- and these SQL files, never on what a previous run left behind.
DROP SCHEMA IF EXISTS stg CASCADE;
DROP SCHEMA IF EXISTS dq CASCADE;
DROP SCHEMA IF EXISTS mart CASCADE;
CREATE SCHEMA stg;
CREATE SCHEMA dq;
CREATE SCHEMA mart;
