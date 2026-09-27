'use strict';

const assert = require('assert');
const { normalizeBuybackPayload, bestBuybackOffer } = require('./buyback');

const now = Date.parse('2026-09-16T10:00:00Z');
function offer(overrides = {}) {
  return {
    provider_id: 'provider-a',
    provider_name: 'Provider A',
    product_id: 'iphone-15-pro-256',
    matched_title: 'Apple iPhone 15 Pro 256 GB',
    condition: 'like_new',
    price: 620,
    currency: 'EUR',
    offer_url: 'https://example.com/offer',
    checked_at: '2026-09-16T09:30:00Z',
    price_kind: 'indicative_buyback',
    requires_inspection: true,
    match_confidence: 0.98,
    ...overrides,
  };
}

const normalized = normalizeBuybackPayload({ items: [offer()] }, { now });
assert.strictEqual(normalized.length, 1);
assert.strictEqual(normalized[0].price, 620);
assert.strictEqual(normalized[0].affiliate_link, false);

assert.strictEqual(normalizeBuybackPayload({ items: [offer({ checked_at: '2026-09-14T09:30:00Z' })] }, { now }).length, 0);
assert.strictEqual(normalizeBuybackPayload({ items: [offer({ checked_at: '2026-09-16T09:30:00' })] }, { now }).length, 0, 'provider timestamps without timezone must not affect freshness');
assert.strictEqual(normalizeBuybackPayload({ items: [offer({ checked_at: '2026-09-16T11:30:00+02:00' })] }, { now }).length, 1, 'explicit timezone offsets are valid');
assert.strictEqual(normalizeBuybackPayload({ items: [offer({ price: 0 })] }, { now }).length, 0);
assert.strictEqual(normalizeBuybackPayload({ items: [offer({ price: 10001 })] }, { now }).length, 0, 'implausible feed prices must not distort deal ranking');
assert.strictEqual(normalizeBuybackPayload({ items: [offer({ price_kind: 'asking_price' })] }, { now }).length, 0);
assert.strictEqual(normalizeBuybackPayload({ items: [offer({ match_confidence: 0.72 })] }, { now }).length, 0);
assert.strictEqual(normalizeBuybackPayload({ items: [offer({ condition_uncertain: true })] }, { now }).length, 0);
assert.strictEqual(normalizeBuybackPayload({ items: [offer({ affiliate_link: 'true' })] }, { now }).length, 0, 'affiliate metadata must be boolean');
assert.strictEqual(normalizeBuybackPayload({ items: [offer({ affiliate_link: true })] }, { now })[0].affiliate_link, true);
assert.strictEqual(normalizeBuybackPayload({ items: [offer({ offer_url: 'http://example.com/offer' })] }, { now }).length, 0);
assert.strictEqual(normalizeBuybackPayload({ items: [offer({ offer_url: 'https://user:secret@example.com/offer' })] }, { now }).length, 0, 'offer URLs must not embed credentials');

const comparable = normalizeBuybackPayload({ items: [
  offer({ provider_id: 'a', price: 610 }),
  offer({ provider_id: 'b', price: 645 }),
  offer({ provider_id: 'c', price: 700, condition: 'used_good' }),
] }, { now });
assert.strictEqual(bestBuybackOffer(comparable, 'like_new').provider_id, 'b');
assert.strictEqual(bestBuybackOffer(comparable, 'like_new').price, 645);

const duplicates = normalizeBuybackPayload({ items: [
  offer({ provider_id: 'a', price: 610, checked_at: '2026-09-16T09:20:00Z' }),
  offer({ provider_id: 'a', price: 625, checked_at: '2026-09-16T09:10:00Z' }),
  offer({ provider_id: 'a', price: 625, checked_at: '2026-09-16T09:40:00Z' }),
  offer({ provider_id: 'b', price: 640 }),
] }, { now });
assert.strictEqual(duplicates.length, 2, 'same provider/product/condition must not inflate comparison');
assert.strictEqual(duplicates[0].provider_id, 'b', 'comparison should be ordered by best payout');
assert.strictEqual(duplicates[1].price, 625);
assert.strictEqual(duplicates[1].checked_at, '2026-09-16T09:40:00.000Z', 'equal-price duplicate should keep freshest quote');

const casingDuplicates = normalizeBuybackPayload({ items: [
  offer({ provider_id: 'Provider-A', product_id: 'IPHONE-15-PRO-256', price: 610 }),
  offer({ provider_id: 'provider-a', product_id: 'iphone-15-pro-256', price: 630 }),
] }, { now });
assert.strictEqual(casingDuplicates.length, 1, 'provider ID casing must not inflate the visible comparison');
assert.strictEqual(casingDuplicates[0].price, 630);

console.log('buyback tests passed');
