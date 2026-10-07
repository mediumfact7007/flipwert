'use strict';

const assert = require('node:assert/strict');
const { normalizeBuybackOffer, normalizeBuybackPayload, bestBuybackOffer } = require('./buyback');

const now = Date.parse('2026-09-27T12:00:00Z');
const rawOffer = (overrides = {}) => ({
  provider_id: 'provider',
  provider_name: 'Provider',
  product_id: 'phone-256',
  matched_title: 'Phone 256 GB',
  condition: 'like_new',
  price: 620,
  mandatory_deductions_eur: 0,
  currency: 'EUR',
  offer_url: 'https://provider.example/offer/123',
  checked_at: '2026-09-27T11:55:00Z',
  price_kind: 'indicative_buyback',
  payout_type: 'cash',
  requires_inspection: true,
  match_confidence: 0.98,
  ...overrides,
});

const net = normalizeBuybackOffer(rawOffer({ mandatory_deductions_eur: 25 }), { now });
assert.ok(net);
assert.equal(net.listed_price, 620);
assert.equal(net.mandatory_deductions_eur, 25);
assert.equal(net.price, 595);
assert.equal(net.price_basis, 'net_after_mandatory_deductions');

const unchanged = normalizeBuybackOffer(rawOffer(), { now });
assert.ok(unchanged);
assert.equal(unchanged.price, 620);
assert.equal(unchanged.mandatory_deductions_eur, 0);

assert.equal(normalizeBuybackOffer(rawOffer({ mandatory_deductions_eur: undefined }), { now }), null);
assert.equal(normalizeBuybackOffer(rawOffer({ mandatory_deductions_eur: '0' }), { now }), null);
assert.equal(normalizeBuybackOffer(rawOffer({ price: '620' }), { now }), null);
assert.equal(normalizeBuybackOffer(rawOffer({ price: 620.005 }), { now }), null);
assert.equal(normalizeBuybackOffer(rawOffer({ mandatory_deductions_eur: 0.001 }), { now }), null);
assert.equal(normalizeBuybackOffer(rawOffer({ match_confidence: '0.98' }), { now }), null);
assert.equal(normalizeBuybackOffer(rawOffer({ mandatory_deductions_eur: -1 }), { now }), null);
assert.equal(normalizeBuybackOffer(rawOffer({ mandatory_deductions_eur: 620 }), { now }), null);
assert.equal(normalizeBuybackOffer(rawOffer({ mandatory_deductions_eur: 700 }), { now }), null);
assert.equal(normalizeBuybackOffer(rawOffer({ payout_type: 'store_credit' }), { now }), null);
assert.equal(normalizeBuybackOffer(rawOffer({ payout_type: undefined }), { now }), null);

const decimalCents = normalizeBuybackOffer(rawOffer({
  price: 620.10,
  mandatory_deductions_eur: 0.20,
}), { now });
assert.ok(decimalCents);
assert.equal(decimalCents.listed_price, 620.10);
assert.equal(decimalCents.mandatory_deductions_eur, 0.20);
assert.equal(decimalCents.price, 619.90);

const expiring = normalizeBuybackOffer(rawOffer({ expires_at: '2026-09-27T12:15:00Z' }), { now });
assert.equal(expiring.expires_at, '2026-09-27T12:15:00.000Z');
assert.equal(normalizeBuybackOffer(rawOffer({ expires_at: '2026-09-27T11:59:00Z' }), { now }), null);
assert.equal(normalizeBuybackOffer(rawOffer({ expires_at: '2026-09-27T12:15:00' }), { now }), null);

const highGross = normalizeBuybackOffer(rawOffer({ provider_id: 'gross', price: 650, mandatory_deductions_eur: 80 }), { now });
const lowerGross = normalizeBuybackOffer(rawOffer({ provider_id: 'net', price: 620, mandatory_deductions_eur: 10 }), { now });
assert.equal(bestBuybackOffer([highGross, lowerGross], 'like_new').provider_id, 'net');

const olderHigh = rawOffer({ price: 680, checked_at: '2026-09-27T10:00:00Z' });
const newerLow = rawOffer({ price: 610, checked_at: '2026-09-27T11:00:00Z' });
for (const rows of [[olderHigh, newerLow], [newerLow, olderHigh]]) {
  const normalized = normalizeBuybackPayload(rows, { now });
  assert.equal(normalized.length, 1);
  assert.equal(normalized[0].price, 610, 'the latest provider SKU quote must replace an older higher payout');
  assert.equal(normalized[0].checked_at, '2026-09-27T11:00:00.000Z');
}

const sameTimeConflict = normalizeBuybackPayload([
  rawOffer({ price: 650, checked_at: '2026-09-27T11:30:00Z' }),
  rawOffer({ price: 600, checked_at: '2026-09-27T11:30:00Z' }),
], { now });
assert.equal(sameTimeConflict.length, 1);
assert.equal(sameTimeConflict[0].price, 600, 'same-time conflicts must not overstate the payout');

console.log('buyback_test: ok');
