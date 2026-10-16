import assert from 'node:assert/strict';
import worker from './index.mjs';

const cases = [
  ['GET', '/health', null, 200],
  ['GET', '/v1/status', null, 200],
  ['GET', '/v1/market/search', null, 400],
  ['GET', '/v1/buyback/search', null, 400],
  ['GET', '/v1/listing/resolve', null, 410],
  [
    'POST',
    '/v1/entitlements/google-play',
    JSON.stringify({ product_id: 'invalid', purchase_token: 'invalid' }),
    403,
  ],
];

for (const [method, path, body, expectedStatus] of cases) {
  const response = await worker.fetch(
    new Request(`https://flipwert-api.example${path}`, {
      method,
      body,
      headers: body ? { 'content-type': 'application/json' } : undefined,
    }),
    {},
  );
  assert.equal(response.status, expectedStatus, `${method} ${path}`);
}

console.log('worker endpoint tests passed');

