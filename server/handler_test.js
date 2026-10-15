'use strict';

const assert = require('node:assert/strict');
const { handle } = require('./handler');

(async () => {
  const health = await handle(new Request('https://api.example/health'), {
    EBAY_ENV: 'production',
  });
  assert.equal(health.status, 200);
  assert.deepEqual(await health.json(), {
    ok: true,
    service: 'flipwert-api',
    version: '0.11.0',
    ebay_environment: 'production',
  });

  const status = await handle(new Request('https://api.example/v1/status'), {});
  assert.equal(status.status, 200);
  const statusBody = await status.json();
  assert.equal(statusBody.sources.ebay_de.environment, 'sandbox');
  assert.equal(statusBody.monetization.play_verification_configured, false);

  const retiredImport = await handle(
    new Request('https://api.example/v1/listing/resolve?url=https://example.com'),
    {},
  );
  assert.equal(retiredImport.status, 410);
  assert.deepEqual(await retiredImport.json(), {
    error: 'listing_import_disabled',
    manual_entry: true,
  });

  console.log('handler_test: ok');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
