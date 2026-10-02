# OSINT-отчёт: анти-зацикливание LLM-агентов
Дата: 2026-09-01 · Канал: osint_cascade_v2.py (SearXNG→DDG) + web_extract + web_search
Цель: собрать подтверждённые практики/исследования для набора правил против зацикливания агента.
Полная версия на диске: `Documents/OSINT_anti_loop_agent_research_20260901.md` (в локальном workspace).

## Главный вывод
**«Безусловно и 100%» через промпт недостижимо.** Все источники сходятся: правила в голове модели — слабейший слой. Надёжность дают **механические стоп-краны в рантайме** (детерминированный код), а не декларативные правила. Ключевая формула: *step-лимиты (max iterations/tokens/time) — это backstop, а НЕ детектор затыка.* Они убивают бесконечный цикл только после того, как бюджет сожжён. Настоящий детектор — **no-progress guard** (повтор идентичного действия без изменения состояния).

## Подтверждение пяти правил пользователя
| Правило | Вердикт источников |
|---|---|
| 1. Fail-Fast (2 попытки) | ✅ для failing/mutating ops; для reads бессмысленно |
| 2. Method Swap | ✅ сильное, обобщить на любой уровень (не только Computer Use) |
| 3. State Delta | ✅ но только для мутаций, дешёвые метрики (PID/сокет/mtime/exit code) |
| 4. Ouroboros Filter | ✅ реализовать **механически** (dedupe), а не поведением |
| 5. Belief vs ground-truth | ✅ один авторитетный замер, не серия |

## Добавления (подтверждены источниками)
- **A. Global step budget на ход** — обязателен, в рантайме (Quaxel #2, OpenAI max-turns, qwen-code round cap ~30).
- **B. Повтор без новой информации = стоп** — самый надёжный детектор. Nexus Core: блокировка redundant call + показ прежнего результата **разрешает ~60% циклов без прочих вмешательств**.
- **C. Checkpoint перед fan-out** — execution checkpoints с полем `information_gained`; false 2 цикла подряд → инъекция «объясни или объяви недосягаемым», 3 подряд → принудительное завершение sub-goal.
- **D. Цикл мышления ≠ цикл действий** — отдельный детектор (Nexus stuck-states, Decoder overthinking).
- **E. Эскалация как первый выход** — preferred over третий слепой метод. Форма: `BLOCKED / Tried / Believes / Question(один) / Default`.

## Два критических находки для данной системы
1. **Qwen3.6-27B (рабочая модель) имеет конкретный баг**: QwenLM issue #150 (пустые tool calls → loop считает задачу готовой), vLLM #50989 (doom loop token 197 в strict mode с no-arg tools), qwen-code #4695 (collapse в repeated identical tool_call **внутри** окна, модель пишет «let me stop this loop» но шлёт тот же вызов — нет client-side circuit breaker). Это объясняет инцидент 68× `rg` — self-reinforcing snowball: каждый повтор добавляет в историю пример «уже вызывал», следующая вероятность collapse выше.
2. **Lossy summarization ПОВТОРЯЕТ циклы**: суммаризатор выбрасывает факт «tool уже вызывали», модель пере-выводит то же действие. Durable fix — компактный **tool-call ledger** (tool, args-hash, terminal flag) в зоне контекста, которую summarization не трогает.

## Архитектура реализации (3 слоя)
1. **Промпт/память** (слабый) — правила как факты в MEMORY + skill `anti-loop-discipline`.
2. **Skill** (средний) — загрузка при высоком риске (Computer Use, gateway, длинные bash) + escalation shape.
3. **Рантайм-гардрейлы** (сильный, единственный близкий к 100%) — hard step-budget, dedupe `(tool,args)` со стопом, auto-signal при нулевой дельте, неуязвимый ledger. Частично уже есть в Hermes (`repeated_exact_failure_warning` count=2) — вопрос, можно ли ужесточить до STOP.

## Источники (ключевые)
- arxiv.org/html/2607.01641v1 — no-progress detection, step budgets.
- particula.tech/blog/stop-ai-agents-looping-same-tool-call-no-progress — redundant-call blocking ≈60% циклов.
- medium.com/@Quaxel/stop-runaway-tool-loops — global step budget как обязательный backstop.
- dev.to/aws/how-to-prevent-ai-agent-reasoning-loops-from-wasting-tokens — reasoning-loop vs action-loop разделение.
- dev.to/siva_kumargowni_327fcd5d/how-we-stopped-infinite-agent-loops — checkpoint + information_gained.
- reddit.com/r/AI_Agents — multiagent infinite-loop debugging (community experience).
- QwenLM issue #150, vLLM #50989, qwen-code #4695 — конкретные баги Qwen-класса.
- Anthropic «Building Effective Agents» / OpenAI «Practical Guide to Building Agents» — max-turns/stop conditions как стандарт.
