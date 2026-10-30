import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
# WHITECIRCLE_DATA lets a test run point at a scratch copy of data/ (never the real one).
DATA = Path(os.environ["WHITECIRCLE_DATA"]) if os.environ.get("WHITECIRCLE_DATA") else ROOT / "data"
RAW = DATA / "raw"
VERIFY = DATA / "verify"
DB = DATA / "white_circle.duckdb"
LOGS = DATA / "logs"
EVENTS = LOGS / "events.jsonl"
SQL_DIR = Path(__file__).resolve().parent / "sql"
# Committed package data: the LLM-verified website labels (provenance for score v3).
SEEDS = (Path(os.environ["WHITECIRCLE_SEEDS"]) if os.environ.get("WHITECIRCLE_SEEDS")
         else Path(__file__).resolve().parent / "seeds")
REVIEW_SEED = SEEDS / "company_review.csv"
HC_SEED = SEEDS / "headcount_history.csv"
ENRICH = DATA / "enrich" / "pdl"

# Published documents (docs/ is fully tracked; data/ is not).
DOCS = ROOT / "docs"
DASHBOARD_HTML = DOCS / "dashboard" / "index.html"
SEGMENTATION = DOCS / "part1-segmentation"
TOP50_CSV = SEGMENTATION / "top50.csv"
ACCOUNTS_DIR = SEGMENTATION / "accounts"
EVOLUTION_MD = SEGMENTATION / "approach-evolution.md"
CRM_MODEL_JSON = DOCS / "part1-crm-model" / "crm_model.json"
TRACES_DIR = DOCS / "traces"

# Second copy for the publisher (data/ is gitignored): same page without the document wrapper tags.
PUBLISH_HTML = DATA / "publish" / "dashboard.html"
README = ROOT / "README.md"
SRC_PKG = Path(__file__).resolve().parent
