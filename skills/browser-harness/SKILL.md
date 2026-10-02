---
name: browser-harness
description: Direct Chrome control via CDP — self-healing browser automation with raw CDP access, coordinate clicks, and dynamic helper generation. Use for complex web automation, bulk scraping, or when built-in browser_* tools are insufficient.
category: software-development
version: 1.0.0
---

# Browser Harness — Direct Chrome Control via CDP

## 📋 Overview

Browser Harness connects Hermes to your running Chrome browser through a minimal CDP (Chrome DevTools Protocol) layer. Unlike the built-in `browser_*` tools, it gives you **raw CDP access** and lets the agent write custom helper functions at runtime.

## ⚡ Quick Start

**IMPORTANT:** Only heredoc syntax works — `browser-harness -c '...'` exits with error. Always use `<<'PY'`:

```bash
export BU_CDP_URL=http://127.0.0.1:9222 && browser-harness <<'PY'
new_tab("https://example.com")
wait_for_load()
print(page_info())
PY
```

### JavaScript inside `js()` — use JS syntax, NOT Python

Code inside `js("...")` is evaluated as JavaScript. Python ternary (`x if cond else y`) causes SyntaxError:

```python
# ❌ WRONG — Python ternary in JS context → SyntaxError
result = js("titles[0] if titles.length > 0 else 'N/A'")

# ✅ CORRECT — use JS ternary
result = js("titles.length > 0 ? titles[0] : 'N/A'")
```

## 🔧 Hermes Integration

### Calling from terminal tool

Always use **heredoc syntax** (`<<'PY'`) to avoid shell quote mangling:

```bash
export BU_CDP_URL=http://127.0.0.1:9222 && browser-harness <<'PY'
# Your Python code here
new_tab("https://example.com")
wait_for_load()
result = js("document.querySelectorAll('h1').length")
print(result)
PY
```

### When to use vs built-in browser_* tools

| Use Browser Harness when... | Use browser_* tools when... |
|-----------------------------|----------------------------|
| **Cloudflare/bot-protected sites** — real Chrome passes CF challenges that block headless browsers | Simple navigation/clicking on unprotected sites |
| Complex automation with dynamic helpers | Standard web interaction |
| Need raw CDP access (custom commands) | Single page extraction |
| Bulk HTTP scraping (http_get + ThreadPoolExecutor) | Selector-based clicking works |
| Coordinate-based clicking through iframes/shadow DOM | Built-in tools cover your needs |
| Self-healing workflow (agent writes missing functions) | |

**⚠️ User preference:** When a site has Cloudflare protection, **use browser-harness immediately** — do not first try built-in `browser_*` tools and then fall back. Real Chrome with CDP is the primary path for protected sites.

## 🎯 Core Functions

### Navigation
- `new_tab(url)` — Open new tab (always use for first navigation)
- `wait_for_load()` — Wait for page to fully load
- `page_info()` — Returns dict with url, title, dimensions

### Interaction
- `click_at_xy(x, y)` — Click at coordinates (passes through iframes/shadow DOM)
- `type_text(selector, text)` — Type into element
- `js(expression)` — Execute JavaScript in page context
- `cdp(domain.method, params)` — Raw CDP command

### Data Extraction
- `http_get(url)` — Fast HTTP GET (returns string, parse with json.loads())
- `capture_screenshot()` — Save screenshot (may timeout on some systems)

## 🌐 Chrome Setup (Way 2 — Isolated Profile)

For unattended automation without popup interruptions:

```bash
# Launch Chrome with CDP enabled
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" ^
  --remote-debugging-port=9222 ^
  --user-data-dir="%USERPROFILE%\BrowserHarness-Profile" ^
  --no-first-run

# Set environment variable
export BU_CDP_URL=http://127.0.0.1:9222
```

**Important:** `--user-data-dir` MUST NOT point to Chrome's default profile directory, or the flag is silently ignored.

### Auto-start on Windows (VBS wrapper)

To avoid visible cmd.exe windows at login, wrap the `.bat` launcher in a VBS script with window style 0:

```vbs
' start_chrome_cdp.vbs — hidden Chrome CDP auto-start
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """C:\Program Files\Google\Chrome\Application\chrome.exe"" --remote-debugging-port=9222 --user-data-dir=""%USERPROFILE%\BrowserHarness-Profile"" --no-first-run", 0, False
Set WshShell = Nothing
```

