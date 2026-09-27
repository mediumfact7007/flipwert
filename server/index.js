'use strict';

const http = require('http');
const { URL, URLSearchParams } = require('url');
const { filterMarketListings } = require('./market_quality');
const { fetchBuybackOffers, sourceStatus: buybackSourceStatus } = require('./buyback_source');

const PORT = Number(process.env.PORT || 8080);
const EBAY_CLIENT_ID = process.env.EBAY_CLIENT_ID || '';
const EBAY_CLIENT_SECRET = process.env.EBAY_CLIENT_SECRET || '';
const rawEbayEnv = String(process.env.EBAY_ENV || 'sandbox').trim().toLowerCase();
const EBAY_ENV = rawEbayEnv === 'production' ? 'production' : 'sandbox';
const EBAY_API_BASE = EBAY_ENV === 'production'
  ? 'https://api.ebay.com'
  : 'https://api.sandbox.ebay.com';
const KEEPA_API_KEY = process.env.KEEPA_API_KEY || '';

const RATE_WINDOW_MS = 60_000;
const RATE_MAX = Number(process.env.RATE_LIMIT_PER_MINUTE || 90);
const CACHE_TTL_MS = 45_000;
const CACHE_MAX = 400;
const FETCH_TIMEOUT_MS = Number(process.env.UPSTREAM_TIMEOUT_MS || 8_000);
const ALLOWED_SOURCES = new Set(['ebay_de', 'amazon_de', 'all']);

let ebayToken = null;
let ebayTokenExpiresAt = 0;
const rateBuckets = new Map();
const searchCache = new Map();

function json(res, status, body) {
  const data = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(data),
    'access-control-allow-origin': '*',
    'cache-control': status >= 200 && status < 300 ? 'public, max-age=30' : 'no-store',
    'x-content-type-options': 'nosniff',
  });
  res.end(data);
}

function money(value) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.round(n * 100) / 100 : 0;
}

function normalizeQuery(value) {
  return String(value || '').replace(/\s+/g, ' ').trim().slice(0, 180);
}

function clientKey(req) {
  const forwarded = String(req.headers['x-forwarded-for'] || '').split(',')[0].trim();
  return forwarded || req.socket.remoteAddress || 'unknown';
}

function allowRequest(req) {
  const key = clientKey(req);
  const now = Date.now();
  const bucket = rateBuckets.get(key);
  if (!bucket || now - bucket.startedAt >= RATE_WINDOW_MS) {
    rateBuckets.set(key, { startedAt: now, count: 1 });
    return true;
  }
  bucket.count += 1;
  return bucket.count <= RATE_MAX;
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

async function fetchJson(url, options = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
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

async function ebayAccessToken() {
  if (!EBAY_CLIENT_ID || !EBAY_CLIENT_SECRET) return '';
  if (ebayToken && Date.now() < ebayTokenExpiresAt - 60_000) return ebayToken;
  const credentials = Buffer.from(`${EBAY_CLIENT_ID}:${EBAY_CLIENT_SECRET}`).toString('base64');
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    scope: 'https://api.ebay.com/oauth/api_scope',
  });
  const token = await fetchJson(`${EBAY_API_BASE}/identity/v1/oauth2/token`, {
    method: 'POST',
    headers: {
      authorization: `Basic ${credentials}`,
      'content-type': 'application/x-www-form-urlencoded',
    },
    body,
  });
  ebayToken = String(token.access_token || '');
  ebayTokenExpiresAt = Date.now() + Number(token.expires_in || 0) * 1000;
  return ebayToken;
}

function ebayConditionLabel(condition) {
  const value = String(condition || '').toUpperCase();
  if (value === 'NEW') return 'Neu';
  if (value === 'LIKE_NEW') return 'Wie neu';
  if (value === 'VERY_GOOD') return 'Sehr gut';
  if (value === 'GOOD') return 'Gut';
  if (value === 'ACCEPTABLE') return 'Akzeptabel';
  return value ? value.replaceAll('_', ' ') : 'Unbekannt';
}

async function searchEbay(q) {
  const token = await ebayAccessToken();
  if (!token) return [];
  const url = new URL(`${EBAY_API_BASE}/buy/browse/v1/item_summary/search`);
  url.searchParams.set('q', q);
  url.searchParams.set('limit', '50');
  url.searchParams.set('filter', 'buyingOptions:{FIXED_PRICE},itemLocationCountry:DE');
  const data = await fetchJson(url, {
    headers: {
      authorization: `Bearer ${token}`,
      'x-ebay-c-marketplace-id': 'EBAY_DE',
    },
  });
  const summaries = Array.isArray(data.itemSummaries) ? data.itemSummaries : [];
  return summaries.map((item) => {
    const price = money(item.price?.value);
    const shipping = money(item.shippingOptions?.[0]?.shippingCost?.value);
    return {
      source: 'ebay_de',
      title: String(item.title || '').trim(),
      price,
      shipping,
      currency: String(item.price?.currency || 'EUR'),
      condition: ebayConditionLabel(item.condition),
      url: String(item.itemWebUrl || ''),
      live: true,
    };
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

async function searchAmazon(q) {
  if (!KEEPA_API_KEY) return [];
  const searchUrl = new URL('https://api.keepa.com/search');
  searchUrl.searchParams.set('key', KEEPA_API_KEY);
  searchUrl.searchParams.set('domain', '3');
  searchUrl.searchParams.set('type', 'product');
  searchUrl.searchParams.set('term', q);
  const search = await fetchJson(searchUrl);
  const asinList = Array.isArray(search.asinList) ? search.asinList.slice(0, 10) : [];
  if (!asinList.length) return [];

  const productUrl = new URL('https://api.keepa.com/product');
  productUrl.searchParams.set('key', KEEPA_API_KEY);
  productUrl.searchParams.set('domain', '3');
  productUrl.searchParams.set('asin', asinList.join(','));
  productUrl.searchParams.set('offers', '20');
  const payload = await fetchJson(productUrl);
  const products = Array.isArray(payload.products) ? payload.products : [];
  return products.flatMap((product) => keepaProductItems(product));
}

function keepaProductItems(product) {
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
    });
  }

  return items;
}

