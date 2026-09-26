# russian-law-mcp — server, document IDs, API quirks

Server: `https://russian-law-mcp.fly.dev/mcp` — stateless streamable-HTTP MCP, ~12k+ laws, source pravo.gov.ru. Re-confirm the currency date from the server at list time; never hardcode it as a fact.

## Tools (as of the 2026 citation sweeps)
- `get_provision(document_id, provision_ref)` — workhorse for norm text.
- `search_legislation` — full-text search across all laws; use it to re-derive a `document_id` when a cached ID doesn't resolve or returns off-topic content.
- `validate_citation` — exists (citation enforcer) but its parameter format is unverified — do not build flows on it; `get_provision` is the reliable path.

## get_provision quirks
- `provision_ref` = numeric string, **WITHOUT the dot**: 39.5 → `"395"`, 55.32 → `"5532"`.
- The parameter is `document_id`. Passing `code:` (or similar) yields a ~1.5KB null response that looks like «article missing» — it is a parameter error, not a missing norm.
- `content` may come back as a dict, not a string — normalize before substring matching.
- Transient nulls / empty content happen (more often on multi-part codes) — retry once before concluding absence.

## Verified document IDs (2026 sweep)
| Code | ID | Note |
|---|---|---|
| ГК РФ, часть 1 | `gk-rf-1` | |
| ГК РФ, часть 2 | `gk-rf-2` | |
| ГрК РФ (current edition) | `gradk-rf` | post-renumbering article numbers |
| ГрК 190-ФЗ (old edition) | `fz-190-2004` | facts under pre-renumbering citations |
| ГПК РФ | `fz-138-2002` | `gpk-rf` = repealed ID → null, do NOT use |
| ЗК РФ | `zk-rf` | |
| ВК РФ 2006 | `fz-74-2006` | `fz-167-1995` (ВК 1995) = repealed, do NOT use |
| ФЗ-101 (1994) | `fz-101-1994` | does NOT resolve as ГК ч.1 — never use as a Civil Code ID |
| ФЗ-229 (2007, об исполнительном производстве) | `fz-229-2007` | ст. 112 (исполнительский сбор) fetched OK in 2026; fee rates change by amendment — re-fetch before citing |

АПК РФ (220-2015): no verified ID in this table — re-derive via `search_legislation` or fall back to consultant.ru.

If an ID returns null or off-topic content: stop trusting it for the rest of the sweep — re-derive via `search_legislation` and re-verify the first citation of that code.
