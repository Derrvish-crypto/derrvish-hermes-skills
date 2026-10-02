# Browser Harness Setup on This Workstation

## Environment
- **OS:** Windows 11 Pro 25H2
- **Chrome:** 149.0.7827.103 (as of 2026-06-13)
- **Python:** 3.11.15 (via uv toolchain)
- **Install method:** `uv tool install -e .` from `~/Developer/browser-harness/`

## Chrome Launch Command (Way 2 — Isolated Profile)

```bash
# Start Chrome with CDP on port 9222, isolated profile:
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" ^
  --remote-debugging-port=9222 ^
  --user-data-dir="$HOME/BrowserHarness-Profile" ^
  --no-first-run

# Verify CDP is listening:
curl -s http://127.0.0.1:9222/json/version
```

## Environment Variable
Always set before invoking browser-harness:
```bash
export BU_CDP_URL=http://127.0.0.1:9222
```

## Verified Working (2026-06-13)
- ✅ `new_tab()` + `wait_for_load()` — navigation works
- ✅ `js("...")` — JavaScript evaluation returns correct results
- ✅ `http_get(url)` — fast HTTP requests work (returns string, parse with json.loads())
- ✅ `page_info()` — returns url, title, dimensions dict

## Verified NOT Working / Unreliable
- ❌ `browser-harness -c '...'` — exits with error, only heredoc works on Windows
- ⚠️ `capture_screenshot()` — daemon IPC TimeoutError on this setup
- ⚠️ Dynamic pages (GitHub, HN) — need explicit `time.sleep(2)` after load

## Common Errors Encountered
1. **Python ternary in JS strings** → `SyntaxError: Unexpected token 'if'`
   - Fix: Use JS ternary (`cond ? a : b`) inside `js("...")`
2. **Daemon timeout on screenshot** → `TimeoutError: timed out` at `_ipc.py:99`
   - Workaround: Skip screenshots, use `js()` for DOM inspection
