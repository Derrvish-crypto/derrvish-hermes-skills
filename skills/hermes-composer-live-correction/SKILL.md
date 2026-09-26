---
name: hermes-composer-live-correction
description: Live T9-style correction in the Hermes desktop composer.
metadata:
  hermes:
    tags: [desktop, plugins, composer, text-correction, t9]
    category: productivity
    related_skills: [hermes-desktop-plugins]
---

# Composer Live Correction (T9-style)

Class: adding live, smartphone-style text correction / autosuggestion to the
Hermes desktop composer — typos fixed in place on a typing pause, cut-off
last words completed, grammar normalized — via a `desktop-plugins/` plugin
(plain ESM, no build step). General plugin mechanics (import allowlist,
`jsx()` UI, hot-reload) live in `hermes-desktop-plugins`.

Known-good exemplar on this machine:
`%LOCALAPPDATA%\hermes\desktop-plugins\textpolish\plugin.js` (v5: live loop +
middleware + model keep-alive + visible fix indicator, RU/HE/EN) — read it
before writing a new correction plugin rather than starting from scratch.
User's standing requirements: (1) corrections must be accurate — NEVER
degrade quality to cut latency (no fuzzy/offline fallback in place of the
model pass); (2) LIVE in-field correction (while typing, phone-style) is the
PRIMARY mode — on-send correction is only the safety net. Design and verify
against the live path first.

## Architecture (poll → debounce → guard → paint)

1. Poll `host.composer.getDraft(null)` every ~700 ms from `ctx.setInterval`
   (scoped timer — auto-cancels on plugin reload; a raw `setInterval` would
   leak across reloads).
2. Debounce: track last-seen text + last-change timestamp; act only after the
   text has been UNCHANGED for ~1100 ms. The pause is the signal.
3. Race guard: re-read the draft right before painting; if it changed while
   the model ran, abandon and re-arm. Never paint stale text over fresh
   keystrokes.
4. Paint with `host.composer.setDraft(null, fixedText)` — caret lands at the
   end, where the user's caret is after a pause anyway.
5. Keep a `COMPOSER_AREAS.middleware` handler as the send-time safety net
   (`data: { handler: async (draft) => draft }`, awaited, returns modified or
   original draft) — but SKIP the model call when the exact text was already
   fixed within the last ~10 s (fresh-fix cache): zero-latency send after a
   live fix.
6. Skip conditions: empty / < 3 chars, > ~1500 chars (pasted documents), or
   any in-flight state from the plugin's own UI flows.

## Safety guards (accept model output only if ALL hold)

- Char-bigram Jaccard similarity input↔output ≥ ~0.55 ("same text, repaired").
- Output length within [0.4×, 2.5×] of input length.
- Dash-only-change guard: if the ONLY difference is a hyphen/dash/em-dash
  variant, reject — models cosmetically "normalize" dashes and users hate the
  churn.
- Clean-text cache: text the model returned unchanged stays cached ~30 s so
  the polling window doesn't re-call the model.
- Whole handler in try/catch with pass-through: a broken plugin must never
  eat, mutate, or delay the user's message.

## Cut-off-word completion (the "smartphone" behavior)

- System prompt: complete an obviously truncated FINAL word
  (`deploym` → `deployment`, `приве` → `привет`, `я иду в ма` → `я иду в
  магазин`).
- Forbid completing short words (1–2 letters: prepositions, particles,
  pronouns).
- Forbid DELETION when unsure — "if unsure it is truncated, do not add and do
  not delete: leave it as is". Without this clause the model truncates
  ambiguous fragments (drops `שלום ה` to `שלום`) instead of leaving them.
- One prompt handles RU/HE/EN: the model detects the language.

## LLM endpoint (local :1234)

- If the model is a reasoning model (`qwen*-mtp` etc.), send
  `enable_thinking: false` — otherwise it burns `max_tokens` on chain-of-
  thought and returns an empty string. With thinking off: 0.1–0.4 s per call.
- Cold start ≈ 15–17 s on the first request after model start; do not "fix"
  that by shrinking `max_tokens`.
