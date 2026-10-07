# Flipwert Buyback Comparison v1

## Product goal

Flipwert should compare two different exit paths after a deal check:

1. **Private-market resale** — expected resale value based on trustworthy market evidence.
2. **Instant buyback** — current indicative purchase offers from buyback portals for the matched product and condition.

This turns a deal result into an actionable choice: higher expected margin with more selling effort versus a faster, simpler exit through a buyback provider.

## Normalized condition model

Providers use different condition vocabularies. Flipwert must not compare provider prices until the provider-specific state has been mapped to a common condition.

Canonical states:

- `new_sealed` — new / factory sealed / OVP sealed
- `like_new` — no visible wear, fully functional
- `very_good` — light wear, fully functional
- `used_good` — normal visible wear, fully functional
- `acceptable` — heavier wear but functional
- `defective` — functional defect or provider-defined defective state

Every provider adapter owns its own mapping. If a provider condition cannot be mapped with sufficient confidence, the offer must be marked `condition_uncertain` and excluded from automatic best-offer claims.

## Normalized buyback offer

A backend/partner adapter should return normalized records such as:

```json
{
  "provider_id": "example-buyback",
  "provider_name": "Example Buyback",
  "product_id": "provider-product-id",
  "matched_title": "Apple iPhone 15 Pro 256 GB",
  "condition": "like_new",
  "price": 620.00,
  "mandatory_deductions_eur": 0.00,
  "currency": "EUR",
  "offer_url": "https://example.com/...",
  "checked_at": "2026-09-16T08:30:00+02:00",
  "price_kind": "indicative_buyback",
  "requires_inspection": true,
  "match_confidence": 0.98,
  "affiliate_link": false
}
```

Required fields: provider, matched product, normalized condition, numeric listed
price, numeric mandatory deductions (explicitly `0` when none apply), currency,
destination URL, timestamp and price kind. Numeric strings are rejected so an
adapter cannot silently pass through an unvalidated or locale-formatted amount.
EUR price and deduction fields must be exact cent amounts with no fractional
cents. Net payout is calculated by subtracting integer cents; values with more
than two decimal places are rejected instead of being silently rounded.

## Trust rules

- Never mix asking prices, sold-market evidence and buyback offers into one unlabeled number.
- A buyback price is an **indicative exit price**, not guaranteed profit. Providers may inspect the item and revise/reject an offer.
- Display when the price was checked.
- Product identity must include relevant variants where available (storage, model generation, network/version, color only where price-relevant).
- Numeric model tokens and named variants are hard constraints across product
  categories. Common spelling aliases such as `S24+`/`S24 Plus` and
  `PlayStation 5`/`PS5` are normalized before comparison. Xbox Series X/S and
  Xbox One X/S remain distinct named hardware variants even though their final
  model marker is only one character.
- Only compare offers with compatible normalized conditions.
- Visible damage and failure wording is checked independently of the
  provider's structured condition. Compound phrases such as `Wasser Schaden`,
  `ohne Funktion`, `startet nicht` or `no power` cannot enter a functional
  condition comparison.
- A provider response may contain a full condition matrix, but the server only
  returns rows for the exact condition requested by the user. The app repeats
  this filter as a defensive boundary before display and comparison.
- Low-confidence product matches must not participate in `best buyback` calculations.
- Price-defining watch case sizes must match exactly; a standard watch search
  without its size is not eligible for a LIVE quote. Named Ultra models may
  use their inherent single case size.
- Labelled hardware screen size and explicitly labelled RAM must match exactly.
  A query that omits either dimension cannot inherit a provider SKU's more
  specific LIVE price; release years and storage remain separate dimensions.
- The server checks provider titles against manufacturer, model, variant and
  storage before accepting provider-reported match confidence. A conflicting
  manufacturer is rejected; omission is allowed only where an exclusive family
  such as iPhone, Galaxy or Pixel establishes it unambiguously. Barcode-only
  searches require the provider to return a matching EAN/GTIN; ambiguous or
  broad searches yield no comparable price.
- Missing data is shown as unavailable, never estimated as if it were a live provider quote.
- A successful partner response must be either an item array or an object with
  an item array. Malformed and unexpectedly oversized payloads are treated as
  provider outages and are never cached as a valid zero-offer result.
