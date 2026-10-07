'use strict';

const CONDITIONS = new Set([
  'new_sealed',
  'like_new',
  'very_good',
  'used_good',
  'acceptable',
  'defective',
]);

const MAX_AGE_MS = 24 * 60 * 60 * 1000;
const MAX_PRICE_EUR = 10000;

function text(value, max = 240) {
  return String(value || '').trim().slice(0, max);
}

function hasExplicitTimeZone(value) {
  const normalized = text(value, 80);
  return normalized.endsWith('Z') || /[+-]\d{2}:?\d{2}$/.test(normalized);
}

function normalizeBuybackOffer(raw, { now = Date.now() } = {}) {
  if (!raw || typeof raw !== 'object') return null;
  const condition = text(raw.condition, 32);
  const listedPrice = raw.price;
  const mandatoryDeductions = raw.mandatory_deductions_eur;
  const price = Math.round((listedPrice - mandatoryDeductions) * 100) / 100;
  const confidence = raw.match_confidence;
  const checkedAtRaw = text(raw.checked_at, 80);
  const checkedAt = Date.parse(checkedAtRaw);
  const expiresAtRaw = raw.expires_at === undefined || raw.expires_at === null
    ? ''
    : text(raw.expires_at, 80);
  const expiresAt = expiresAtRaw ? Date.parse(expiresAtRaw) : null;
  const offerUrl = text(raw.offer_url, 1000);
  let parsedUrl;
  try { parsedUrl = new URL(offerUrl); } catch (_) { return null; }

  if (!CONDITIONS.has(condition)) return null;
  if (!Number.isFinite(listedPrice) || listedPrice <= 0 || listedPrice > MAX_PRICE_EUR) return null;
  if (!Number.isFinite(mandatoryDeductions) || mandatoryDeductions < 0 ||
      mandatoryDeductions >= listedPrice || price <= 0) return null;
  if (text(raw.currency, 8) !== 'EUR') return null;
  if (text(raw.price_kind, 40) !== 'indicative_buyback') return null;
  if (text(raw.payout_type, 40) !== 'cash') return null;
  if (!Number.isFinite(confidence) || confidence < 0.9 || confidence > 1) return null;
  if (!hasExplicitTimeZone(checkedAtRaw) || !Number.isFinite(checkedAt) || checkedAt > now + 5 * 60 * 1000 || now - checkedAt > MAX_AGE_MS) return null;
  if (expiresAtRaw && (!hasExplicitTimeZone(expiresAtRaw) || !Number.isFinite(expiresAt) || expiresAt <= now || expiresAt <= checkedAt)) return null;
  if (parsedUrl.protocol !== 'https:' || parsedUrl.username || parsedUrl.password) return null;
  if (raw.condition_uncertain === true) return null;
  if (raw.affiliate_link !== undefined && typeof raw.affiliate_link !== 'boolean') return null;

  const providerId = text(raw.provider_id, 80);
  const providerName = text(raw.provider_name, 120);
  const productId = text(raw.product_id, 160);
  const matchedTitle = text(raw.matched_title, 240);
  if (!providerId || !providerName || !productId || !matchedTitle) return null;

  return {
    provider_id: providerId,
    provider_name: providerName,
    product_id: productId,
    matched_title: matchedTitle,
    condition,
    price,
    listed_price: listedPrice,
    mandatory_deductions_eur: mandatoryDeductions,
    price_basis: 'net_after_mandatory_deductions',
    currency: 'EUR',
    offer_url: parsedUrl.toString(),
    checked_at: new Date(checkedAt).toISOString(),
    ...(expiresAt === null ? {} : { expires_at: new Date(expiresAt).toISOString() }),
    price_kind: 'indicative_buyback',
    payout_type: 'cash',
    requires_inspection: raw.requires_inspection !== false,
    match_confidence: confidence,
    affiliate_link: raw.affiliate_link === true,
  };
}

function normalizeBuybackPayload(payload, options) {
  const rawItems = Array.isArray(payload) ? payload : Array.isArray(payload?.items) ? payload.items : [];
  const unique = new Map();
  for (const raw of rawItems) {
    const item = normalizeBuybackOffer(raw, options);
    if (!item) continue;
    const key = `${item.provider_id.toLowerCase()}\u0000${item.product_id.toLowerCase()}\u0000${item.condition}`;
    const current = unique.get(key);
    // A feed may contain multiple snapshots for the same provider SKU. The
    // newest quote is authoritative even when the provider lowered its price;
    // selecting the highest value would silently resurrect an older payout.
    // Conflicting rows with the same timestamp fail conservatively to the
    // lower net payout instead of overstating the user's expected proceeds.
    if (!current || item.checked_at > current.checked_at ||
        (item.checked_at === current.checked_at && item.price < current.price)) {
      unique.set(key, item);
    }
  }
  return [...unique.values()].sort((a, b) => b.price - a.price || b.checked_at.localeCompare(a.checked_at));
}

function bestBuybackOffer(items, condition) {
  return items
    .filter((item) => item.condition === condition)
    .reduce((best, item) => (!best || item.price > best.price ? item : best), null);
}

module.exports = { CONDITIONS, MAX_AGE_MS, MAX_PRICE_EUR, normalizeBuybackOffer, normalizeBuybackPayload, bestBuybackOffer };
