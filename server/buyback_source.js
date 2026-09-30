'use strict';

const crypto = require('crypto');

const { CONDITIONS, normalizeBuybackPayload, bestBuybackOffer } = require('./buyback');
const { matchesBuybackQuery } = require('./buyback_match');

const configuredTimeoutMs = Number(process.env.BUYBACK_SOURCE_TIMEOUT_MS || 6000);
const BUYBACK_SOURCE_TIMEOUT_MS = Number.isFinite(configuredTimeoutMs)
  ? Math.min(15000, Math.max(1000, configuredTimeoutMs))
  : 6000;
const configuredCacheTtlMs = Number(process.env.BUYBACK_SOURCE_CACHE_TTL_MS || 60000);
const BUYBACK_SOURCE_CACHE_TTL_MS = Number.isFinite(configuredCacheTtlMs)
  ? Math.min(300000, Math.max(0, configuredCacheTtlMs))
  : 60000;
const BUYBACK_SOURCE_CACHE_MAX = 200;
const BUYBACK_SOURCE_URL = String(process.env.BUYBACK_SOURCE_URL || '').trim();
const BUYBACK_SOURCE_TOKEN = String(process.env.BUYBACK_SOURCE_TOKEN || '').trim();
const BUYBACK_SOURCE_POLICY_ACK = String(process.env.BUYBACK_SOURCE_POLICY_ACK || '').trim();
const BUYBACK_SOURCE_APPROVALS_JSON = String(process.env.BUYBACK_SOURCE_APPROVALS_JSON || '').trim();
const BUYBACK_SOURCE_ACTIVATION_FINGERPRINT = String(process.env.BUYBACK_SOURCE_ACTIVATION_FINGERPRINT || '').trim().toLowerCase();
const REQUIRED_POLICY_ACK = 'approved-feed-and-price-display-v1';
const ACTIVATION_FINGERPRINT_PATTERN = /^[a-f0-9]{64}$/;
const PROVIDER_ID_PATTERN = /^[a-z0-9][a-z0-9_-]{1,63}$/;
const APPROVED_HOST_PATTERN = /^(?=.{1,253}$)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/;
const resultCache = new Map();
const inFlightRequests = new Map();

function explicitTimestamp(value) {
  const raw = String(value || '').trim();
  if (!/(?:Z|[+-]\d{2}:?\d{2})$/.test(raw)) return null;
  const parsed = Date.parse(raw);
  return Number.isFinite(parsed) ? parsed : null;
}

function approvedHosts(value) {
  if (!Array.isArray(value) || !value.length || value.length > 20) return null;
  const hosts = new Set();
  for (const raw of value) {
    const host = String(raw || '').trim().toLowerCase().replace(/\.$/, '');
    if (!APPROVED_HOST_PATTERN.test(host) || !hasPublicSourceHost(host)) return null;
    try {
      const parsed = new URL(`https://${host}`);
      if (parsed.hostname !== host || parsed.pathname !== '/') return null;
    } catch (_) {
      return null;
    }
    if (hosts.has(host)) return null;
    hosts.add(host);
  }
  return hosts;
}

function currentProviderApprovals(now = Date.now()) {
  if (!BUYBACK_SOURCE_APPROVALS_JSON) return new Map();
  let rows;
  try {
    rows = JSON.parse(BUYBACK_SOURCE_APPROVALS_JSON);
  } catch (_) {
    return new Map();
  }
  if (!Array.isArray(rows) || !rows.length) return new Map();

  const approvals = new Map();
  const seenProviderIds = new Set();
  for (const row of rows) {
    if (!row || typeof row !== 'object' || Array.isArray(row)) return new Map();
    const providerId = String(row.provider_id || '').trim().toLowerCase();
    const reference = String(row.approval_reference || '').trim();
    const reviewedAt = explicitTimestamp(row.reviewed_at);
    const validUntil = explicitTimestamp(row.valid_until);
    const feedHosts = approvedHosts(row.feed_hosts);
    const offerHosts = approvedHosts(row.offer_hosts);
    if (!PROVIDER_ID_PATTERN.test(providerId) || seenProviderIds.has(providerId) ||
        !reference || reference.length > 160 || reviewedAt === null ||
        validUntil === null || feedHosts === null || offerHosts === null) {
      return new Map();
    }
    seenProviderIds.add(providerId);
    if (reviewedAt > now || validUntil <= now ||
        row.feed_access !== true || row.price_display !== true ||
        row.offer_links !== true || row.provider_identity_display !== true) continue;
    approvals.set(providerId, {
      providerId,
      approvalReference: reference,
      reviewedAt,
      validUntil,
      feedHosts,
      offerHosts,
      affiliateLinks: row.affiliate_links === true,
    });
  }
  return approvals;
}

