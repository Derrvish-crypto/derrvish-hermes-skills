---
name: product-research-comparison
description: Multi-criteria product research, specification verification, and comparative analysis across online retailers (primarily Amazon).
---

# Product Research & Comparison

Multi-criteria product research, specification verification, and comparative analysis across online retailers (primarily Amazon).

## Triggers

- User asks to compare products by specific criteria (features, price, specs)
- "Find me a product that has X, Y, Z features"
- Product recommendation requests with budget constraints
- "Check this Amazon link and tell me if it meets my requirements"
- "Где купить X / find me a specific reliable seller" — seller discovery with live prices + reliability signals (marketplace seller verification below)

## Workflow

### Phase 1: Discovery

1. `web_search` for candidate products matching criteria
2. Extract ASINs, model numbers, prices from search results
3. Build initial candidate list (5-8 models)

### Phase 2: Deep Verification (per product)

**Amazon pages — use this extraction chain:**

1. Try `web_extract(url)` first - fast but often fails on Amazon
2. **Fallback:** `browser_navigate(url)` -> `browser_snapshot(full=true)` -> read the cached snapshot file for full content
3. Read product details section: model number, ASIN, dimensions, ratings, reviews count
4. Check color options and per-color pricing
5. Read "Product description" tabs/features (click expandable sections)
6. Scan customer reviews for real-world issues (noise level, build quality, missing features)

**Official manufacturer sites:**

- `web_extract` on official product pages for authoritative specs
- Cross-reference Amazon claims vs manufacturer claims - discrepancies are red flags

### Phase 3: Comparison Matrix

Build a comparison table with columns:

| Model | [Each user criterion] | Price | Rating | Verdict |

Mark each cell ✅ / ❌ / ⚠️ against user's stated requirements.

### Phase 4: Verdict

1. Rank candidates by how many criteria they satisfy
2. Flag "combo products" that bundle unrelated items (e.g., flosser + toothbrush) - these often compromise on core features
3. Recommend the best single product OR a combo solution if no single product meets all criteria

### Marketplace seller verification (AliExpress & similar)

When candidates are third-party sellers on a marketplace:

1. **Search result pages lazy-render — never trust them.** `document.body.innerText` on a marketplace search page often contains only the footer (~1KB) even when products exist. Collect candidate item IDs from `a[href*="/item/"]` hrefs, then open each item page directly (`/item/<id>.html`) — item pages render fully.
2. **Seller identity chain:** on the item page find the `a[href*="/store/<id>"]` link → store ID. On the store page `meta[property="og:title"]` = store name; store page body shows positive-feedback % + followers. Item pages also show "X% positive feedback" directly.
3. **Prices are localized** to the site locale (he.aliexpress.com shows ₪): first price = sale price, "save" line = discount; flash sales carry an expiry date — record it in the table.
4. **Verify exact variant/series in the SKU before recommending:** listings frequently bundle multiple series/sizes (e.g. ink "664 672 673 674" in one listing). Confirm the wanted series/size exists in the SKU labels and body text, and tell the user which exact SKU to pick at checkout.
5. **Shipping cost:** destination shipping usually requires an address entry / login. If it cannot be retrieved, report "shipping is calculated at checkout with address" — never invent a number.

For ink/toner series identification and the original-vs-compatible capacity trap, see `references/printer-ink-procurement.md`.

## Pitfalls

### Amazon extraction failures

`web_extract` frequently returns empty or errors on Amazon product pages. **Always fall back to browser_navigate -> browser_snapshot.** The snapshot is cached to disk - use `read_file` on the cache path for full content when truncated.

### Combo-product traps

Products marketed as "2-in-1" or "combo kit" often:

- Have fewer accessories than dedicated products (e.g., 6 tips vs 13)
- Smaller tanks to fit both devices in one package
- Missing premium features (UV sterilization, heating) that exist in the brand's standalone models
- **Always check if the same brand has a dedicated model with better specs**

### Spec verification gaps

- "Whisper quiet" != measured decibel rating - search reviews for actual dB mentions
- "UV sterilization" claims: verify it's UV-C (254nm), not just blue LED light
- Color availability varies by region - check the specific Amazon marketplace
- Battery life claims are lab conditions; real-world is ~60%

### Review analysis

- Read 3-star reviews for balanced pros/cons
- Look for patterns: "tip popped off", "needs to be held upright", "battery died after X months"
- Ignore verified purchase badges - focus on review content quality and date recency

## Output Format

1. Full spec table per product (all criteria)
2. Comparison matrix ✅/❌/⚠️
3. Clear verdict with reasoning
4. Price + shipping calculation to user's location if applicable
5. Alternative combo recommendation if no single product meets all criteria
6. **Seller requests need named rows:** when the user asks "найди конкретных надёжных продавцов", every table row must be a NAMED seller — store name, store URL, item URL, live price (verified that day), feedback %, sales/follower count. Ending with generic advice ("check seller ratings before paying") is a substitute for the work, not the answer — the user's ask IS the verification.
