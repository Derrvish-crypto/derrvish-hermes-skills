---
name: russian-law-verification
description: "Use when verifying citations in Russian legal documents."
metadata:
  hermes:
    tags: [legal, russian, verification, mcp, citations]
    category: legal
    related_skills: [legal-document-humanization]
---

# Russian Statutory Citation Verification

User's iron rule for legal documents (иски, возражения, экспертные заключения, отзывы): **every cited norm of RF legislation is verified against the primary source via the russian-law-mcp server — never from memory and never from the document's own wording.** A document citing an article is not a source for what that article says.

## Procedure

1. **Extract the citation set.** Regex-sweep the document for «ст. N», «п. N», «пп. N», «ст. N п. M пп. K», code abbreviations (ГК, ГрК, ЗК, ГПК, ВК, АПК, НК) and ФЗ numbers. Deduplicate into a (code, article, point) list — that is the sweep unit. A 200k-char document yields 50–70 unique norms; verify ALL of them, not a sample. Count occurrences of each — systematic errors repeat the same wrong citation 10–20×.
2. **Resolve each code to a `document_id`** — see `references/mcp-docids.md` (verified mapping + re-derivation). If an ID returns null or off-topic content, the ID is stale/wrong: re-derive it with `search_legislation` (full-text search over all laws). Never trust an ID cached from a prior session — re-check the FIRST citation of each code in the current sweep.
3. **Fetch each norm: `get_provision(document_id=..., provision_ref=...)`.** Quirks (reference file): `provision_ref` is a numeric string WITHOUT the dot (39.5 → "395"); the parameter is `document_id`, not `code:` (wrong name → null response that looks like "article missing"); `content` may be a dict — normalize before matching; transient nulls happen — retry once before declaring absence.
4. **Match the fetched text against the document's usage** — subject matter, not verbatim (documents paraphrase). Verdicts: OK (exists and fits the usage) / mismatch (wrong article or wrong code) / repealed (find the successor norm + repealing act) / absent (go to step 5).
5. **"Absent" gets a three-way check — absence in one code ≠ non-existent norm:**
   a. **Wrong code in the citation.** The article may exist in a sibling code: a «ст. 55.32 ГК» absent from the Civil Code but present as ГрК 55.32 = a code-mixup error in the filing, while the norm itself exists. Check adjacent codes before declaring «норма отсутствует».
   b. **Old edition.** Case facts are governed by the edition in force at the fact date; article numbering shifts between editions. Verify against the old-edition ID (e.g. ГрК 190-ФЗ) and report the mapping to the current edition (old «ст. 51 п. 17» building-permit exceptions vs the current-edition numbering).
   c. **Repealed.** A repealed article: name the repealing act + the current successor norm.
6. **Patch the document, don't rewrite it.** A systematic error (same wrong citation ×N) = one targeted old→new patch pattern repeated for every occurrence, uniqueness-guarded. Every fix anchors to the verbatim primary-source text fetched in step 3. **Nested-substitution guard:** when the replacement text itself contains a substring of the old pattern (typical: a fix note like `ст. 35 ЗК РФ (ст. 36 ЗК утратила силу с 23.06.2014 — 171-ФЗ)` still carries `ст. 36 ЗК`), repeated or overlapping application nests it: `... (ст. 35 ЗК РФ (ст. 35 ЗК РФ (ст. 36 ЗК ...)))`. Apply each old→new exactly once (assert `md.count(old) == expected` before the replace); after ALL patches: (a) regex-check for double nesting `РФ\s*\(ст\.` = 0; (b) verify remaining old-article occurrences with a negative lookahead that excludes the fix note (e.g. `ст\.\s*36\s*ЗК(?!\s*утратила силу)`) so the note is not counted as an error — a spot check cannot see the nesting, only the two regex passes do.
7. **Report.** Per-citation ✅/❌ table with the verbatim primary-source text + a discrepancy table (document's claim → primary source → fix applied). The user wants ✅/❌ verdicts, not a process narrative.

## Pitfalls

- **Article numbering shifts between editions — pin the document_id before trusting the article number.** The current (2026-era) Urban Planning Code renumbered articles: an article that in the old 190-ФЗ carried the building-permit exceptions (гараж/малоэтажка без разрешения) is a different article now (current ст. 51 = публичные слушания). A number-only check silently passes a wrong article.
- **The sweep is the safety net, not spot-checking.** Filings contain SYSTEMATIC citation errors — one wrong article repeated 10–20× (repealed-code article cited as current). Verifying the first occurrence and extrapolating misses the pattern; count occurrences first, then verify one per unique norm.
- **A not-found citation is not necessarily a non-existent norm** — run the three-way check (wrong code / old edition / repealed) before reporting «отсутствует».
- **Never quote the norm from the document's own text in the report** — the document may paraphrase or misquote; the quoted text must come from the MCP fetch.
- **Don't silently swap editions in a citation.** Facts under an old edition cite the old article + a note on the current mapping; never silently replace the number with the current-edition one.