function currentSourceApprovals(now = Date.now()) {
  if (BUYBACK_SOURCE_POLICY_ACK !== REQUIRED_POLICY_ACK || !BUYBACK_SOURCE_URL) return new Map();
  try {
    const sourceHost = new URL(BUYBACK_SOURCE_URL).hostname.toLowerCase();
    return new Map([...currentProviderApprovals(now)]
      .filter(([, approval]) => approval.feedHosts.has(sourceHost)));
  } catch (_) {
    return new Map();
  }
}

function sourceConfigFingerprint(now = Date.now()) {
  const approvals = currentSourceApprovals(now);
  if (!approvals.size || !BUYBACK_SOURCE_URL) return null;
  let sourceUrl;
  try {
    sourceUrl = new URL(BUYBACK_SOURCE_URL).toString();
  } catch (_) {
    return null;
  }
  const providers = [...approvals.values()]
    .sort((a, b) => a.providerId.localeCompare(b.providerId))
    .map((approval) => ({
      provider_id: approval.providerId,
      approval_reference: approval.approvalReference,
      reviewed_at: new Date(approval.reviewedAt).toISOString(),
      valid_until: new Date(approval.validUntil).toISOString(),
      feed_hosts: [...approval.feedHosts].sort(),
      offer_hosts: [...approval.offerHosts].sort(),
      affiliate_links: approval.affiliateLinks,
    }));
  return crypto.createHash('sha256')
    .update(JSON.stringify({ source_url: sourceUrl, providers }))
    .digest('hex');
}

function hasCurrentApproval(now = Date.now()) {
  return currentSourceApprovals(now).size > 0;
}

function approvedProviderIds(now = Date.now()) {
  return [...currentSourceApprovals(now).keys()].sort();
}

function hasPublicSourceHost(hostname) {
  const host = String(hostname || '').toLowerCase().replace(/^\[|\]$/g, '');
  if (!host || host === 'localhost' || host.endsWith('.local') || host === '::' || host === '::1') return false;
  if (host.includes(':')) {
    return !host.startsWith('::ffff:') && !host.startsWith('fc') && !host.startsWith('fd') &&
      !host.startsWith('fe8') && !host.startsWith('fe9') &&
      !host.startsWith('fea') && !host.startsWith('feb');
  }
  const octets = host.split('.');
  if (octets.length !== 4) return true;
  const parts = octets.map(Number);
  if (parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) return false;
  const [a, b, c] = parts;
  return !(a === 0 || a === 10 || a === 127 ||
    (a === 100 && b >= 64 && b <= 127) ||
    (a === 169 && b === 254) ||
    (a === 172 && b >= 16 && b <= 31) ||
    (a === 192 && b === 0 && (c === 0 || c === 2)) ||
    (a === 192 && b === 168) ||
    (a === 198 && (b === 18 || b === 19)) ||
    (a === 198 && b === 51 && c === 100) ||
    (a === 203 && b === 0 && c === 113) || a >= 224);
}