async function marketSearch(source, q) {
  switch (source) {
    case 'ebay_de':
      return searchEbay(q);
    case 'amazon_de':
      return searchAmazon(q);
    case 'all': {
      const results = await Promise.allSettled([searchEbay(q), searchAmazon(q)]);
      return results.flatMap((r) => r.status === 'fulfilled' ? r.value : []);
    }
    default:
      return [];
  }
}

async function marketSearchCached(source, q) {
  const cached = cacheGet(source, q);
  if (cached) return { items: cached, cached: true };
  const items = await marketSearch(source, q);
  cacheSet(source, q, items);
  return { items, cached: false };
}

function sourceStatus() {
  return {
    ebay_de: {
      configured: Boolean(EBAY_CLIENT_ID && EBAY_CLIENT_SECRET),
      mode: 'official_api',
      environment: EBAY_ENV,
      data_kind: EBAY_ENV === 'production' ? 'active_marketplace_listings' : 'sandbox_mock_data',
      estimate: 'used_fixed_price_active_listings',
    },
    amazon_de: {
      configured: Boolean(KEEPA_API_KEY),
      mode: 'keepa',
      estimate: 'retail_reference',
    },
    kleinanzeigen: { configured: false, mode: 'official_search_link' },
    mediamarkt: { configured: false, mode: 'official_search_link' },
    saturn: { configured: false, mode: 'official_search_link' },
    idealo: { configured: false, mode: 'official_search_link' },
    buyback: buybackSourceStatus(),
  };
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

    if (req.method === 'OPTIONS') {
      res.writeHead(204, {
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'GET,OPTIONS',
        'access-control-allow-headers': 'content-type',
      });
      return res.end();
    }

    if (req.method === 'GET' && url.pathname === '/health') {
      return json(res, 200, {
        ok: true,
        service: 'flipwert-api',
        version: '0.11.0',
        ebay_environment: EBAY_ENV,
      });
    }

    if (req.method === 'GET' && url.pathname === '/v1/status') {
      return json(res, 200, { sources: sourceStatus() });
    }

    if (req.method === 'GET' && url.pathname === '/v1/listing/resolve') {
      // Retired: older clients may still call this route. Never fetch a
      // Kleinanzeigen page without an explicit written integration agreement.
      return json(res, 410, { error: 'listing_import_disabled', manual_entry: true });
    }

    if (req.method === 'GET' && url.pathname === '/v1/buyback/search') {
      pruneRateBuckets();
      if (!allowRequest(req)) {
        return json(res, 429, { error: 'rate_limit', items: [], best: null });
      }

      const q = normalizeQuery(url.searchParams.get('q'));
      const condition = String(url.searchParams.get('condition') || '').trim().slice(0, 32);
      if (!q) return json(res, 400, { error: 'q is required', items: [], best: null });
      if (!condition) return json(res, 400, { error: 'condition is required', items: [], best: null });

      const started = Date.now();
      try {
        const result = await fetchBuybackOffers(q, condition);
        const readiness = buybackSourceStatus().readiness;
        return json(res, 200, {
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
        return json(res, 503, {
          source: 'buyback',
          query: q,
          condition,
          items: [],
          best: null,
          error: message,
        });
      }
    }

    if (req.method === 'GET' && url.pathname === '/v1/market/search') {
      pruneRateBuckets();
      if (!allowRequest(req)) {
        return json(res, 429, { error: 'rate_limit', items: [] });
      }
      const source = String(url.searchParams.get('source') || 'all').trim().toLowerCase();
      const q = normalizeQuery(url.searchParams.get('q'));
      if (!ALLOWED_SOURCES.has(source)) return json(res, 400, { error: 'unsupported_source', items: [] });
      if (!q) return json(res, 400, { error: 'q is required', items: [] });

      try {
        const result = await marketSearchCached(source, q);
        const quality = filterMarketListings(result.items, {
          query: q,
          source,
          now: Date.now(),
        });
        return json(res, 200, {
          source,
          query: q,
          cached: result.cached,
          items: quality.items,
          meta: {
            count: quality.items.length,
            raw_count: result.items.length,
            rejected_count: quality.rejectedCount,
            market_quality: quality.marketQuality,
            price_summary: quality.priceSummary,
          },
        });
      } catch (error) {
        const message = error?.name === 'AbortError'
          ? 'upstream_timeout'
          : error instanceof Error
            ? error.message
            : String(error);
        return json(res, 502, { error: message, items: [] });
      }
    }

    return json(res, 404, { error: 'not_found' });
  } catch (error) {
    return json(res, 500, { error: error instanceof Error ? error.message : String(error) });
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Flipwert API listening on :${PORT}`);
});
