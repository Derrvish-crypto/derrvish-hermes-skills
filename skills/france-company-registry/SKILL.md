---
name: france-company-registry
description: "French company registry: SIRET, officers, public emails."
---

# French Company Registry Lookups

Use when asked for a French company's SIRET/SIREN, officers, or public email addresses (due diligence, shipowners, suppliers).

## Procedure

1. **Registry record:** `https://annuaire-entreprises.data.gouv.fr/entreprise/<SIREN>` — legal form, creation date, status, establishment count. Officers: same host, path `/dirigeants/<SIREN>`. Pappers/societe.com pages carry the same data; the gov page is primary.
2. **Second confirmation:** LEI lookup (`lei-lookup.com` records) echoes the SIREN as the registration-authority entity ID — report the SIRET only after two independent sources agree.
3. **Emails:** for shipping/shipowning companies, sector directories publish named contacts with emails and phones (cluster-maritime.fr member listings, rynda.io, magicport.ai, helderline.com). LinkedIn company posts (especially recruiting announcements) are the richest public source of `@domain` addresses. Search patterns: `"@<domain>"`, `"people@<domain>"`, `"Orion Global Transport" email`.
4. **Verify domains before citing:** search the bare domain to confirm it belongs to the same legal entity and country, and check it resolves (not a parking page) before calling it the company website.

## Pitfalls

- **Lead-gen aggregator email-format pages (Prospeo, RocketReach) misattribute domains** by similar company name — one listed a Polish hydraulic firm's domain under a French LNG operator. Never report a domain from such a page without the ownership verification in step 4.
- **Report SIRET vs SIRET distinction:** SIREN = legal entity (9 digits); SIRET adds the establishment suffix (14 digits). State which one was found and which establishment it covers.
- Parked/dead domain ≠ no website; the company may operate without one (LinkedIn only). Say so explicitly instead of guessing a new domain.
