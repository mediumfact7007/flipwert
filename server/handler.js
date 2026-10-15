'use strict';

const { assessMarketListings } = require('./market_quality');
const { fetchBuybackOffers, sourceStatus: buybackSourceStatus } = require('./buyback_source');
const { configured: playVerificationConfigured, verifyPlayEntitlement } = require('./play_entitlement');

const RATE_WINDOW_MS = 60_000;
const CACHE_TTL_MS = 45_000;
const CACHE_MAX = 400;
const ALLOWED_SOURCES = new Set(['ebay_de', 'amazon_de', 'all']);

let ebayToken = null;
let ebayTokenExpiresAt = 0;
const rateBuckets = new Map();
const searchCache = new Map();

function runtimeConfig(env = {}) {
  const rawEbayEnv = String(env.EBAY_ENV || 'sandbox').trim().toLowerCase();
  const ebayEnv = rawEbayEnv === 'production' ? 'production' : 'sandbox';
  return {
    ebayClientId: String(env.EBAY_CLIENT_ID || ''),
    ebayClientSecret: String(env.EBAY_CLIENT_SECRET || ''),
    ebayEnv,
    ebayApiBase: ebayEnv === 'production'
      ? 'https://api.ebay.com'
      : 'https://api.sandbox.ebay.com',
    keepaApiKey: String(env.KEEPA_API_KEY || ''),
    ebayRightsApproved: String(env.EBAY_SOURCE_RIGHTS_ACK || '').trim() ===
      'approved-ebay-api-use-and-display-v1',
    keepaRightsApproved: String(env.KEEPA_SOURCE_RIGHTS_ACK || '').trim() ===
      'approved-keepa-price-use-and-display-v1',
    rateMax: Number(env.RATE_LIMIT_PER_MINUTE || 90),
    fetchTimeoutMs: Number(env.UPSTREAM_TIMEOUT_MS || 8_000),
  };
}

function json(status, body) {
  const data = JSON.stringify(body);
  return new Response(data, { status, headers: {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': '*',
    'cache-control': status >= 200 && status < 300 ? 'public, max-age=30' : 'no-store',
    'x-content-type-options': 'nosniff',
  } });
}

async function readJson(request, maxBytes = 16_384) {
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > maxBytes) {
    throw new Error('request_too_large');
  }
  return text ? JSON.parse(text) : {};
}

function money(value) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.round(n * 100) / 100 : 0;
}

function ebayEuroAmount(amount, { allowZero = false } = {}) {
  if (String(amount?.currency || '').trim().toUpperCase() !== 'EUR') return null;
  const value = Number(amount?.value);
  if (!Number.isFinite(value) || (allowZero ? value < 0 : value <= 0)) return null;
  const normalized = money(value);
  return allowZero || normalized > 0 ? normalized : null;
}

function normalizeQuery(value) {
  return String(value || '').replace(/\s+/g, ' ').trim().slice(0, 180);
}

function clientKey(request) {
  const connecting = request.headers.get('cf-connecting-ip') || '';
  const forwarded = String(request.headers.get('x-forwarded-for') || '')
    .split(',')[0].trim();
  return connecting || forwarded || 'unknown';
}

function allowRequest(request, rateMax) {
  const key = clientKey(request);
  const now = Date.now();
  const bucket = rateBuckets.get(key);
  if (!bucket || now - bucket.startedAt >= RATE_WINDOW_MS) {
    rateBuckets.set(key, { startedAt: now, count: 1 });
    return true;
  }
  bucket.count += 1;
  return bucket.count <= rateMax;
}

function pruneRateBuckets() {
  const cutoff = Date.now() - RATE_WINDOW_MS * 2;
  for (const [key, bucket] of rateBuckets.entries()) {
    if (bucket.startedAt < cutoff) rateBuckets.delete(key);
  }
}

function cacheKey(source, q) {
  return `${source}:${q.toLowerCase()}`;
}

function cacheGet(source, q) {
  const key = cacheKey(source, q);
  const entry = searchCache.get(key);
  if (!entry) return null;
  if (Date.now() - entry.at > CACHE_TTL_MS) {
    searchCache.delete(key);
    return null;
  }
  return entry.items;
}

function cacheSet(source, q, items) {
  if (searchCache.size >= CACHE_MAX) {
    const oldest = searchCache.keys().next().value;
    if (oldest) searchCache.delete(oldest);
  }
  searchCache.set(cacheKey(source, q), { at: Date.now(), items });
}

