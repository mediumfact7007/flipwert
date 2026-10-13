'use strict';

const assert = require('assert');
const http = require('http');
const { spawn } = require('child_process');
const { ebayItems } = require('./index');

const ebayPayload = {
  itemSummaries: [{
    title: 'Apple iPhone 15 Pro 256GB Titan',
    price: { value: '800', currency: 'EUR' },
    shippingOptions: [{ shippingCost: { value: '5', currency: 'EUR' } }],
    condition: 'GOOD',
    itemWebUrl: 'https://www.ebay.de/itm/123',
  }],
};

const checkedAt = '2026-10-11T23:45:00.000Z';
assert.strictEqual(ebayItems(ebayPayload, 'sandbox', false, checkedAt)[0].live, false);
assert.strictEqual(
  ebayItems(ebayPayload, 'production')[0].live,
  false,
  'production credentials alone must not create LIVE evidence',
);
assert.strictEqual(ebayItems(ebayPayload, 'production', true)[0].live, true);
assert.strictEqual(ebayItems(ebayPayload, 'production', true)[0].condition, 'Gut');
assert.strictEqual(
  ebayItems(ebayPayload, 'production', true, checkedAt)[0].checked_at,
  checkedAt,
  'market evidence must carry its exact fetch time',
);
assert.deepStrictEqual(ebayItems({ itemSummaries: [
  { ...ebayPayload.itemSummaries[0], condition: 'NEW' },
] }, 'production'), [], 'new items must not influence used resale valuation');
assert.deepStrictEqual(ebayItems({ itemSummaries: [
  { ...ebayPayload.itemSummaries[0], condition: 'CERTIFIED_REFURBISHED' },
] }, 'production'), [], 'refurbished items must stay separate from used valuation');
assert.deepStrictEqual(ebayItems({ itemSummaries: [
  { ...ebayPayload.itemSummaries[0], condition: 'UNKNOWN_FUTURE_VALUE' },
] }, 'production'), [], 'unknown conditions must fail closed');
assert.strictEqual(ebayItems({ itemSummaries: [
  { ...ebayPayload.itemSummaries[0], condition: 'Gebraucht' },
] }, 'production')[0].condition, 'Gebraucht');
assert.deepStrictEqual(ebayItems({ itemSummaries: [
  { ...ebayPayload.itemSummaries[0], price: { value: '800' } },
] }, 'production'), [], 'missing price currency must fail closed');
assert.deepStrictEqual(ebayItems({ itemSummaries: [
  { ...ebayPayload.itemSummaries[0], price: { value: '800', currency: 'USD' } },
] }, 'production'), [], 'non-EUR prices must not be treated as EUR');
assert.deepStrictEqual(ebayItems({ itemSummaries: [
  { ...ebayPayload.itemSummaries[0], shippingOptions: [] },
] }, 'production'), [], 'missing shipping cost must fail closed');
assert.deepStrictEqual(ebayItems({ itemSummaries: [
  { ...ebayPayload.itemSummaries[0], shippingOptions: [{ shippingCost: { value: '5' } }] },
] }, 'production'), [], 'missing shipping currency must fail closed');
assert.deepStrictEqual(ebayItems({ itemSummaries: [
  { ...ebayPayload.itemSummaries[0], shippingOptions: [{ shippingCost: { value: '5', currency: 'USD' } }] },
] }, 'production'), [], 'non-EUR shipping must not be treated as EUR');
assert.deepStrictEqual(ebayItems({ itemSummaries: [
  { ...ebayPayload.itemSummaries[0], shippingOptions: [{ shippingCost: { value: '-1', currency: 'EUR' } }] },
] }, 'production'), [], 'negative shipping cost must fail closed');
assert.strictEqual(ebayItems({ itemSummaries: [
  { ...ebayPayload.itemSummaries[0], shippingOptions: [{ shippingCost: { value: '0', currency: 'EUR' } }] },
] }, 'production')[0].shipping, 0, 'explicit free shipping remains valid');

const port = 18082;
const child = spawn(process.execPath, ['index.js'], {
  cwd: __dirname,
  env: {
    ...process.env,
    PORT: String(port),
    EBAY_CLIENT_ID: '',
    EBAY_CLIENT_SECRET: '',
    KEEPA_API_KEY: '',
  },
  stdio: ['ignore', 'ignore', 'inherit'],
});

function get(path) {
  return new Promise((resolve, reject) => {
    const request = http.get({ hostname: '127.0.0.1', port, path }, (response) => {
      let body = '';
      response.setEncoding('utf8');
      response.on('data', (chunk) => { body += chunk; });
      response.on('end', () => resolve({ status: response.statusCode, body }));
    });
    request.on('error', reject);
  });
}

function post(path, payload) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(payload);
    const request = http.request({
      hostname: '127.0.0.1',
      port,
      path,
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'content-length': Buffer.byteLength(body),
      },
    }, (response) => {
      let responseBody = '';
      response.setEncoding('utf8');
      response.on('data', (chunk) => { responseBody += chunk; });
      response.on('end', () => resolve({ status: response.statusCode, body: responseBody }));
    });
    request.on('error', reject);
    request.end(body);
  });
}

async function waitForServer() {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    try {
      if ((await get('/health')).status === 200) return;
    } catch (_) {
      // Server startup is asynchronous; retry briefly below.
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }
  throw new Error('server_start_timeout');
}

(async () => {
  try {
    await waitForServer();
    const response = await get('/v1/market/search?source=ebay_de&q=Apple%20iPhone%2015%20Pro%20256GB');
    assert.strictEqual(response.status, 200);
    const payload = JSON.parse(response.body);
    assert.deepStrictEqual(payload.items, []);
    assert.deepStrictEqual(payload.meta, {
      count: 0,
      raw_count: 0,
      rejected_count: 0,
    });
    const entitlement = await post('/v1/entitlements/google-play', {
      product_id: 'flipwert_pro_monthly',
      purchase_token: 'valid-looking-purchase-token-value',
    });
    assert.strictEqual(entitlement.status, 503);
    assert.deepStrictEqual(JSON.parse(entitlement.body), {
      verified: false,
      error: 'play_verification_not_configured',
    });
    console.log('market_endpoint_test: ok');
  } finally {
    child.kill();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