- `temperature: 0`, `max_tokens: 512`.
- **Cold start is the #1 LIVE killer, not the endpoint.** LM Studio/NInfer
  unloads `:1234` after idle; the first live fix after a quiet period pays the
  ~13–17 s model-load, and by the time it answers the user has typed more, so
  the race-guard correctly DROPS the fix. On a phone this never happens because
  the corrector is always hot. Fix: **warm at plugin `register` + a 1-token
  keep-alive ping every ~45 s** (`max_tokens:1`, best-effort, local + free).
  With a warm model a live fix is 0.1–0.4 s and the race-guard almost never
  fires. Verify warmth with two quick `/v1/chat/completions` calls (both should
  be < ~1 s).

## Pitfalls

- **The `steer` path bypasses the composer middleware.** When the main Hermes
  agent is mid-response (busy), the composer routes an Enter press to
  `steerDraft` → `onSteer(text)` instead of `dispatchSubmit` → middleware.
  That redirect **does not run `composer.middleware`** — confirmed in the
  installed bundle: `steerDraft` is `Promise.resolve(h(t))` with no
  `xre(...)` middleware call, while the normal submit is
  `xre({text,attachments})` → `x(r.text)`. So typos sent while the agent is
  answering are NOT on-send-fixed (this is why "отправил с ошибкой, не
  исправилось" reports show no `send:` log line at all — the middleware never
  saw the text). The **live loop is the only fixer that covers the steer
  path**, which is exactly why live is the primary (not just on-send) fix.
  There is no official SDK seam to hook steer — do not try to patch the
  bundle; rely on the live loop + keep-alive so the loop catches the pause
  before Enter.
- `host.composer.submit()` does NOT clear the DOM editor field — the app's
  external submit path clears only the stored draft stash. Any flow that
  ends with an empty field must follow with
  `await host.composer.setDraft(null, '')` + re-`focus()`.
- `console.log` never reaches `desktop.log` (renderer forwarder captures
  level-3/errors only). Proof-of-life and decision lines go through
  `console.error('[<id>] vN …')` with counts/timings only — never message
  content.
- Verify hot-reload headlessly: tail
  `%LOCALAPPDATA%\hermes\logs\desktop.log` for your new marker line with a
  fresh blob URL — no need for the user to confirm.
- **Live fixes are invisible by default.** `setDraft` repaints the field with
  no toast — the user cannot tell the correction landed (so "всё ещё нельзя"
  reports appear even when the loop IS fixing). Add a visible indicator: a
  tiny module-scope pub/sub the live loop calls on a successful paint
  (`notifyLiveFix()`), and a toolbar button that flashes "✓ исправлено" for
  ~1.6 s on the signal. The loop runs at module scope and the Toolbar is a
  separate React component — `ctx` has no shared-channel API, so a
  `Set<fn>` + a `setTimeout` reset in the subscriber is the whole bridge.

## Diagnostics (silent-gate problem)

A poll loop that returns early at many gates (busy, empty draft, debounce,
length bounds, caches) is UNOBSERVABLE from `desktop.log` — every silent
return looks identical to a working loop, so "live doesn't work" reports
have zero signal. Fix: track a `lastPath` string updated at EVERY early
return (`gate(state)`, `typing`, `debounce(412ms)`, `len(0)`, `already-fixed`,
`clean-cache`, `race(changed)`, `FIXED`) and emit one heartbeat line every
~30 ticks (`live: hb ticks=30 path=… live=… busy=…`). One line per ~20 s
proves the scoped timer fires AND shows exactly which gate the loop sits on,
with counts/timings only (never message content). This turned an
undecidable "is it even running?" into a one-grep answer.

## Verification

- Test the model side headless (urllib/curl against the endpoint) BEFORE
  wiring UI: matrix of cut-off words per language, clean texts (must return
  identical), ambiguous fragments (must not be deleted).
- In-app: decision log lines (`send: fixed Nch → Mch (Xms)`,
  `live: fixed …`) in `desktop.log` prove the pipeline fired.
- Interpret `send: unchanged` correctly: it is a SUCCESS on clean text, not a
  failure. Before treating it as a bug, reproduce the exact sent text against
  the model with the plugin's exact system prompt + guard pipeline (similarity
  floor, length ratio, dash guard); if the model returns the text unchanged in
  isolation, the send behaved correctly. Only a text with a REAL error that the
  model leaves unchanged in isolation is a genuine fixer failure.
