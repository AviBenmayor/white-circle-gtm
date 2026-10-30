"""Redacted export of the Claude Code session that built this repo (the "AI traces").

Allowlist, not blocklist: only four kinds of transcript content are carried over
(user prompts, assistant visible text, tool calls, tool results) and each one is
scrubbed on the way through. Everything else (system/attachment/meta entries,
injected context, thinking blocks) is dropped without being read into the output.
Every redaction is logged with entry index + reason to data/logs/REDACTION_REPORT.txt,
and a final scan of docs/traces/ must come back with zero hits or the command fails.
"""
from __future__ import annotations

import json
import re
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path

from .paths import DATA, LOGS, ROOT, TRACES_DIR

OUT = TRACES_DIR
REPORT = LOGS / "REDACTION_REPORT.txt"
CLAUDE_PROJECTS = Path.home() / ".claude" / "projects" / "-Users-abenmayor-Documents-Projects-abenmayor"
DEFAULT_SESSIONS = [
    "20f886d2-3e4f-44fa-a0fb-33aac534d3c4",   # original build session
    "e096f4c5-4c93-454b-9b78-b7b51a4f459a",   # resumed copy of it (repeats its history)
    "51f4a902-ee2f-42ae-91c1-314656bb810f",   # the session continuing the work
]

MD_RESULT_CHARS = 1500      # tool results in the markdown
JSONL_RESULT_CHARS = 6000   # tool results in the machine copy
MD_INPUT_CHARS = 4000       # tool-call inputs / agent prompts in the markdown

# ---- policy (edit here) -----------------------------------------------------
# Lines/results matching any of these are removed. DNI is the only case-sensitive one.
DENYLIST = [
    r"residen(?:cy|t)\b", r"(?-i:\bDNI\b)", r"certificado", r"r[eé]sum[eé]", r"job search",
    r"salary", r"transactions\.csv", r"Preply", r"Classroom", r"favicon", r"\bOpera\b",
    r"Notion .*\.dmg", r"avibenmayor", r"sk-\[A-Za-z", r"api[_-]?key=\S+", r"sk-[A-Za-z0-9]{10,}",
]
# Secret *shapes*: the value is replaced in place, the rest of the line survives.
SECRET_SHAPES = [
    r"sk-[A-Za-z0-9_\-]{10,}", r"tvly-[A-Za-z0-9_\-]{8,}", r"gh[pousr]_[A-Za-z0-9]{20,}",
    r"AKIA[0-9A-Z]{16}", r"xox[abprs]-[A-Za-z0-9\-]{10,}", r"eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]*",
    r"(?i:bearer)\s+[A-Za-z0-9._\-]{20,}", r"(?i:api[_-]?key|secret|token|password)\s*[=:]\s*['\"]?[A-Za-z0-9._\-/+]{12,}",
    r"(?<![/.\w-])[A-Fa-f0-9]{40,}\b", r"(?<![/.\w-])[A-Za-z0-9+/_\-]{48,}={0,2}",
]
# References that put an item outside the take-home's scope.
OUT_OF_SCOPE = [
    r"/Users/(?!abenmayor/(?:Documents/Projects/abenmayor/white_circle\b|Downloads\b))",
    r"/Users/abenmayor/(?!Documents/Projects/abenmayor/white_circle\b|Downloads\b)",
    r"/Users/abenmayor/Documents/Projects/abenmayor/(?!white_circle\b)",
    r"~/(?!Downloads\b)", r"\.claude/", r"claude-501", r"-Users-abenmayor", r"/private/tmp",
    r"\.env(?!\.example)\b",
    r"\bagents/", r"CLAUDE\.md", r"MEMORY\.md",
]
# Names of the author's other projects, kept out of the repo: one per line in data/notes/redact_projects.txt.
_PROJECTS = DATA / "notes" / "redact_projects.txt"
if _PROJECTS.exists():
    _names = [re.escape(n.strip()) for n in _PROJECTS.read_text().splitlines() if n.strip()]
    if _names:
        OUT_OF_SCOPE.append(r"\b(?:" + "|".join(_names) + r")\b")
