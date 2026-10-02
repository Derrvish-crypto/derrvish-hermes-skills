---
name: hermes-state-db-maintenance
description: "Audit, clean, and compact Hermes state.db."
---

# Hermes State DB Maintenance

Direct SQLite operations on `state.db` for bulk cleanup, disk reclamation, and health auditing. Complements `session-librarian` (CLI-level session organization) with DB-level structural maintenance.

## When to Use

- User asks how many sessions/messages exist, or wants exact counts
- User asks to clean up / reclaim disk space from the session database
- `state.db` grows beyond ~2 GB and FTS tables dominate
- Diagnosing why session search is slow or returning stale results
- Before/after large cron job changes that affect session volume

## DB Location & Schema

**Path:** `%LOCALAPPDATA%\hermes\state.db`

Key tables:
| Table | Purpose |
|---|---|
| `sessions` | One row per session (id, source, user_id, model, message_count, tool_call_count, tokens, started_at, ended_at, end_reason, title, display_name, archived, hidden) |
| `messages` | One row per message (session_id FK, role, content, tool info) |
| `messages_fts` / `messages_fts_content` / `messages_fts_data` | Keyword FTS5 index |
| `messages_fts_trigram` / `messages_fts_trigram_content` / `messages_fts_trigram_data` | Trigram FTS index (for substring/partial matching) |
| `session_model_usage` | Per-session token/cost tracking |
| `system_prompts` | Cached system prompts |

**Source values:** `cli`, `cron`, `desktop`, `subagent`, `telegram`, `tui`, `unknown`

## Audit Procedure

```python
import sqlite3, os, datetime
db = r'%LOCALAPPDATA%\hermes\state.db'
conn = sqlite3.connect(db); cur = conn.cursor()

# 1. File size
print(f"DB: {os.path.getsize(db)/1024/1024:.0f} MB")

# 2. Disk usage by table (dbstat)
cur.execute("SELECT name, SUM(pgsize)/1024/1024 as mb FROM dbstat GROUP BY name ORDER BY mb DESC LIMIT 15")
for r in cur.fetchall(): print(f"  {r[0]}: {r[1]:.1f} MB")

# 3. Session counts by source
cur.execute('SELECT source, COUNT(*) FROM sessions GROUP BY source ORDER BY 2 DESC')

# 4. Real user chats vs automation
cur.execute("SELECT COUNT(*) FROM sessions WHERE source NOT IN ('cron','subagent')")

# 5. Date range
cur.execute('SELECT MIN(started_at), MAX(started_at) FROM sessions')

# 6. Totals
cur.execute('SELECT SUM(message_count), SUM(tool_call_count), SUM(input_tokens), SUM(output_tokens) FROM sessions')

# 7. Freelist (reclaimable by VACUUM alone)
cur.execute('PRAGMA freelist_count'); free = cur.fetchone()[0]
cur.execute('PRAGMA page_size'); ps = cur.fetchone()[0]
print(f"Freelist: {free*ps/1024/1024:.1f} MB")

# 8. WAL file
wal = db + '-wal'
if os.path.exists(wal): print(f"WAL: {os.path.getsize(wal)/1024/1024:.1f} MB")
```

**Key insight:** FTS tables (`messages_fts_*`, `messages_fts_trigram_*`) typically occupy 2–3× the raw `messages` table. Deleting rows without rebuilding FTS saves nothing on disk — the ghost index entries persist.

## Bulk Cleanup Procedure

### ① Backup (MANDATORY)
```python
import shutil
backup = r'%USERPROFILE%:\Documents\hermes_state\state.db.pre-cron-clean-YYYYMMDD'
shutil.copy2(db, backup)
```
Show backup size to user. Never skip this step.

### ② Preview deletion set
Query what will be removed BEFORE deleting. Present counts to user.

Safe filter pattern (preserves unique work):
```sql
-- Delete: short homogeneous cron runs older than 30 days
SELECT COUNT(*), SUM(message_count) FROM sessions
WHERE source='cron' AND started_at < ? AND message_count < 50

-- Keep: long cron sessions (>50 msg) — may contain unique investigations
SELECT COUNT(*) FROM sessions
WHERE source='cron' AND started_at < ? AND message_count >= 50
```
Always keep all non-cron sources (desktop, telegram, tui, subagent, cli).

### ③ Delete in FK order
```python
cutoff = time.time() - 30*86400
cur.execute("DELETE FROM messages WHERE session_id IN (
    SELECT id FROM sessions WHERE source='cron' AND started_at < ? AND message_count < 50)", (cutoff,))
cur.execute("DELETE FROM sessions WHERE source='cron' AND started_at < ? AND message_count < 50", (cutoff,))
```

### ④ Rebuild FTS indexes (MANDATORY after bulk delete)
```python
cur.execute("INSERT INTO messages_fts(messages_fts) VALUES('rebuild')")
cur.execute("INSERT INTO messages_fts_trigram(messages_fts_trigram) VALUES('rebuild')")
```
~60s on a 2 GB DB. This is where the real disk savings happen — without it, FTS retains ghost entries.

### ⑤ VACUUM
```python
cur.execute('VACUUM')
```
~25s on a 2 GB DB. Freelist is usually small (<5 MB) so VACUUM alone saves little; the savings come from FTS rebuild + row deletion.

### ⑥ Verify
```python
cur.execute('SELECT COUNT(*) FROM sessions')  # expected count
cur.execute('SELECT COUNT(*) FROM messages')   # expected count
cur.execute("SELECT COUNT(*) FROM messages_fts WHERE messages_fts MATCH 'gateway'")  # FTS alive
print(f"DB: {os.path.getsize(db)/1024/1024:.0f} MB")  # size delta
```

## Pitfalls

