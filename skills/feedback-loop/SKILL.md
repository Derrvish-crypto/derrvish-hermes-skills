---
name: feedback-loop
description: Lightweight user preference learning system — captures corrections, ratings, and patterns after complex tasks to improve future responses.
triggers:
  - task completion with 5+ tool calls
  - user correction or complaint
  - explicit rating request
  - pattern detection in conversations
---

# Feedback Loop System

## Purpose
Capture user preferences, corrections, and quality signals to improve response accuracy over time without annoying the user.

## When to Ask
- **After complex tasks** (5+ tool calls): Single brief question
- **After user correction**: Immediately acknowledge + save pattern
- **NOT after every response**: Avoids annoyance

## Question Format (Russian)
```
Оценка 1-5? Что улучшить в следующий раз?
```

Keep it optional — user can skip or give brief feedback.

## Response Quality Standard (User Preference)
When the user asks for analysis, recommendations, or technical explanations:
- **Provide detailed, argumented responses** — not superficial summaries
- Include **analysis with reasoning** ("почему" и "какие последствия"), not just conclusions
- Support claims with **evidence, comparisons, or trade-offs**
- Deliver **clear conclusions** backed by the preceding analysis
- Avoid shallow lists without context — every point should have justification

## What to Save to Memory
### DO save:
- Format preferences ("плотные списки вместо таблиц")
- Tone/style corrections ("меньше эмодзи", "техничнее")
- Tool usage patterns ("не предлагай alternatives без запроса")
- Domain-specific preferences ("код с комментариями на русском")
- Response depth preferences (user wants detailed analysis, not superficial summaries)

### DO NOT save:
- Task progress or session state
- Temporary data (PR numbers, commit SHAs)
- One-off requests that aren't patterns
- Anything >1 week old unless confirmed recurring

### Workflow constraints to remember (not skills):
- User is against fine-tuning models — prefers adapting through prompts/context rather than modifying weights. Do NOT suggest QLoRA/fine-tune pipelines unless user explicitly asks.

## Memory Entry Format
Declarative facts, not instructions:
```
✓ "Предпочитает плотные списки с кликабельными ссылками"
✗ "Всегда используй плотные списки"
```

## Pattern Detection
Track these signals automatically:
- User rejects suggested approach → save preference for alternative
- User asks to redo in different format → save format preference
- User praises specific style → reinforce pattern
- Repeated corrections on same topic → high priority memory update

## Integration with Existing Systems
- **Memory**: Store preferences as declarative facts
- **Skills**: Update skill instructions if correction affects workflow
- **Session Search**: Use for context when similar tasks recur

## Example Workflow
1. Complete complex task (e.g., generate report)
2. Ask: "Оценка 1-5? Что улучшить?"
3. User responds: "4, но без эмодзи в заголовках"
4. Save to memory: "Не хочет эмодзи в заголовках отчётов"
5. Next similar task: Apply preference automatically

## Response Quality Standards (User-Specific)
- **Depth over brevity**: User requires detailed, well-reasoned responses with analysis and conclusions — not surface-level summaries. Every technical answer should include "why" and "what are the consequences," not just "what."
- **Format**: Tables + clear structure + emoji status markers (✅/❌) for reports. Dense lists with clickable links for digests.
- When in doubt between a short answer and a detailed one, choose detailed — user explicitly rated 5/5 on this approach but asked for more depth.

## Anti-Patterns (Avoid)
- Asking for feedback after simple tasks (<3 tool calls)
- Saving temporary state as permanent preference
- Over-collecting — max 1-2 memory updates per session
- Ignoring explicit user corrections to save "cleaner" data
