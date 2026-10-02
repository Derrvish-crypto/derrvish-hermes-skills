# Session Compaction Diagnosis

Reference for diagnosing why a session appears "empty" or missing history in the Hermes desktop UI.

## Root Cause: Context Compaction

Long sessions go through multiple context compaction cycles. Each cycle:
1. Marks old messages `active=0, compacted=1`
2. Inserts a summary message with `_compressed_summary=1` (role=user, prefixed `[CONTEXT COMPACTION — REFERENCE ONLY]`)
3. The new session inherits the chain via `parent_session_id` + `model_config._reset_from`

The desktop UI renders only `active=1` messages (plus compacted summaries when `includeCompacted=true`). After several compaction cycles, most original content is behind `compacted=1` rows, leaving few visible user/assistant text messages.

**Key point: data is NOT lost.** All messages remain in the `messages` table. `session_search` finds them. The UI just doesn't render compacted rows as normal transcript by default.

## Diagnostic Queries

```python
import sqlite3
db = r'%LOCALAPPDATA%\hermes\state.db'
conn = sqlite3.connect(db); cur = conn.cursor()
sid = '<session_id>'

# 1. Session metadata — check reset chain and handoff state
cur.execute('''SELECT id, title, message_count, parent_session_id,
              handoff_state, end_reason, archived, hidden,
              compression_failure_error, model_config
              FROM sessions WHERE id=?''', (sid,))
row = cur.fetchone()
# model_config JSON contains _reset_from (previous session id)

# 2. Message visibility breakdown (the key query)
cur.execute('''SELECT active, compacted, _compressed_summary, COUNT(*)
              FROM messages WHERE session_id=?
              GROUP BY active, compacted, _compressed_summary''', (sid,))
# Typical result for a heavily-compacted session:
#   active=0, compacted=0, compressed=0: N    (pre-compaction originals, now hidden)
#   active=0, compacted=1, compressed=0: M    (compacted away)
#   active=0, compacted=1, compressed=1: K    (summary rows)
#   active=1, compacted=0, compressed=0: X    (what the UI shows)
#   active=1, compacted=0, compressed=1: Y    (latest compaction summary, visible)

# 3. What the UI actually sees
cur.execute('''SELECT role, COUNT(*),
              SUM(CASE WHEN content IS NOT NULL AND content != '' THEN 1 ELSE 0 END)
              FROM messages WHERE session_id=? AND active=1
              GROUP BY role''', (sid,))
# If assistant count >> non-empty content count, most turns were
# tool-call-only (content stored in tool_calls JSON, not content column)

# 4. Trace the full session chain
cur.execute('SELECT id, title, message_count, parent_session_id FROM sessions WHERE id=?', (sid,))
while row := cur.fetchone():
    print(row)
    cur.execute('SELECT id, title, message_count, parent_session_id FROM sessions WHERE id=?', (row[3],))
```

## messages Table Schema (visibility-relevant columns)

| Column | Meaning |
|---|---|
| `active` (INTEGER) | 1 = visible in current context window; 0 = evicted by compaction |
| `compacted` (INTEGER) | 1 = this row was absorbed into a compaction summary |
| `_compressed_summary` (INTEGER) | 1 = this row IS a compaction summary (not original content) |
| `observed` (INTEGER) | 1 = message was seen by the model at least once |
| `display_kind` (TEXT) | Optional display override (usually NULL) |
| `tool_calls` (TEXT) | JSON array of tool calls for assistant turns (content may be empty) |

## Desktop API Behavior

- `/api/sessions/{id}/messages?order=latest&limit=120&include_compacted=true` — initial hydration page
- `include_compacted=true` includes rows where `active=0 AND compacted=1` (preserved by in-place compaction)
- Without `include_compacted`, the transcript silently ends at the compaction boundary
- Tool results (`role=tool`) and empty assistant turns (tool-call-only) render collapsed or hidden in the UI

## When to Reassure vs Investigate Further

**Reassure (data intact):**
- `active=0, compacted=1` rows exist with substantial counts
- `_compressed_summary=1` rows present (handoff summaries)
- `parent_session_id` chain traces back to the original session
- `session_search` finds the content

**Investigate further (possible real loss):**
- `message_count` in `sessions` table is 0 or very low AND no compacted rows
- No `parent_session_id` chain exists
- `compression_failure_error` is set (compaction crashed mid-write)
- `handoff_state` indicates an incomplete handoff

## Exporting Full Transcript (including compacted)

If the user wants the complete history:

```python
cur.execute('''SELECT role, content, timestamp FROM messages
              WHERE session_id=? ORDER BY id''', (sid,))
# Write all rows to a markdown file, including compacted ones
# Label compacted sections with their compaction boundary
```