# In `ls`-style listings only these lines survive (the GTM dataset and this project).
LISTING_ALLOW = r"organizations|funding_rounds|contacts|white_circle|GTM|take.?home|^total\b"
# Pasted injected context that sometimes rides inside a prompt or result.
INJECTED = [r"<system-reminder>.*?</system-reminder>", r"<local-command-caveat>.*?</local-command-caveat>"]

_DENY = [re.compile(p, re.I) for p in DENYLIST]
_SECRET = [re.compile(p) for p in SECRET_SHAPES]
_OOS = [re.compile(p, re.I) for p in OUT_OF_SCOPE]
_INJ = [re.compile(p, re.S) for p in INJECTED]
_REPO = "/Users/abenmayor/Documents/Projects/abenmayor/white_circle"
_DL = "/Users/abenmayor/Downloads"
OOS_MARK = "[redacted: outside project scope]"


@dataclass
class Ctx:
    """Per-file redaction log."""
    label: str
    log: list = field(default_factory=list)   # (entry_idx, reason, hint)
    idx: int = 0
    hit: bool = False

    def note(self, reason: str, text: str) -> None:
        self.hit = True
        hint = re.sub(r"\s+", " ", text).strip()[:80]
        self.log.append((self.idx, reason, hint))


def _norm_paths(s: str) -> str:
    return s.replace(_REPO, "white_circle").replace(_DL, "~/Downloads").replace("task-id", "task_id")


def _line_bad(line: str) -> str | None:
    for r in _DENY:
        if r.search(line):
            return "denylist"
    for r in _OOS:
        if r.search(line):
            return "outside-scope"
    return None


def scrub(text: str, ctx: Ctx) -> str:
    """Line-level scrub: strip injected blocks, mask secrets, drop denylisted/out-of-scope lines."""
    for r in _INJ:
        if r.search(text):
            ctx.note("injected-context", r.search(text).group(0))
            text = r.sub("", text)
    text = _norm_paths(text)
    out = []
    for line in text.split("\n"):
        masked = line
        for r in _SECRET:
            masked = r.sub("[REDACTED_SECRET]", masked)
        if masked != line:
            ctx.note("secret-shape", "(value masked; not logged)")
        why = _line_bad(masked)
        if why:
            ctx.note(why, "(line dropped; hint withheld)" if why == "denylist" else masked)
            out.append(f"[redacted line: {why}]")
        else:
            out.append(masked)
    return re.sub(r"(\[redacted line: [a-z-]+\]\n?){2,}", lambda m: m.group(0).split("\n")[0] + "\n", "\n".join(out))


def scrub_result(text: str, tool: str, cmd: str, ctx: Ctx) -> str:
    """Tool results: listings are filtered to dataset lines; out-of-scope results are replaced whole."""
    for r in _INJ:
        text = r.sub("", text)
    if tool == "Bash" and re.match(r"\s*ls\b", cmd or ""):
        keep = re.compile(LISTING_ALLOW, re.I | re.M)
        lines = text.split("\n")
        kept = [l for l in lines if keep.search(l)]
        if len(kept) < len(lines):
            ctx.note("listing-filtered", f"{len(lines) - len(kept)} listing lines dropped")
            kept.append(f"[{len(lines) - len(kept)} other listing lines redacted: outside project scope]")
        text = "\n".join(kept)
    text = _norm_paths(text)
    if tool == "ToolSearch":
        ctx.note("tool-schema-lookup", "ToolSearch result")
        return "[omitted: tool-schema lookup]"
    for r in _OOS:
        m = r.search(text)
        if m:
            ctx.note("outside-scope", m.group(0))
            return OOS_MARK
    return scrub(text, ctx)


def _trunc(s: str, n: int) -> str:
    return s if len(s) <= n else s[:n] + f"\n... [truncated {len(s) - n} chars]"


def _blocks_text(content) -> str:
    if isinstance(content, str):
        return content
    parts = []
    for b in content or []:
        if isinstance(b, dict) and b.get("type") == "text":
            parts.append(b.get("text", ""))
    return "\n".join(parts)


def _scrub_input(inp, ctx: Ctx):
    if isinstance(inp, str):
        return scrub(inp, ctx)
    if isinstance(inp, list):
        return [_scrub_input(v, ctx) for v in inp]
    if isinstance(inp, dict):
        return {k: _scrub_input(v, ctx) for k, v in inp.items()}
    return inp


