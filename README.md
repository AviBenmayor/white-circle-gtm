# White Circle GTM take-home

Crunchbase extract in, ranked top-50 account list, Attio CRM data model and a systems-design note out, all reproducible from one DuckDB pipeline.

## View the dashboard

https://claude.ai/artifact/16YPoLWsmzWM5ApkZsscX9

Fallback: download `docs/dashboard/index.html` and open it in a browser. It is one self-contained file and works offline. One tab per deliverable, each with its own deep link: **1 · Segments & top 50** (`#segments`), **2 · Top-5 deep dives** (`#deep-dives`), **3 · Memo** (`#memo`), **4 · CRM model** (`#crm`), **5 · Code, SQL & traces** (`#code`) and **Part 2 · System design** (`#system-design`).

## Where each deliverable is

| Brief item | Where |
|---|---|
| Part 1.1 Segments, scoring model, top 50 | SQL in `src/white_circle/sql/` (`50_`-`70_`), list in `docs/part1-segmentation/top50.csv`, dashboard Accounts tab |
| Part 1.2 Top-5 enrichment | `docs/part1-segmentation/accounts/` (one `.md` and one `.json` dossier per account: Replit, Shapes, Botpress, Dash0, Kinfolk) |
| Part 1.3 Memo | `docs/part1-segmentation/memo.md` |
| Part 1.4 CRM data model | `docs/part1-crm-model/crm-data-model.md`, `crm_model.json`, `attio_upsert_example.json`; export SQL `src/white_circle/sql/80_crm_export.sql` |
| Part 1.5 Code, SQL, schema, notes, AI traces | `src/white_circle/`, `docs/part1-segmentation/data-profile.md` and `approach-evolution.md`, `docs/traces/` |
| Part 2 Workflow diagram and note | `docs/part2-systems-design/system-design.md`, diagram `docs/dashboard/workflow.svg` |
| The brief and our research on White Circle | `docs/context/` |

## How it works

1. DuckDB layers: `raw` (faithful VARCHAR copy of the CSVs) -> `stg` (typed, cleaned) -> `mart` (features, gates, score, segments, top 50) -> `crm` (Attio-shaped export). `dq` holds the checks.
2. Hard gates first (closed, acquired, non-profit, services firm, dead site, not AI, industry not matched), then a points rubric on funding recency, revenue, headcount and fit to White Circle's own positioning.
3. Tavily verification: candidates' websites were checked in score order for what the product actually ships (180 companies, including every top-50 account); the labels are committed as `src/white_circle/seeds/company_review.csv` and feed the score.
4. Every run and every external API call is logged to `ops.run` and `ops.api_call` (provider, credits, latency).
5. Scores are written to `ops.score_history` on each build so a rubric change is visible as a diff, not a silent overwrite.

## Beyond the brief

Built but left off the dashboard to keep it scoped to the deliverables:

- **Verification queue** (`mart.verify_next`): every gate-passer outside the top 50 that has not been checked against its own website yet, best score first. Working it moves companies into or out of the top-50 pool.
- **Segments by vertical and region**: the scored candidates split by industry and by region (`mart.org_segment`; `uv run whitecircle segments` prints the segment × tier matrix).
- **Run and API-call log** (`ops.run`, `ops.api_call`) and **score history** (`ops.score_history`): kept on the dashboard, collapsed at the bottom of tab 1.

## Reproduce it

```
uv sync
cp .env.example .env     # optional: TAVILY_API_KEY, APOLLO_API_KEY (not needed to rebuild)
# put organizations.csv, funding_rounds.csv, contacts.csv in data/raw/
make                     # load, merge-reviews, build, dq, top50, dashboard
```

The raw CSVs are not committed: they are the brief's licensed dataset. Verification labels are committed in `src/white_circle/seeds/`, so the build is deterministic without re-scraping. Equivalent commands: `uv run whitecircle load && uv run whitecircle merge-reviews && uv run whitecircle build && uv run whitecircle dq && uv run whitecircle top50 && uv run whitecircle dashboard`. `make` skips `merge-reviews` when `data/verify/` is absent.

## Repo layout

```
README.md
Makefile  pyproject.toml  uv.lock  .env.example
docs/
  dashboard/             index.html, workflow.svg
  part1-segmentation/    memo.md, approach-evolution.md, data-profile.md, top50.csv, accounts/, archive/
  part1-crm-model/       crm-data-model.md, crm_model.json, attio_upsert_example.json
  part2-systems-design/  system-design.md
  context/               assignment.md, whitecircle-research.md
  traces/                redacted AI session traces
src/white_circle/        CLI, dashboard renderer, SQL (numbered), seeds, templates
data/                    gitignored: raw CSVs, warehouse, logs, notes
```

## AI traces

`docs/traces/` holds the Claude Code session that built this project and its subagents, as readable markdown plus one redacted JSONL (`index.md` lists the files). They are exported by `uv run whitecircle export-traces`, which redacts secrets, local paths, injected system context and private reasoning, and fails if a final scan of the folder finds any leak.