function sourceRightsReadiness(now = Date.now()) {
  if (!BUYBACK_SOURCE_URL) return 'missing_source_url';
  let url;
  try {
    url = new URL(BUYBACK_SOURCE_URL);
  } catch (_) {
    return 'invalid_source_url';
  }
  if (url.protocol !== 'https:' || url.username || url.password ||
      !hasPublicSourceHost(url.hostname)) return 'invalid_source_url';
  if (BUYBACK_SOURCE_POLICY_ACK !== REQUIRED_POLICY_ACK) return 'missing_policy_ack';
  const approvals = currentProviderApprovals(now);
  if (!approvals.size) return 'missing_current_provider_approval';
  if (![...approvals.values()].some((approval) =>
    approval.feedHosts.has(url.hostname.toLowerCase()))) {
    return 'source_host_not_approved';
  }
  return 'rights_ready';
}

function sourceReadiness(now = Date.now()) {
  const rightsReadiness = sourceRightsReadiness(now);
  if (rightsReadiness !== 'rights_ready') return rightsReadiness;
  const expected = sourceConfigFingerprint(now);
  if (!expected ||
      !ACTIVATION_FINGERPRINT_PATTERN.test(BUYBACK_SOURCE_ACTIVATION_FINGERPRINT) ||
      BUYBACK_SOURCE_ACTIVATION_FINGERPRINT !== expected) {
    return 'missing_or_stale_validation';
  }
  return 'ready';
}

function configured(now = Date.now()) {
  return sourceReadiness(now) === 'ready';
}

function hasApprovedOfferUrl(value, allowedHosts) {
  try {
    const url = new URL(String(value || '').trim());
    return url.protocol === 'https:' && !url.username && !url.password &&
      hasPublicSourceHost(url.hostname) && allowedHosts.has(url.hostname.toLowerCase());
  } catch (_) {
    return false;
  }
}

function cacheKey(query, condition) {
  return `${condition}:${query.toLowerCase()}`;
}

function cachedResult(key, now) {
  const entry = resultCache.get(key);
  if (!entry) return null;
  if (entry.expiresAt <= now) {
    resultCache.delete(key);
    return null;
  }
  return entry.result;
}

function cacheResult(key, result, now) {
  if (BUYBACK_SOURCE_CACHE_TTL_MS <= 0 || result.unavailable === true) return;
  let expiresAt = now + BUYBACK_SOURCE_CACHE_TTL_MS;
  const approvals = currentSourceApprovals(now);
  for (const item of result.items) {
    const checkedAt = Date.parse(String(item.checked_at || ''));
    if (Number.isFinite(checkedAt)) {
      expiresAt = Math.min(expiresAt, checkedAt + 24 * 60 * 60 * 1000);
    }
    const approval = approvals.get(String(item.provider_id || '').trim().toLowerCase());
    if (approval) expiresAt = Math.min(expiresAt, approval.validUntil);
  }
  if (expiresAt <= now) return;
  if (resultCache.size >= BUYBACK_SOURCE_CACHE_MAX && !resultCache.has(key)) {
    const oldest = resultCache.keys().next().value;
    if (oldest) resultCache.delete(oldest);
  }
  resultCache.delete(key);
  resultCache.set(key, { expiresAt, result });
}

async function fetchBuybackOffers(query, condition, options = {}) {
  return fetchBuybackOffersInternal(query, condition, options, true);
}

async function fetchBuybackOffersForVerification(query, condition, options = {}) {
  return fetchBuybackOffersInternal(query, condition, options, false);
}

async function fetchBuybackOffersInternal(
  query,
  condition,
  { fetchImpl = fetch, now = Date.now() } = {},
  requireActivation,
) {
  const available = requireActivation
    ? configured(now)
    : sourceRightsReadiness(now) === 'rights_ready';
  if (!available) return { configured: false, items: [], best: null };

  const normalizedQuery = String(query || '').trim().replace(/\s+/g, ' ').slice(0, 160);
  if (normalizedQuery.length < 3) return { configured: true, items: [], best: null };
  const normalizedCondition = String(condition || '').trim().slice(0, 32);
  if (!CONDITIONS.has(normalizedCondition)) {
    return { configured: true, items: [], best: null };
  }

  const key = cacheKey(normalizedQuery, normalizedCondition);
  if (BUYBACK_SOURCE_CACHE_TTL_MS > 0) {
    const cached = cachedResult(key, now);
    if (cached) return cached;
    const pending = inFlightRequests.get(key);
    if (pending) return pending;
  }

  const request = requestBuybackOffers(normalizedQuery, normalizedCondition, {
    fetchImpl,
    now,
  });
  if (BUYBACK_SOURCE_CACHE_TTL_MS <= 0) return request;
  inFlightRequests.set(key, request);
  try {
    const result = await request;
    cacheResult(key, result, now);
    return result;
  } finally {
    if (inFlightRequests.get(key) === request) inFlightRequests.delete(key);
  }
}

