# Derrvish Hermes Skills Tap

A curated [Hermes Agent](https://hermes-agent.nousresearch.com) skills tap: 20
battle-tested skills, published from real daily operation.

## Install

```bash
hermes skills tap add Derrvish-crypto/derrvish-hermes-skills
hermes skills search <query> --source github   # tap skills appear in the github source
hermes skills install Derrvish-crypto/derrvish-hermes-skills/<skill-name>
```

You can also install any single skill without subscribing:

```bash
hermes skills install Derrvish-crypto/derrvish-hermes-skills/problem-solving-protocol
```

## Skills

| Skill | What it does |
|---|---|
| `problem-solving-protocol` | Structured troubleshooting: diagnose → audit → isolate. No blind trial-and-error. |
| `verification-before-completion` | Never claim "done" without real, verified evidence. |
| `writing-plans` | Turn a spec/requirements into a markdown implementation plan. |
| `executing-plans` | Execute a written plan in a separate session, task by task. |
| `brainstorming` | Mandatory exploration phase before any creative/project work. |
| `code-review` | Review changes for security, performance, and correctness. |
| `receiving-code-review` | Handle review feedback properly before implementing. |
| `dispatching-parallel-agents` | Fan out 2+ independent tasks to parallel subagents. |
| `using-git-worktrees` | Isolate feature work with git worktrees. |
| `product-research-comparison` | Multi-criteria product research with spec verification. |
| `france-company-registry` | French company registry lookups: SIREN/SIRET, officers, public emails. |
| `russian-law-verification` | Verify legal citations in Russian-language legal documents. |
| `json-canvas` | Create and edit Obsidian JSON Canvas files. |
| `obsidian-markdown` | Obsidian-flavored markdown: wikilinks, embeds, callouts, properties. |
| `leaflet-route-map` | Route maps with real roads and stops (OSRM/OSM). |
| `drawio-skill` | Create, edit, test and publish editable draw.io diagrams. *Third-party: © Agents365-ai, MIT — see `skills/drawio-skill/LICENSE`.* |
| `feedback-loop` | Lightweight user-preference learning: capture corrections and preferences. |
| `hermes-desktop-plugins` | Write desktop plugins that add UI panes, statusbar chips, composer middleware — plain ESM, no build step. |
| `hermes-composer-live-correction` | Live T9-style text correction in the desktop composer: typos fixed in-place on a typing pause, RU/עברית/EN. Hard-won pitfalls: cold-start keep-alive, steer-path bypass, guard filters. Pairs with `hermes-desktop-plugins`. |
| `writing-skills` | Author correct SKILL.md files and verify they work. |

## Layout

```
skills/
└── <skill-name>/
    ├── SKILL.md          # required
    ├── references/       # optional supporting docs
    ├── scripts/          # optional scripts
    └── data/             # optional data files
```

## Provenance & licensing

- Skills marked otherwise are original work, released under MIT.
- `drawio-skill` is third-party (MIT, © Agents365-ai) and is redistributed
  here with attribution intact.

## Updates

Skills in this tap are updated by the author; after a change, run
`hermes skills check` / `hermes skills update` to pull the new versions.