async function fetchJson(url, options = {}, timeoutMs = 8_000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, { ...options, signal: controller.signal });
    const text = await response.text();
    let body = {};
    try { body = text ? JSON.parse(text) : {}; } catch (_) { body = {}; }
    if (!response.ok) {
      const error = new Error(`upstream_${response.status}`);
      error.status = response.status;
      error.body = body;
      throw error;
    }
    return body;
  } finally {
    clearTimeout(timeout);
  }
}

async function ebayAccessToken(config) {
  if (!config.ebayClientId || !config.ebayClientSecret) return '';
  if (ebayToken && Date.now() < ebayTokenExpiresAt - 60_000) return ebayToken;
  const credentials = Buffer.from(
    `${config.ebayClientId}:${config.ebayClientSecret}`,
  ).toString('base64');
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    scope: 'https://api.ebay.com/oauth/api_scope',
  });
  const token = await fetchJson(`${config.ebayApiBase}/identity/v1/oauth2/token`, {
    method: 'POST',
    headers: {
      authorization: `Basic ${credentials}`,
      'content-type': 'application/x-www-form-urlencoded',
    },
    body,
  }, config.fetchTimeoutMs);
  ebayToken = String(token.access_token || '');
  ebayTokenExpiresAt = Date.now() + Number(token.expires_in || 0) * 1000;
  return ebayToken;
}

function ebayUsedConditionLabel(condition) {
  const value = String(condition || '')
    .trim()
    .toUpperCase()
    .replace(/[\s-]+/g, '_');
  if (value === 'USED' || value === 'GEBRAUCHT') return 'Gebraucht';
  if (['LIKE_NEW', 'USED_EXCELLENT', 'WIE_NEU', 'NEUWERTIG'].includes(value)) return 'Wie neu';
  if (['VERY_GOOD', 'USED_VERY_GOOD', 'SEHR_GUT'].includes(value)) return 'Sehr gut';
  if (['GOOD', 'USED_GOOD', 'GUT'].includes(value)) return 'Gut';
  if (['ACCEPTABLE', 'USED_ACCEPTABLE', 'AKZEPTABEL'].includes(value)) return 'Akzeptabel';
  return null;
}

async function searchEbay(q, config) {
  if (config.ebayEnv === 'production' && !config.ebayRightsApproved) return [];
  const token = await ebayAccessToken(config);
  if (!token) return [];
  const url = new URL(`${config.ebayApiBase}/buy/browse/v1/item_summary/search`);
  url.searchParams.set('q', q);
  url.searchParams.set('limit', '50');
  url.searchParams.set('filter', 'buyingOptions:{FIXED_PRICE},itemLocationCountry:DE');
  const data = await fetchJson(url, {
    headers: {
      authorization: `Bearer ${token}`,
      'x-ebay-c-marketplace-id': 'EBAY_DE',
    },
  }, config.fetchTimeoutMs);
  return ebayItems(
    data,
    config.ebayEnv,
    config.ebayRightsApproved,
    new Date().toISOString(),
  );
}

function ebayItems(data, environment, rightsApproved = false, checkedAt = new Date().toISOString()) {
  const summaries = Array.isArray(data.itemSummaries) ? data.itemSummaries : [];
  return summaries.flatMap((item) => {
    // The resale forecast is explicitly based on used asking prices. New,
    // refurbished, defective and unknown conditions must not silently inflate
    // or distort that estimate. Unknown upstream values therefore fail closed.
    const condition = ebayUsedConditionLabel(item.condition);
    if (!condition) return [];
    const price = ebayEuroAmount(item.price);
    const shipping = ebayEuroAmount(
      item.shippingOptions?.[0]?.shippingCost,
      { allowZero: true },
    );
    if (price === null || shipping === null) return [];
    return [{
      source: 'ebay_de',
      title: String(item.title || '').trim(),
      price,
      shipping,
      currency: 'EUR',
      condition,
      url: String(item.itemWebUrl || ''),
      live: environment === 'production' && rightsApproved === true,
      checked_at: checkedAt,
    }];
  }).filter((item) => item.title && item.price > 0 && item.currency === 'EUR' && item.url.startsWith('https://'));
}

function keepaCondition(value) {
  const n = Number(value);
  if (n === 1) return 'Neu';
  if (n === 2) return 'Gebraucht - wie neu';
  if (n === 3) return 'Gebraucht - sehr gut';
  if (n === 4) return 'Gebraucht - gut';
  if (n === 5) return 'Gebraucht - akzeptabel';
  return 'Unbekannt';
}