async function requestBuybackOffers(normalizedQuery, normalizedCondition, { fetchImpl, now }) {
  const endpoint = new URL(BUYBACK_SOURCE_URL);
  endpoint.searchParams.set('q', normalizedQuery);
  if (normalizedCondition) endpoint.searchParams.set('condition', normalizedCondition);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), BUYBACK_SOURCE_TIMEOUT_MS);
  try {
    const headers = { accept: 'application/json' };
    if (BUYBACK_SOURCE_TOKEN) headers.authorization = `Bearer ${BUYBACK_SOURCE_TOKEN}`;
    const response = await fetchImpl(endpoint, { headers, signal: controller.signal, redirect: 'error' });
    if (!response.ok) return { configured: true, items: [], best: null, unavailable: true };
    const contentType = String(response.headers?.get?.('content-type') || '').toLowerCase();
    if (contentType && !contentType.includes('application/json')) {
      return { configured: true, items: [], best: null, unavailable: true };
    }
    const payload = await response.json();
    const rawItems = Array.isArray(payload) ? payload : Array.isArray(payload?.items) ? payload.items : [];
    const allowedProviders = currentSourceApprovals(now);
    const normalizedItems = normalizeBuybackPayload(rawItems.filter((item) => {
      const providerId = String(item?.provider_id || '').trim().toLowerCase();
      const approval = allowedProviders.get(providerId);
      return approval?.feedHosts.has(endpoint.hostname.toLowerCase()) === true &&
        hasApprovedOfferUrl(item?.offer_url, approval.offerHosts) &&
        (item?.affiliate_link === undefined ||
          item?.affiliate_link === false ||
          (item?.affiliate_link === true && approval.affiliateLinks === true)) &&
        matchesBuybackQuery(normalizedQuery, item);
    }), { now });
    // The requested condition is part of the product identity. Some partner
    // feeds return a condition matrix even when one state was requested; never
    // let those other rows reach the app or influence the visible best offer.
    const items = normalizedItems.filter((item) => item.condition === normalizedCondition);
    return {
      configured: true,
      items,
      best: normalizedCondition ? bestBuybackOffer(items, normalizedCondition) : null,
    };
  } catch (_) {
    return { configured: true, items: [], best: null, unavailable: true };
  } finally {
    clearTimeout(timer);
  }
}

function sourceStatus(now = Date.now()) {
  const approvals = currentSourceApprovals(now);
  const readiness = sourceReadiness(now);
  const rightsReady = sourceRightsReadiness(now) === 'rights_ready';
  const isConfigured = readiness === 'ready';
  return {
    configured: isConfigured,
    mode: isConfigured ? 'approved_partner_adapter' : 'disabled',
    data_kind: 'indicative_buyback',
    max_age_hours: 24,
    cache_ttl_seconds: BUYBACK_SOURCE_CACHE_TTL_MS / 1000,
    minimum_match_confidence: 0.9,
    rights_gate: rightsReady ? 'approved' : 'not_approved_or_expired',
    activation_gate: isConfigured ? 'validated' : 'missing_or_stale',
    readiness,
    approval_model: 'per_provider_hosts_affiliate_and_activation_v4',
    activation_model: 'configuration_fingerprint_v1',
    approved_provider_count: isConfigured ? approvals.size : 0,
  };
}

module.exports = {
  configured,
  fetchBuybackOffers,
  fetchBuybackOffersForVerification,
  sourceStatus,
  hasCurrentApproval,
  approvedProviderIds,
  sourceReadiness,
  activationFingerprint: sourceConfigFingerprint,
};
