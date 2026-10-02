---
name: spec-kit-workflow
description: "Use for large features: spec, plan, tasks pipeline."
version: 1.0.0
---

# Spec Kit Workflow (spec → plan → tasks)

Formal specification-driven development using GitHub's Spec Kit templates.
Use for features with 3+ files, cross-cutting concerns, or multi-session work.
Skip for single-file scripts or quick fixes — use `writing-plans` instead.

## When to Use

- New feature touching 3+ files
- Multi-session project (will span multiple conversations)
- Complex system design (architecture decisions needed)
- User says "let's spec this out" or "plan it properly"

## Template Location

```
%USERPROFILE%\Documents\tools\spec-kit\templates\
├── spec-template.md      # Feature specification
├── plan-template.md      # Implementation plan
├── tasks-template.md     # Task breakdown
├── checklist-template.md # Verification checklist
└── constitution-template.md  # Project principles
```

## Workflow

### Phase 1: Specify (spec.md)

1. Read the template: `read_file("%USERPROFILE%\Documents\tools\spec-kit/templates/spec-template.md")`
2. Fill in:
   - **Feature name** and branch name
   - **User stories** (P1, P2, P3) — each independently testable
   - **Acceptance scenarios** (Given/When/Then)
   - **Functional requirements** (FR-1, FR-2, ...)
   - **Non-functional requirements** (NFR-1, NFR-2, ...)
   - **Out of scope** (explicitly list what we're NOT doing)
3. Save to: `%USERPROFILE%\Documents\<project>\specs\<feature-name>\spec.md`
4. Present to user for approval BEFORE proceeding

### Phase 2: Plan (plan.md)

1. Read the template: `read_file("%USERPROFILE%\Documents\tools\spec-kit/templates/plan-template.md")`
2. Fill in:
   - **Technical context**: language, dependencies, storage, testing, platform
   - **Constitution check**: does this align with project principles?
   - **Project structure**: which files will be created/modified
   - **Phases**: break into research → design → implementation
   - **Risks**: what could go wrong, mitigation strategies
3. Save to: `%USERPROFILE%\Documents\<project>\specs\<feature-name>\plan.md`
4. Present to user for approval

### Phase 3: Tasks (tasks.md)

1. Read the template: `read_file("%USERPROFILE%\Documents\tools\spec-kit/templates/tasks-template.md")`
2. Break plan into bite-sized tasks:
   - Each task = one action (2-5 minutes)
   - Each task ends with an independently testable deliverable
   - Mark dependencies between tasks
   - Estimate effort (S/M/L)
3. Save to: `%USERPROFILE%\Documents\<project>\specs\<feature-name>\tasks.md`
4. Execute tasks using `executing-plans` skill

### Phase 4: Verify (checklist.md)

1. Read the template: `read_file("%USERPROFILE%\Documents\tools\spec-kit/templates/checklist-template.md")`
2. After implementation, walk through the checklist
3. All items must pass before declaring done

## Integration with Existing Skills

| Phase | Skill |
|-------|-------|
| Brainstorm | `brainstorming` |
| Specify | This skill (Phase 1) |
| Plan | This skill (Phase 2) + `writing-plans` |
| Tasks | This skill (Phase 3) |
| Execute | `executing-plans` |
| TDD | `test-driven-development` |
| Debug | `systematic-debugging` |
| Review | `requesting-code-review` / `receiving-code-review` |
| Verify | `verification-before-completion` |

## Pitfalls

- **Don't skip user approval** between phases — spec without sign-off leads to rework
- **Don't over-specify** small features — if it's 1 file, use `writing-plans` directly
- **Templates are guides, not gospel** — adapt sections to the actual project
- **Keep specs living** — update spec.md if requirements change mid-implementation
- **Branch naming**: use `[###-feature-name]` format for traceability

## Quick Start (one-liner)

For a new feature, say: "Let's spec this out" — I'll create the spec directory,
fill in the template, and present it for your approval before any code is written.