def _walk(path: Path):
    for ln in path.read_text().splitlines():
        try:
            yield json.loads(ln)
        except json.JSONDecodeError:
            continue


def _merged(paths: list[Path]) -> list[dict]:
    """Main-session entries from several transcripts: sidechains skipped, de-duplicated by uuid
    (first occurrence wins), chronological (entries with no timestamp inherit the previous one)."""
    seen: set[str] = set()
    rows: list[tuple[str, dict]] = []
    for p in paths:
        last = ""
        for e in _walk(p):
            if e.get("isSidechain"):
                continue
            u = e.get("uuid")
            if u:
                if u in seen:
                    continue
                seen.add(u)
            last = e.get("timestamp") or last
            rows.append((last, e))
    rows.sort(key=lambda r: r[0])
    return [e for _, e in rows]


def process(entries, label: str) -> tuple[list[dict], Ctx, Counter]:
    """Transcript entries -> allowlisted, scrubbed event list. Counter keys: kept/dropped/redacted + drop reasons."""
    ctx = Ctx(label)
    stats: Counter = Counter()
    events: list[dict] = []
    tools: dict[str, tuple[str, str, bool]] = {}   # tool_use_id -> (name, command, call_out_of_scope)
    for i, e in enumerate(entries):
        ctx.idx, ctx.hit = i, False
        t = e.get("type")
        msg = e.get("message") or {}
        ts = e.get("timestamp", "")
        new: list[dict] = []
        if t == "user":
            c = msg.get("content")
            if isinstance(c, str):
                txt = scrub(c, ctx).strip()
                if txt:
                    new.append(dict(role="user", kind="prompt", text=txt))
            else:
                for b in c or []:
                    if b.get("type") == "tool_result":
                        name, cmd, bad_call = tools.get(b.get("tool_use_id"), ("?", "", False))
                        raw = _blocks_text(b.get("content"))
                        if not raw and isinstance(b.get("content"), list):
                            raw = "[non-text result]"
                        if bad_call:   # the call reached outside scope, so what it returned does too
                            ctx.note("outside-scope-call", "result of a redacted call")
                            res = OOS_MARK
                        else:
                            res = scrub_result(raw, name, cmd, ctx)
                        new.append(dict(role="tool", kind="result", name=name, text=res))
                    elif b.get("type") == "text":
                        txt = scrub(b.get("text", ""), ctx).strip()
                        if txt:
                            new.append(dict(role="user", kind="prompt", text=txt))
        elif t == "assistant":
            for b in msg.get("content") or []:
                if b.get("type") == "text" and b.get("text", "").strip():
                    new.append(dict(role="assistant", kind="text", text=scrub(b["text"], ctx).strip()))
                elif b.get("type") == "tool_use":
                    inp = b.get("input") or {}
                    n0 = len(ctx.log)
                    scrubbed = _scrub_input(inp, ctx)
                    oos = any(r == "outside-scope" for _, r, _ in ctx.log[n0:])
                    tools[b.get("id")] = (b.get("name"), str(inp.get("command", "")), oos)
                    if b.get("name") == "SubagentHandback":
                        new.append(dict(role="assistant", kind="final_report",
                                        text=scrub(str(inp.get("message", "")), ctx).strip()))
                    else:
                        new.append(dict(role="assistant", kind="tool_call", name=b.get("name"),
                                        input=scrubbed))
                elif b.get("type") == "thinking":
                    stats["dropped:thinking"] += 1
        elif t == "attachment":
            a = e.get("attachment") or {}
            if a.get("type") == "queued_command" and "<agent-message" in str(a.get("prompt", "")):
                body = re.sub(r"</?agent-message[^>]*>", "", str(a["prompt"]))
                new.append(dict(role="user", kind="subagent_handback", text=scrub(body, ctx).strip()))
            else:
                stats[f"dropped:attachment/{a.get('type')}"] += 1
        else:
            stats[f"dropped:{t}"] += 1
        for n in new:
            events.append(dict(src=label, idx=i, ts=ts, **n))
        if new:
            stats["kept"] += 1
            stats["redacted"] += ctx.hit
    return events, ctx, stats


