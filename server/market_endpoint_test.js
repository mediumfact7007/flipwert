'use strict';

const assert = require('assert');
const http = require('http');
const { spawn } = require('child_process');
const { ebayItems } = require('./index');

const ebayPayload = {
  itemSummaries: [{
    title: 'Apple iPhone 15 Pro 256GB Titan',
    price: { value: '800', currency: 'EUR' },
    shippingOptions: [{ shippingCost: { value: '5' } }],
    condition: 'GOOD',
    itemWebUrl: 'https://www.ebay.de/itm/123',
  }],
};

assert.strictEqual(ebayItems(ebayPayload, 'sandbox')[0].live, false);
assert.strictEqual(ebayItems(ebayPayload, 'production')[0].live, true);
assert.strictEqual(ebayItems(ebayPayload, 'production')[0].condition, 'Gut');
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
    console.log('market_endpoint_test: ok');
  } finally {
    child.kill();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