- Every offer must state all mandatory deductions explicitly, including a
  numeric zero when none apply. Flipwert compares and calculates profit from
  the resulting net cash payout, never from a gross headline amount.
- A new search invalidates an in-flight buyback request and rechecks the selected condition for the new product, so a late response cannot be attached to another deal.
- Provider credentials, partner tokens and feed secrets stay server-side.
- Every provider approval is bound to explicit feed hosts and offer-link hosts.
  It also binds the provider ID to the approved visible provider name. A valid
  provider ID alone cannot authorize another brand, data from another feed or
  redirect users to an unapproved destination. The approval also sets a maximum
  server-side cache duration; zero disables caching for the shared feed.
- Affiliate/advertising links require a separate explicit provider approval.
  A feed item marked `affiliate_link: true` is discarded unless that right is
  current; accepted commercial links are labelled visibly in the app.
- A rights-approved feed remains pre-activation until a representative matrix
  of at least three unique cases, two products and two conditions succeeds. A
  single diagnostic probe cannot issue an activation fingerprint. The
  resulting configuration fingerprint is bound to the exact source URL,
  approval references, validity dates, approved hosts, affiliate rights and
  cache limits;
  any change disables LIVE prices until the matrix is rerun and deliberately
  reactivated.
- Repeated identical product/condition requests are coalesced and may use a
  short server-side cache within the lowest current provider limit and the
  server's stricter configured limit. An outage is never
  cached as a valid empty result, and cached quotes never outlive their explicit
  offer expiry, the normal freshness limit or the provider approval.
- If an approved feed returns multiple snapshots for the same provider,
  product and condition, the newest checked timestamp is authoritative even
  when its payout is lower. Conflicting rows with the same timestamp use the
  lower net payout so Flipwert cannot inflate expected proceeds.

## Provider integration priority

Use, in order:

1. official API or documented partner API;
2. official affiliate/partner/product feed that permits price-comparison use;
3. explicit provider cooperation / Flipwert adapter;
4. official search/deep link as a fallback without claiming an in-app live price.

Do not make fragile scraping a core dependency without an explicit technical/legal review.

Initial providers to investigate include reBuy, ZOXS and Clevertronic. They publicly operate condition-dependent electronics buyback flows; ZOXS and Clevertronic also advertise partner/affiliate programs. Availability of an affiliate program alone does **not** imply permission or an API for ingesting live buyback prices, so each integration must be verified separately before enabling live quotes.

## Deal-result UX

The result should eventually expose:

- `Private sale`: expected market value and estimated net margin.
- `Instant buyback`: highest eligible current indicative offer and estimated margin versus the user's purchase price.
- `Compare offers`: provider list, condition, checked time and important inspection caveat.

The provider list and offer links can be opened without a private-market valuation. Only the private-versus-instant profit recommendation needs a reliable private-market value. The selected buyback condition is rechecked after a new product search.

The primary deal verdict should remain understandable even if no buyback provider is available.

If no approved feed is available, the user may open an official provider page
and manually enter the quote shown there. Flipwert may calculate the local
margin from that user-entered value, but must label it as a manual user entry,
must not call it LIVE or verified, and must preserve this provenance in saved
deal snapshots. A later verified feed quote must not silently turn a previous
manual value into historical LIVE evidence.

Deal alerts may compare a saved buyback margin with a later quote only when
both values originate from the validated LIVE-provider path. A manual user
entry must never trigger a LIVE buyback alert. The alert UI labels this signal
separately from private-market profit and continues to require a fresh,
eligible exact-condition offer.

## Free / Pro direction

Do not lock the basic usefulness of a deal check behind Pro. A possible later split, to validate with real usage data:

- Free: private-market valuation plus existence/range of instant-buyback options.
- Pro: full provider comparison, condition-by-condition comparison, buyback price history, automatic rechecks and price alerts.

This is a product hypothesis, not a final paywall decision.

## Implementation phases

1. Add normalized buyback condition/offer models and fixtures independent of providers.
2. Add backend adapter contract and validation, including timestamps and confidence.
3. Implement one provider only after its permitted data-access path is verified.
4. Add the buyback block to deal results without changing existing market valuation semantics.
5. Add rechecks/history and then evaluate Pro gating.