async function searchAmazon(q, config) {
  if (!config.keepaApiKey || !config.keepaRightsApproved) return [];
  const searchUrl = new URL('https://api.keepa.com/search');
  searchUrl.searchParams.set('key', config.keepaApiKey);
  searchUrl.searchParams.set('domain', '3');
  searchUrl.searchParams.set('type', 'product');
  searchUrl.searchParams.set('term', q);
  const search = await fetchJson(searchUrl, {}, config.fetchTimeoutMs);
  const asinList = Array.isArray(search.asinList) ? search.asinList.slice(0, 10) : [];
  if (!asinList.length) return [];

  const productUrl = new URL('https://api.keepa.com/product');
  productUrl.searchParams.set('key', config.keepaApiKey);
  productUrl.searchParams.set('domain', '3');
  productUrl.searchParams.set('asin', asinList.join(','));
  productUrl.searchParams.set('offers', '20');
  const payload = await fetchJson(productUrl, {}, config.fetchTimeoutMs);
  const products = Array.isArray(payload.products) ? payload.products : [];
  const checkedAt = new Date().toISOString();
  return products.flatMap((product) => keepaProductItems(product, checkedAt));
}

function keepaProductItems(product, checkedAt = new Date().toISOString()) {
  const asin = product.asin || '';
  const title = product.title || `Amazon ${asin}`;
  const offers = Array.isArray(product.offers) ? product.offers : [];
  const liveOrder = new Set(Array.isArray(product.liveOffersOrder) ? product.liveOffersOrder : []);
  const items = [];

  for (let index = 0; index < offers.length; index += 1) {
    const offer = offers[index];
    if (liveOrder.size > 0 && !liveOrder.has(index)) continue;
    if (offer.isShippable === false || offer.isPreorder === true) continue;
    if (Number(offer.condition) !== 1) continue;

    const csv = offer.offerCSV;
    if (!Array.isArray(csv) || csv.length < 2) continue;
    const rawPrice = Number(csv[csv.length - 2]);
    const rawShipping = Number(csv[csv.length - 1]);
    if (!Number.isFinite(rawPrice) || rawPrice <= 0) continue;
    if (!Number.isFinite(rawShipping) || rawShipping < 0) continue;

    items.push({
      source: 'amazon_de',
      title,
      price: rawPrice / 100,
      shipping: rawShipping / 100,
      currency: 'EUR',
      condition: `Amazon marketplace · ${keepaCondition(offer.condition)}`,
      url: asin ? `https://www.amazon.de/dp/${encodeURIComponent(asin)}` : 'https://www.amazon.de/',
      live: true,
      checked_at: checkedAt,
    });
  }

  return items;
}

async function marketSearch(source, q, config) {
  switch (source) {
    case 'ebay_de':
      return searchEbay(q, config);
    case 'amazon_de':
      return searchAmazon(q, config);
    case 'all': {
      const results = await Promise.allSettled([
        searchEbay(q, config),
        searchAmazon(q, config),
      ]);
      return results.flatMap((r) => r.status === 'fulfilled' ? r.value : []);
    }
    default:
      return [];
  }
}

async function marketSearchCached(source, q, config) {
  const cached = cacheGet(source, q);
  if (cached) return { items: cached, cached: true };
  const items = await marketSearch(source, q, config);
  cacheSet(source, q, items);
  return { items, cached: false };
}

function sourceStatus(env, config) {
  const ebayProductionAllowed =
    config.ebayEnv !== 'production' || config.ebayRightsApproved;
  return {
    ebay_de: {
      configured: Boolean(
        config.ebayClientId && config.ebayClientSecret && ebayProductionAllowed,
      ),
      mode: 'official_api',
      environment: config.ebayEnv,
      data_kind: config.ebayEnv === 'production'
        ? (config.ebayRightsApproved
          ? 'active_marketplace_listings'
          : 'blocked_pending_rights')
        : 'sandbox_mock_data',
      rights_gate: config.ebayEnv === 'production'
        ? (config.ebayRightsApproved ? 'approved' : 'not_approved')
        : 'not_live_sandbox',
      estimate: 'used_fixed_price_active_listings',
    },
    amazon_de: {
      configured: Boolean(config.keepaApiKey && config.keepaRightsApproved),
      mode: 'keepa',
      rights_gate: config.keepaRightsApproved ? 'approved' : 'not_approved',
      estimate: 'retail_reference',
    },
    kleinanzeigen: { configured: false, mode: 'official_search_link' },
    mediamarkt: { configured: false, mode: 'official_search_link' },
    saturn: { configured: false, mode: 'official_search_link' },
    idealo: { configured: false, mode: 'official_search_link' },
    buyback: buybackSourceStatus(Date.now(), env),
  };
}