# ---- rendering ---------------------------------------------------------------
def _fence(s: str) -> str:
    return "```\n" + s.replace("```", "`` `") + "\n```"


def render_md(title: str, events: list[dict], blurb: str) -> str:
    out = [f"# {title}", "", blurb, ""]
    turn = 0
    for ev in events:
        k = ev["kind"]
        if k in ("prompt", "subagent_handback"):
            turn += 1
            who = "User" if k == "prompt" else "Subagent report delivered to the main session"
            out += [f"## Turn {turn} - {who} ({ev['ts'][:19].replace('T', ' ')} UTC)", "", ev["text"], ""]
        elif k == "text":
            out += ["**Assistant**", "", ev["text"], ""]
        elif k == "final_report":
            out += ["**Final report (hand-back)**", "", ev["text"], ""]
        elif k == "tool_call":
            inp = ev["input"]
            body = inp.get("command") if isinstance(inp, dict) and set(inp) <= {"command", "description", "timeout"} \
                else json.dumps(inp, indent=1, ensure_ascii=False)
            out += [f"Tool call `{ev['name']}`", _fence(_trunc(str(body), MD_INPUT_CHARS)), ""]
        elif k == "result":
            out += [f"Result of `{ev['name']}`", _fence(_trunc(ev["text"], MD_RESULT_CHARS)), ""]
    return "\n".join(out)


def _slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")[:40] or "agent"


def _flat(o) -> str:
    if isinstance(o, str):
        return o
    if isinstance(o, dict):
        return "\n".join(_flat(v) for v in o.values())
    if isinstance(o, list):
        return "\n".join(_flat(v) for v in o)
    return str(o)


def scan_outputs() -> list[str]:
    """Final gate: denylist terms and stray /Users/ paths anywhere under docs/traces/."""
    hits = []
    pats = [(f"denylist:{p}", re.compile(p, re.I)) for p in DENYLIST]
    pats += [("path:/Users/abenmayor/ outside white_circle", re.compile(r"/Users/(?!abenmayor/Documents/Projects/abenmayor/white_circle)"))]
    pats += [("secret-shape", r) for r in _SECRET[:7]]
    for f in sorted(OUT.glob("*")):
        text = f.read_text()
        if f.suffix == ".jsonl":   # scan decoded strings, not JSON escapes
            text = "\n".join(_flat(json.loads(l)) for l in text.splitlines() if l)
        for n, line in enumerate(text.split("\n"), 1):
            for name, r in pats:
                rr = r if hasattr(r, "search") else re.compile(r)
                if rr.search(line):
                    hits.append(f"{f.name}:{n}: {name}")
    return hits


