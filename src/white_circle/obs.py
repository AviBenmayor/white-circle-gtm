"""Audit trail: every CLI run and every external API call.

Each record goes to two places: a row in DuckDB (ops.run / ops.api_call) and one
JSON line in data/logs/events.jsonl. The JSONL file survives a deleted .duckdb,
which is why both exist. Connections are opened and closed per write so the
DuckDB file is never held locked between steps.
"""
from __future__ import annotations

import json
import subprocess
import sys
import traceback
import uuid
from contextlib import contextmanager
from datetime import datetime, timezone

import duckdb

from .paths import DB, EVENTS, ROOT

_DDL = """
CREATE SCHEMA IF NOT EXISTS ops;
CREATE TABLE IF NOT EXISTS ops.run (
  run_id VARCHAR PRIMARY KEY, command VARCHAR, args VARCHAR,
  started_at TIMESTAMP, ended_at TIMESTAMP, status VARCHAR, error VARCHAR,
  rows_written BIGINT, git_sha VARCHAR);
CREATE TABLE IF NOT EXISTS ops.api_call (
  run_id VARCHAR, provider VARCHAR, endpoint VARCHAR, request_summary VARCHAR,
  status_code INTEGER, latency_ms DOUBLE, credits_or_tokens DOUBLE,
  cost_usd DOUBLE, response_ref VARCHAR, called_at TIMESTAMP);
"""


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _git_sha() -> str | None:
    try:
        out = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
                             capture_output=True, text=True, timeout=5)
        return out.stdout.strip() or None
    except Exception:
        return None


def _jsonl(kind: str, rec: dict) -> None:
    EVENTS.parent.mkdir(parents=True, exist_ok=True)
    with EVENTS.open("a") as f:
        f.write(json.dumps({"event": kind, **rec}, default=str) + "\n")


def _db(sql: str, params: list | None = None) -> None:
    DB.parent.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB))
    try:
        con.execute(_DDL)
        con.execute(sql, params or [])
    finally:
        con.close()


class Run:
    """Handle yielded by track_run; commands add to rows_written."""

    def __init__(self, run_id: str):
        self.run_id = run_id
        self.rows_written = 0

    def add_rows(self, n: int) -> None:
        self.rows_written += int(n)


@contextmanager
def track_run(command: str, args: dict | None = None):
    run = Run(str(uuid.uuid4()))
    started = _now()
    sha = _git_sha()
    args_s = json.dumps(args or {}, default=str)
    status, error = "ok", None
    try:
        yield run
    except BaseException as e:  # noqa: BLE001 - record then re-raise
        status = "error"
        error = "".join(traceback.format_exception_only(type(e), e)).strip()
        raise
    finally:
        ended = _now()
        # The DB may have just been rebuilt by the command; write the row after.
        try:
            _db("INSERT INTO ops.run VALUES (?,?,?,?,?,?,?,?,?)",
                [run.run_id, command, args_s, started, ended, status, error,
                 run.rows_written, sha])
        except Exception as e:  # never mask the command's own outcome
            print(f"[obs] could not write ops.run: {e}", file=sys.stderr)
        _jsonl("run", dict(run_id=run.run_id, command=command, args=args or {},
                           started_at=started, ended_at=ended, status=status,
                           error=error, rows_written=run.rows_written, git_sha=sha))


def record_api_call(run_id: str, provider: str, endpoint: str, request_summary: str,
                    status_code: int | None, latency_ms: float | None,
                    credits_or_tokens: float | None = None, cost_usd: float | None = None,
                    response_ref: str | None = None, called_at: datetime | None = None) -> None:
    """Log one external API call (Tavily, Anthropic, ...). Used by later enrichment steps."""
    rec = dict(run_id=run_id, provider=provider, endpoint=endpoint,
               request_summary=request_summary, status_code=status_code,
               latency_ms=latency_ms, credits_or_tokens=credits_or_tokens,
               cost_usd=cost_usd, response_ref=response_ref, called_at=called_at or _now())
    _db("INSERT INTO ops.api_call VALUES (?,?,?,?,?,?,?,?,?,?)", list(rec.values()))
    _jsonl("api_call", rec)
