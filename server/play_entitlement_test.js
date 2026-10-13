'use strict';

const assert = require('assert');
const { activeEntitlement, verifyPlayEntitlement } = require('./play_entitlement');

const now = Date.parse('2026-10-13T12:00:00Z');

assert.deepStrictEqual(activeEntitlement({
  subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
  lineItems: [{ productId: 'flipwert_pro_monthly', expiryTime: '2026-11-13T12:00:00Z' }],
}, 'flipwert_pro_monthly', now), {
  productId: 'flipwert_pro_monthly',
  expiresAt: '2026-11-13T12:00:00.000Z',
});

for (const subscriptionState of [
  'SUBSCRIPTION_STATE_EXPIRED',
  'SUBSCRIPTION_STATE_PAUSED',
  'SUBSCRIPTION_STATE_ON_HOLD',
]) {
  assert.strictEqual(activeEntitlement({
    subscriptionState,
    lineItems: [{ productId: 'flipwert_pro_monthly', expiryTime: '2026-11-13T12:00:00Z' }],
  }, 'flipwert_pro_monthly', now), null);
}

assert.notStrictEqual(activeEntitlement({
  subscriptionState: 'SUBSCRIPTION_STATE_CANCELED',
  lineItems: [{ productId: 'flipwert_pro_monthly', expiryTime: '2026-11-13T12:00:00Z' }],
}, 'flipwert_pro_monthly', now), null, 'paid access remains valid until expiry');

assert.strictEqual(activeEntitlement({
  subscriptionState: 'SUBSCRIPTION_STATE_ACTIVE',
  lineItems: [{ productId: 'flipwert_pro_yearly', expiryTime: '2026-11-13T12:00:00Z' }],
}, 'flipwert_pro_monthly', now), null);

(async () => {
  const disabled = await verifyPlayEntitlement({
    productId: 'flipwert_pro_monthly',
    purchaseToken: 'valid-looking-purchase-token-value',
    env: {},
    now,
  });
  assert.deepStrictEqual(disabled, {
    verified: false,
    error: 'play_verification_not_configured',
  });

  const unsupported = await verifyPlayEntitlement({
    productId: 'other_product',
    purchaseToken: 'valid-looking-purchase-token-value',
    env: {},
    now,
  });
  assert.strictEqual(unsupported.error, 'unsupported_product');
  console.log('play_entitlement_test: ok');
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