def export(sessions: list[str] | None = None, claude_dir: Path = CLAUDE_PROJECTS) -> dict:
    sessions = sessions or DEFAULT_SESSIONS
    mains, sub_dirs, used_sessions = [], [], []
    for sid in sessions:
        m = claude_dir / f"{sid}.jsonl"
        if not m.exists():
            print(f"warning: session {sid} not found, skipped")
            continue
        used_sessions.append(sid)
        mains.append(m)
        if (claude_dir / sid / "subagents").is_dir():
            sub_dirs.append(claude_dir / sid / "subagents")
    OUT.mkdir(parents=True, exist_ok=True)
    LOGS.mkdir(parents=True, exist_ok=True)
    for f in OUT.glob("*"):     # re-runnable: outputs are always rebuilt from scratch
        f.unlink()

    files, rows, logs, all_events = [], [], [], []
    ev, ctx, st = process(_merged(mains), "main")
    (OUT / "session-main.md").write_text(render_md(
        "Main session trace", ev,
        "Chronological, redacted. User prompts, assistant text, tool calls and results. "
        "Results are truncated to about 1,500 characters."))
    files.append(("session-main.md", "The main working session: prompts, assistant text, tool calls, results", ev, st))
    all_events += ev
    logs.append((ctx, st))

    used: set[str] = set()
    jfs = {jf.name: jf for d in reversed(sub_dirs) for jf in d.glob("agent-*.jsonl")}   # one per agent id; earliest session wins
    for jf in sorted(jfs.values(), key=lambda p: p.stat().st_mtime):
        meta = json.loads(jf.with_suffix(".meta.json").read_text()) if jf.with_suffix(".meta.json").exists() else {}
        slug = _slug(meta.get("description", jf.stem))
        if slug in used:
            slug += "-" + jf.stem[-4:]
        used.add(slug)
        ev, ctx, st = process([e for e in _walk(jf)], f"subagent:{slug}")
        ctx.label = f"subagent-{slug}"
        name = f"subagent-{slug}.md"
        (OUT / name).write_text(render_md(
            f"Subagent trace: {meta.get('description', slug)}", ev,
            f"A delegated subagent ({meta.get('agentType', 'general-purpose')}). Its prompt, its tool calls "
            "and results, and its final report. Same redaction rules as the main session."))
        files.append((name, f"Subagent: {meta.get('description', slug)}", ev, st))
        all_events += ev
        logs.append((ctx, st))

    with (OUT / "session.redacted.jsonl").open("w") as f:
        for e in all_events:
            e = dict(e)
            if e["kind"] == "result":
                e["text"] = _trunc(e["text"], JSONL_RESULT_CHARS)
            f.write(json.dumps(e, ensure_ascii=False) + "\n")

    tot = Counter()
    for _, st in logs:
        tot.update(st)
    lines = ["# Traces index", "",
             "These are the AI traces for this take-home: the Claude Code sessions that built the project, "
             "and the subagents it delegated to. They were exported from the raw transcripts by "
             "`whitecircle export-traces` and redacted. They are chronological and in the order things happened.", "",
             "| File | What it is | Entries kept | Entries redacted |", "|---|---|---|---|"]
    for name, what, ev_, st_ in files:
        lines.append(f"| {name} | {what} | {st_['kept']} | {st_['redacted']} |")
    lines.append(f"| session.redacted.jsonl | Machine-readable copy of all of the above, one event per line "
                 f"({len(all_events)} events) | - | - |")
    lines += ["", "## Redaction policy, in plain words", "",
              "- Only four things are carried over: what the user typed, what the assistant said, the tools it called "
              "(name and input), and what those tools returned. Everything else in the raw transcript is dropped.",
              "- Dropped entirely: system and bookkeeping entries, injected context (project instructions, memory notes, "
              "skill and tool listings, environment blocks, hook output), and the assistant's private reasoning blocks.",
              "- Anything that touches files outside this project, other projects, local credentials files, or "
              "personal documents is replaced with `[redacted: outside project scope]`. Directory listings keep only "
              "the lines for the GTM dataset and this project.",
              "- A keyword denylist removes any line about personal, financial or identity matters, and anything that "
              "looks like an API key or token is masked. No credential value appears anywhere in these files.",
              "- Tool results are cut to about 1,500 characters in the markdown. The cut is marked.",
              "- A final scan of every output file must find zero denylisted terms and zero paths outside the project; "
              "the export fails otherwise.", "",
              f"Totals: {tot['kept']} entries kept, {tot['redacted']} of them with at least one redaction, "
              f"{sum(v for k, v in tot.items() if k.startswith('dropped:'))} content items dropped by the allowlist."]
    (OUT / "index.md").write_text("\n".join(lines) + "\n")

    hits = scan_outputs()
    rep = ["REDACTION REPORT (owner review only; gitignored)", "sessions: " + ", ".join(used_sessions), ""]
    for ctx, st in logs:
        rep.append(f"== {ctx.label}: kept {st['kept']}, redacted {st['redacted']}, "
                   + ", ".join(f"{k} {v}" for k, v in sorted(st.items()) if k.startswith("dropped:")))
        rep += [f"  entry {i:>4}  {why:<18} {hint}" for i, why, hint in ctx.log]
    rep += ["", f"== final scan of docs/traces/ (denylist, /Users/ outside white_circle, secret shapes): {len(hits)} hits"]
    rep += [f"  {h}" for h in hits]
    REPORT.write_text("\n".join(rep) + "\n")
    return dict(files=len(files) + 2, kept=tot["kept"], redacted=tot["redacted"],
                dropped=sum(v for k, v in tot.items() if k.startswith("dropped:")),
                events=len(all_events), hits=hits)