- **FTS rebuild is the expensive step, not the delete.** Don't skip it expecting VACUUM to do the work.
- **WAL file** (`state.db-wal`) can be 50–100 MB during active use. Normal; `PRAGMA wal_checkpoint(TRUNCATE)` shrinks it but isn't required.
- **Don't delete sessions referenced by `parent_session_id`** unless you also clean up the parent chain. Cron sessions are top-level so this rarely applies.
- **Growth rate planning:** high-frequency cron jobs (every-5-min) add ~100 MB/week. For sustained control, suggest reducing cron frequency or adding a TTL-based auto-prune cron job.
- **`message_count` column** in `sessions` is a denormalized counter; actual `messages` table row count may differ slightly (tool results, system messages). Use both for accurate sizing.
- **Windows path in Python:** use raw string `r'C:\...'` or forward slashes. MSYS path conversion does not apply inside `execute_code`/`terminal` Python.
- **Pre-cleanup backup doubles the Z: footprint:** the pre-cleanup snapshot (`state.db.pre-cron-clean-*`, ~2.6 GB) sits in `%USERPROFILE%:\Documents\hermes_state\` alongside the live copy. After the next successful cleanup cycle (or ~30 days), offer to delete the old snapshot — it is one of the top consumers of `%USERPROFILE%:\Documents` (observed 5 GB total in hermes_state/ on 2026-09-01).
- **Session dumps copied out of state.db are redundant:** files like `session_*_dump.txt` / `sess_*_full_v1.txt` in `%USERPROFILE%:\Documents` duplicate data that still lives in the DB; they belong in the cleanup tier, not the keep tier.
- **`session_search` scroll rejects anchors in the CURRENT session's lineage** ("anchor lives in the current session lineage" error) — for that kind of forensics fall back to direct SQL on `messages`: `SELECT id, role, substr(content,1,N) FROM messages WHERE session_id=... AND id BETWEEN ...` (by id range or LIKE on a verbatim fragment).
- **Context-compaction summaries can contain false narrative** (which file is the deliverable, who overwrote what, what was already delivered and accepted). When the user asks to verify the sequence of actions, do not argue from the summary — verify every claim against `timestamp` + NTFS + file content first, then report the corrected picture. A file a summary claims is «the deliverable» can be a user-sent reference file that shares the name.
- **User-sent files land in ``AppData\Local\hermes\attachments\` under the names the sender chose** — the same name as a previously delivered file = silent collision. After the user sends a file, identify which file is which by content and timestamps before asserting anything about it, and never name a new deliverable one an attachment already holds.

## Diagnosing "Empty" Sessions in Desktop UI

When a user reports a session appears empty or has no history in the desktop app, the data is almost always intact — the issue is context compaction. See `references/session-compaction-diagnosis.md` for the full diagnostic procedure and schema reference.

## Recovery: restoring lost scripts, data, and deliverables

`messages.tool_calls` is an archive of everything ever executed in a Hermes session — if a deliverable or its build script is lost (overwritten, pruned from scratch, lost to compaction), recover it from here:

1. **Locate** — `SELECT id, session_id, timestamp FROM messages WHERE tool_calls LIKE '%fragment%'` with a short distinctive verbatim fragment (a fixed-text string, an OUT path), not full text. Rows with `compacted=1` survive context compression intact — the code is still there even when the conversation summary no longer carries it.
2. **Extract** — `tool_calls` is a JSON **list**; each item = `{"function": {"name", "arguments"}}` and `arguments` is itself a **JSON-encoded string** — parse twice: `json.loads(item["function"]["arguments"])` → `code` (execute_code), `content` + `path` (write_file), `command` (terminal). Save to scratch and re-run the restored script verbatim.
3. **Reconstruct the true sequence when the narrative is in doubt** — the `timestamp` column (epoch) on messages + NTFS times (`powershell -NoProfile -Command "Get-Item <paths> | Select Name,Length,CreationTime,LastWriteTime"`) + content forensics (fitz `get_text()`, DOCX `word/document.xml`). NTFS and DB timestamps agree to the second — that is the ground truth.

## Duplicate-work check: "you didn't answer / didn't do X"

When the user says a request was missed or went unanswered, the work is often ALREADY DONE — usually in another session (desktop vs TG-mirror vs WA), invisible to the current context after a compaction handoff. Verify before redoing — a full re-run of an already-completed investigation is pure waste:

1. **Find the original request** — `session_search(query=...)`; if scroll is refused (anchor in current lineage), go to direct SQL. Count the repetitions: the same user message sent N times across sessions is a symptom that the answer never reached the user's channel, not that the work is missing.
2. **Locate the assistant's final answer** in that session's messages — `WHERE session_id=... AND role='assistant' AND (content LIKE '%отчёт%' OR content LIKE '%report%')`; the answer usually names the report path and the decision table.
3. **Verify deliverables on disk** — `os.path.exists` on the report + the cloned/installed artifacts. A summary's claim is not evidence; the file is.
4. **Re-verify the report's facts live** (API / disk / NTFS — per the user's "active test of every component" rule), then answer with «выполнено в сессии X, отчёт на <путь>» + what changed since (fresh stars/pushed dates, new versions) — not a redone investigation.

## Reference: Typical Size Profile (post-cleanup, Sep 2026)

| Component | Size |
|---|---|
| `messages` | ~600 MB |
| `messages_fts_trigram_data` | ~650 MB |
| `messages_fts_trigram_content` | ~350 MB |
| `messages_fts_content` | ~350 MB |
| `messages_fts_data` | ~90 MB |
| `sessions` + indexes | ~80 MB |
| **Total** | **~2.3 GB** |

Pre-cleanup was 2.6 GB with 8 440 sessions (8 113 cron). Post-cleanup: 941 sessions, 2.3 GB.
