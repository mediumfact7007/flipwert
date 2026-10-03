# Flipwert API v0.6

This tiny Node.js service keeps marketplace credentials out of the mobile app and normalizes live price results for Flipwert.

## What is live

- **eBay DE:** official eBay Browse API, active listings only. These are current offers, **not verified sold prices**.
- **Amazon DE:** Keepa Product API for ASIN / EAN / UPC lookups. Germany uses Keepa domain `3`. The adapter requests live offers.
- **Kleinanzeigen, MediaMarkt, SATURN, idealo, rebuy, Back Market:** remain official website searches until an approved API/feed/partner adapter is available.
- **Kleinanzeigen shared listings:** the app opens the original listing and asks the user to enter its price; the retired `/v1/listing/resolve` route returns HTTP 410 without requesting third-party pages.

## One-time deployment

Recommended simple route: deploy the `server` folder as a Node.js service (for example Railway). Start command:

```bash
node index.js
```

Set environment variables in the hosting dashboard, never in the Flutter app or Git. Start with Sandbox explicitly:

```text
EBAY_ENV=sandbox
EBAY_CLIENT_ID=...
EBAY_CLIENT_SECRET=...
KEEPA_API_KEY=...
```

`EBAY_CLIENT_ID` is the eBay **App ID / Client ID** and `EBAY_CLIENT_SECRET` is the **Cert ID / Client Secret**. The eBay **Dev ID is not used** by this OAuth client-credentials flow.

Flipwert treats every value other than the exact string `production` as Sandbox. Only switch to:

```text
EBAY_ENV=production
```

after a separate Production keyset exists and the live deployment has been intentionally approved. Do not reuse Sandbox credentials for Production. The `/health` and `/v1/status` endpoints expose the active eBay environment so a deployment can be verified without revealing credentials.

The current Android build workflow does not need eBay credentials because the mobile app never receives the Client Secret; marketplace credentials belong on the server deployment only.

`PORT` is normally provided automatically by the host.

### Approved buyback partner feed

The buyback endpoint is deliberately disabled until an approved partner feed
or adapter is available. After provider approval, configure the adapter only on
the server:

```text
BUYBACK_SOURCE_URL=https://partner-adapter.example/quotes
BUYBACK_SOURCE_TOKEN=...
BUYBACK_SOURCE_TIMEOUT_MS=6000
BUYBACK_SOURCE_CACHE_TTL_MS=60000
BUYBACK_SOURCE_POLICY_ACK=approved-feed-and-price-display-v1
BUYBACK_SOURCE_ACTIVATION_FINGERPRINT=
BUYBACK_SOURCE_APPROVALS_JSON=[{"provider_id":"zoxs","provider_name":"ZOXS","approval_reference":"internal-contract-reference","reviewed_at":"2026-09-24T00:00:00Z","valid_until":"2027-12-31T23:59:59Z","feed_access":true,"price_display":true,"offer_links":true,"provider_identity_display":true,"feed_hosts":["partner-adapter.example"],"offer_hosts":["www.zoxs.de"]}]
```

The adapter must return the normalized fields documented in
`docs/BUYBACK_INTEGRATION.md`, including a current timestamp, exact product and
condition identity, EUR price, confidence and HTTPS offer URL. Affiliate or
deep-link access alone is not permission to scrape or republish prices.
The backend fails closed unless the exact policy acknowledgement and at least one
current per-provider approval record are present. Each record separately confirms
feed access, price display, offer links and provider-identity display, and binds
the provider ID to the exact visible provider name, with an
internal approval reference, reviewed/expiry timestamps, exact adapter/feed
hosts and exact permitted offer-link hosts. Feed rows for other, expired or
partially approved providers are discarded even if the adapter returns them.
Use `docs/buyback-source-approval.example.json` as the non-secret template.
The public `/v1/status` response exposes a `readiness` reason such as
`missing_policy_ack`, `source_host_not_approved`,
`missing_or_stale_validation` or `ready` without revealing credentials or
internal contract references. Rights approval alone does not activate LIVE
prices: the exact current source URL and provider-rights configuration must
also match a successful representative validation fingerprint. Renew or disable each record before its configured expiry; never use these
flags as a substitute for the underlying written rights. Keep this JSON and all
credentials in deployment configuration, not in the APK or repository.

For diagnostics, one exact product/condition probe can be run from the
deployed server environment. A single probe never returns an activation
fingerprint and cannot activate LIVE prices:

```bash
BUYBACK_VERIFY_QUERY="Apple iPhone 15 Pro 256 GB" \\
BUYBACK_VERIFY_CONDITION="like_new" npm run verify:buyback-source
```

Provider activation requires a representative matrix with at least three
unique cases, two distinct products and two distinct conditions. Cover further
models and storage/connectivity variants whenever the approved feed contains
them:

```bash
BUYBACK_VERIFY_CASES_JSON='[
  {"query":"Apple iPhone 15 Pro 256 GB","condition":"like_new"},
  {"query":"Samsung Galaxy S24 Ultra 512 GB","condition":"used_good"},
  {"query":"Apple iPad Air M2 256 GB Wi-Fi","condition":"very_good"}
]' npm run verify:buyback-source
```

The matrix is limited to 20 cases, rejects duplicate or insufficient coverage,
runs sequentially to respect partner limits and fails closed when any case has
no fresh exact-condition offer. Output
identifies only the failing case index and reason; it never prints the query,
price, destination URL, token or approval reference.

Leave `BUYBACK_SOURCE_ACTIVATION_FINGERPRINT` empty for this pre-activation
probe. A successful matrix returns a non-secret `activation_fingerprint`.
Store that exact value in the server deployment configuration and restart the
service. Changing the source URL, approval reference, validity dates, approved
hosts or affiliate rights changes the expected fingerprint and disables LIVE
prices until the matrix is rerun and the new fingerprint is deliberately
applied. Removing the fingerprint immediately disables the source after a
server restart, without an app update.

The command exits successfully only when the rights gate is ready and at least
one fresh, exact-condition offer survives the full validation path (or every
configured matrix case succeeds). Its JSON
output contains provider IDs, counts and the newest check time, but never emits
tokens, internal approval references, prices or offer URLs. A successful probe
verifies technical readiness; it does not replace the underlying contractual
approval.

Identical product/condition requests are coalesced and cached briefly on the
server (60 seconds by default, never more than five minutes). Unavailable
responses are not cached, and a cache entry can never outlive the 24-hour quote
freshness boundary. Set a shorter TTL if the partner agreement requires it.

After deployment, open Flipwert -> **Mehr -> Erweitert: Flipwert-Server** and enter the HTTPS base URL, for example `https://your-service.example`.

## Endpoints

- `GET /health`
- `GET /v1/status`
- `GET /v1/market/search?source=ebay_de&q=iPhone%2015%20Pro`
- `GET /v1/market/search?source=amazon_de&q=<ASIN-or-EAN>`
- `GET /v1/market/search?source=all&q=...`
- `GET /v1/buyback/search?q=...&condition=used_good`

The response format is normalized to objects containing source, title, price, shipping, currency, condition, URL and a live flag.

## Third-party sources

Simple shops do not need backend code. They can be added from the app with a search template containing `{query}`.

Partners that want in-app prices can publish a Flipwert source manifest with an HTTPS `adapter_url`. Their adapter should return either an `items` array or a JSON array with entries like:

```json
{
  "title": "Example product",
  "price": 199.99,
  "shipping": 4.99,
  "condition": "Used - Good",
  "url": "https://partner.example/item/123",
  "live": true
}
```

Keep adapters legally compliant with the source website/API terms. Do not put third-party secrets in manifests.