Copy this VBS to `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\` for automatic startup on login. See `references/chrome-autostart.md` for the complete pattern (bat + vbs + verification).

See `references/windows-setup.md` for this workstation's verified setup (Chrome path, launch command, tested functions).

## 📁 Project Structure

```
~/Developer/browser-harness/
├── src/browser_harness/     # Core code (~600 lines)
│   ├── run.py               # CLI entry point
│   ├── helpers.py           # CDP wrappers (auto-imported)
│   ├── daemon.py            # Long-lived middleman process
│   └── _ipc.py              # IPC communication
├── agent-workspace/         # Agent edits go here
│   ├── agent_helpers.py     # Task-specific helpers
│   └── domain-skills/       # Site-specific playbooks
├── SKILL.md                 # Original skill documentation
└── install.md               # Setup & troubleshooting
```

## ⚠️ Critical Gotchas (Learned from Testing)

1. **`-c` flag does NOT work** — `browser-harness -c 'print(page_info())'` exits with error. Only heredoc (`<<'PY'`) works on Windows. Always use:
   ```bash
   browser-harness <<'PY'
   print(page_info())
   PY
   ```

2. **Python syntax inside `js()` → SyntaxError** — Code in `js("...")` is JavaScript, not Python. Using Python ternary (`x if cond else y`) or walrus operators will crash:
   ```python
   # ❌ CRASHES — Python ternary in JS context
   js("titles[0] if titles.length > 0 else 'N/A'")
   # ✅ Works — proper JS ternary
   js("titles.length > 0 ? titles[0] : 'N/A'")
   ```

3. **`capture_screenshot()` times out on Windows** — Daemon IPC timeout (`TimeoutError: timed out`). Use `js()` for DOM inspection instead, or skip screenshots entirely. Not a blocker but unreliable.

4. **Dynamic pages need explicit wait** — GitHub, Hacker News and other SPA-heavy sites return empty selectors immediately after `wait_for_load()`. Add `import time; time.sleep(2)` before extraction.

## ⚠️ Known Issues & Workarounds

| Issue | Workaround |
|-------|-----------|
| `capture_screenshot()` times out on Windows (daemon IPC) | Use `js()` for DOM inspection instead, or skip screenshots |
| GitHub/HN return empty selectors after load | Pages use dynamic rendering — add `time.sleep(2)` before extraction |
| Daemon connection errors | Restart Chrome with CDP flag, ensure `BU_CDP_URL` is set |
| **Cloudflare/bot protection blocks built-in browser_*** | ✅ **browser-harness with real Chrome PASSES CF challenges** — use it as primary for protected sites. Add `time.sleep(5)` after navigation to let CF challenge resolve. |

## ⚠️ Cloudflare Bypass (Verified)

Real Chrome via CDP passes Cloudflare "I'm not a robot" challenges that block headless browsers:

```bash
export BU_CDP_URL=http://127.0.0.1:9222 && browser-harness <<'PY'
new_tab("https://cloudflare-protected-site.com")
wait_for_load()
import time; time.sleep(5)  # Let CF challenge resolve
print(page_info())  # Should show actual page, not CF block
PY
```

**Key:** The isolated Chrome profile (`BrowserHarness-Profile`) has full browser fingerprinting that Cloudflare accepts. No special configuration needed — just use real Chrome with CDP.

### ⚠️ Critical: POST Endpoints Blocked at Network Level

Some sites (like `agents.stackoverflow.com`) block POST endpoints at the network/IP level for non-browser clients, even with Chrome impersonation (`curl_cffi`). The ONLY reliable method is executing JavaScript `fetch()` inside real Chrome via CDP:

```bash
export BU_CDP_URL=http://127.0.0.1:9222 && browser-harness <<'PY'
new_tab("https://protected-site.com")
wait_for_load()
import time; time.sleep(5)  # Let CF challenge resolve

# Execute fetch() inside real Chrome context (bypasses network-level blocking!)
result = js("""
fetch('https://protected-site.com/api/endpoint', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({key: 'value'})
}).then(r => r.json())
""")
print(result)
PY
```

**Why this works:** The browser session has already resolved CF challenges and maintains valid cookies/tokens. Direct HTTP clients (even with impersonation) are blocked at the WAF level for POST requests.

See `references/sofa-registration.md` for complete SOFA registration workflow using this technique.

## 🔒 Security Notes

- Connects to your **real browser** — inherits all logins, cookies, extensions
- Never type credentials from screenshots or untrusted sources
- Use isolated profile (`--user-data-dir`) for automation tasks
- Agent will stop and ask you if redirected to login page

## 📊 Performance Tips

- Use `http_get()` + `ThreadPoolExecutor` for bulk static page scraping (249 pages in 2.8s)
- Coordinate clicks (`click_at_xy`) are faster than selector hunts for complex UIs
- Always call `wait_for_load()` after navigation
- Re-screenshot after meaningful actions to verify state

## 🆘 Troubleshooting

```bash
# Check if Chrome is running with CDP
curl -s http://127.0.0.1:9222/json/version

# Run diagnostics
browser-harness --doctor

# Test basic connection
export BU_CDP_URL=http://127.0.0.1:9222
browser-harness <<'PY'
print(page_info())
PY
```

If daemon fails: kill Chrome processes, remove `/tmp/bu-default.sock` (or Windows equivalent), restart Chrome with CDP flag.