async function handle(request, env = {}) {
  try {
    const config = runtimeConfig(env);
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: {
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'GET,POST,OPTIONS',
        'access-control-allow-headers': 'content-type',
      } });
    }

    if (request.method === 'GET' && url.pathname === '/health') {
      return json(200, {
        ok: true,
        service: 'flipwert-api',
        version: '0.11.0',
        ebay_environment: config.ebayEnv,
      });
    }

    if (request.method === 'GET' && url.pathname === '/v1/status') {
      return json(200, {
        sources: sourceStatus(env, config),
        monetization: {
          play_verification_configured: playVerificationConfigured(env),
        },
      });
    }

    if (request.method === 'POST' && url.pathname === '/v1/entitlements/google-play') {
      pruneRateBuckets();
      if (!allowRequest(request, config.rateMax)) {
        return json(429, { verified: false, error: 'rate_limit' });
      }
      let body;
      try {
        body = await readJson(request);
      } catch (error) {
        const reason = error instanceof Error ? error.message : '';
        return json(reason === 'request_too_large' ? 413 : 400, {
          verified: false,
          error: reason === 'request_too_large' ? reason : 'invalid_json',
        });
      }
      try {
        const result = await verifyPlayEntitlement({
          productId: String(body.product_id || '').trim(),
          purchaseToken: String(body.purchase_token || '').trim(),
          env,
        });
        const status = result.verified
          ? 200
          : result.error === 'play_verification_not_configured'
            ? 503
            : 403;
        return json(status, {
          verified: result.verified,
          product_id: result.productId,
          expires_at: result.expiresAt,
          error: result.error,
        });
      } catch (_) {
        return json(502, { verified: false, error: 'play_verification_failed' });
      }
    }

    if (request.method === 'GET' && url.pathname === '/v1/listing/resolve') {
      // Retired: older clients may still call this route. Never fetch a
      // Kleinanzeigen page without an explicit written integration agreement.
      return json(410, { error: 'listing_import_disabled', manual_entry: true });
    }

    if (request.method === 'GET' && url.pathname === '/v1/buyback/search') {
      pruneRateBuckets();
      if (!allowRequest(request, config.rateMax)) {
        return json(429, { error: 'rate_limit', items: [], best: null });
      }

      const q = normalizeQuery(url.searchParams.get('q'));
      const condition = String(url.searchParams.get('condition') || '').trim().slice(0, 32);
      if (!q) return json(400, { error: 'q is required', items: [], best: null });
      if (!condition) return json(400, { error: 'condition is required', items: [], best: null });

      const started = Date.now();
      try {
        const result = await fetchBuybackOffers(q, condition, { env });
        const readiness = buybackSourceStatus(Date.now(), env).readiness;
        return json(200, {
          source: 'buyback',
          query: q,
          condition,
          configured: result.configured,
          readiness,
          unavailable: result.unavailable === true,
          live: result.configured && result.items.length > 0,
          items: result.items,
          best: result.best,
          meta: {
            count: result.items.length,
            elapsed_ms: Date.now() - started,
            data_kind: 'indicative_buyback',
            note: result.configured
              ? 'Indicative provider offers; final payout may depend on provider inspection.'
              : 'Buyback provider is not configured; no price is estimated or fabricated.',
          },
        });
      } catch (error) {
        const message = error?.name === 'AbortError'
          ? 'upstream_timeout'
          : error instanceof Error
            ? error.message
            : String(error);
        return json(503, {
          source: 'buyback',
          query: q,
          condition,
          items: [],
          best: null,
          error: message,
        });
      }
    }

    if (request.method === 'GET' && url.pathname === '/v1/market/search') {
      pruneRateBuckets();
      if (!allowRequest(request, config.rateMax)) {
        return json(429, { error: 'rate_limit', items: [] });
      }
      const source = String(url.searchParams.get('source') || 'all').trim().toLowerCase();
      const q = normalizeQuery(url.searchParams.get('q'));
      if (!ALLOWED_SOURCES.has(source)) return json(400, { error: 'unsupported_source', items: [] });
      if (!q) return json(400, { error: 'q is required', items: [] });

      try {
        const result = await marketSearchCached(source, q, config);
        const quality = assessMarketListings(q, result.items);
        return json(200, {
          source,
          query: q,
          cached: result.cached,
          items: quality.items,
          meta: {
            count: quality.items.length,
            raw_count: result.items.length,
            rejected_count: quality.rejectedCount,
          },
        });
      } catch (error) {
        const message = error?.name === 'AbortError'
          ? 'upstream_timeout'
          : error instanceof Error
            ? error.message
            : String(error);
        return json(502, { error: message, items: [] });
      }
    }

    return json(404, { error: 'not_found' });
  } catch (error) {
    return json(500, { error: error instanceof Error ? error.message : String(error) });
  }
}

module.exports = { ebayItems, handle };
