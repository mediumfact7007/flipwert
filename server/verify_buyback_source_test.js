'use strict';

const assert = require('assert');
const { verifyBuybackSource, verifyBuybackSourceMatrix } = require('./verify_buyback_source');

function fakeSource({ status, result, verificationResult, activationFingerprint }) {
  return {
    sourceStatus: () => status,
    fetchBuybackOffers: async () => result,
    ...(verificationResult === undefined ? {} : {
      fetchBuybackOffersForVerification: async () => verificationResult,
    }),
    ...(activationFingerprint === undefined ? {} : {
      activationFingerprint: () => activationFingerprint,
    }),
  };
}

(async () => {
  assert.deepStrictEqual(
    await verifyBuybackSource({ query: 'x', condition: 'like_new' }),
    { ok: false, reason: 'invalid_query' },
  );
  assert.deepStrictEqual(
    await verifyBuybackSource({ query: 'iPhone 15', condition: 'unknown' }),
    { ok: false, reason: 'invalid_condition' },
  );

  const disabled = fakeSource({
    status: { configured: false, readiness: 'missing_current_provider_approval' },
  });
  assert.deepStrictEqual(
    await verifyBuybackSource({
      query: 'iPhone 15 Pro 256 GB',
      condition: 'like_new',
      source: disabled,
    }),
    {
      ok: false,
      reason: 'source_not_ready',
      readiness: 'missing_current_provider_approval',
    },
  );

  const pendingActivation = fakeSource({
    status: { configured: false, readiness: 'missing_or_stale_validation' },
    verificationResult: {
      configured: true,
      items: [{
        provider_id: 'zoxs',
        condition: 'like_new',
        checked_at: '2026-09-24T08:00:00Z',
      }],
      best: null,
    },
    activationFingerprint: 'a'.repeat(64),
  });
  assert.deepStrictEqual(
    await verifyBuybackSource({
      query: 'iPhone 15 Pro 256 GB',
      condition: 'like_new',
      source: pendingActivation,
    }),
    {
      ok: true,
      readiness: 'validation_passed_activation_required',
      condition: 'like_new',
      offer_count: 1,
      provider_count: 1,
      provider_ids: ['zoxs'],
      newest_checked_at: '2026-09-24T08:00:00.000Z',
      activation_fingerprint: 'a'.repeat(64),
    },
  );

  const unavailable = fakeSource({
    status: { configured: true, readiness: 'ready' },
    result: { configured: true, items: [], best: null, unavailable: true },
  });
  assert.deepStrictEqual(
    await verifyBuybackSource({
      query: 'iPhone 15 Pro 256 GB',
      condition: 'like_new',
      source: unavailable,
    }),
    { ok: false, reason: 'source_unavailable', readiness: 'ready' },
  );

  const empty = fakeSource({
    status: { configured: true, readiness: 'ready' },
    result: { configured: true, items: [], best: null },
  });
  assert.deepStrictEqual(
    await verifyBuybackSource({
      query: 'iPhone 15 Pro 256 GB',
      condition: 'like_new',
      source: empty,
    }),
    { ok: false, reason: 'no_exact_matching_offer', readiness: 'ready' },
  );

  const mixedCondition = fakeSource({
    status: { configured: true, readiness: 'ready' },
    result: {
      configured: true,
      items: [{ provider_id: 'zoxs', condition: 'used_good' }],
      best: null,
    },
  });
  assert.deepStrictEqual(
    await verifyBuybackSource({
      query: 'iPhone 15 Pro 256 GB',
      condition: 'like_new',
      source: mixedCondition,
    }),
    {
      ok: false,
      reason: 'unexpected_condition_in_result',
      readiness: 'ready',
    },
  );

  const ready = fakeSource({
    status: { configured: true, readiness: 'ready' },
    result: {
      configured: true,
      items: [
        {
          provider_id: 'ZOXS',
          condition: 'like_new',
          checked_at: '2026-09-24T08:00:00Z',
        },
        {
          provider_id: 'zoxs',
          condition: 'like_new',
          checked_at: '2026-09-24T08:01:00Z',
        },
        {
          provider_id: 'clevertronic',
          condition: 'like_new',
          checked_at: '2026-09-24T07:59:00Z',
        },
      ],
    },
  });
  assert.deepStrictEqual(
    await verifyBuybackSource({
      query: '  iPhone   15 Pro 256 GB  ',
      condition: 'like_new',
      source: ready,
    }),
    {
      ok: true,
      readiness: 'ready',
      condition: 'like_new',
      offer_count: 3,
      provider_count: 2,
      provider_ids: ['clevertronic', 'zoxs'],
      newest_checked_at: '2026-09-24T08:01:00.000Z',
    },
  );

  assert.deepStrictEqual(
    await verifyBuybackSourceMatrix({ cases: [] }),
    { ok: false, reason: 'invalid_cases' },
  );

  const matrixSource = {
    sourceStatus: () => ({ configured: true, readiness: 'ready' }),
    fetchBuybackOffers: async (_query, condition) => ({
      configured: true,
      items: [{
        provider_id: condition === 'like_new' ? 'zoxs' : 'clevertronic',
        condition,
        checked_at: condition === 'like_new'
          ? '2026-09-24T08:00:00Z'
          : '2026-09-24T08:05:00Z',
      }],
      best: null,
    }),
  };
  assert.deepStrictEqual(
    await verifyBuybackSourceMatrix({
      cases: [
        { query: 'iPhone 15 Pro 256 GB', condition: 'like_new' },
        { query: 'Samsung Galaxy S24 Ultra 512 GB', condition: 'used_good' },
      ],
      source: matrixSource,
    }),
    {
      ok: true,
      readiness: 'ready',
      case_count: 2,
      offer_count: 2,
      provider_count: 2,
      provider_ids: ['clevertronic', 'zoxs'],
      newest_checked_at: '2026-09-24T08:05:00.000Z',
    },
  );

  const incompleteProviderMatrixSource = {
    sourceStatus: () => ({ configured: false, readiness: 'missing_or_stale_validation' }),
    approvedProviderIds: () => ['clevertronic', 'zoxs'],
    activationFingerprint: () => 'b'.repeat(64),
    fetchBuybackOffersForVerification: async (_query, condition) => ({
      configured: true,
      items: [{
        provider_id: 'zoxs',
        condition,
        checked_at: '2026-09-24T08:00:00Z',
      }],
      best: null,
    }),
  };
  assert.deepStrictEqual(
    await verifyBuybackSourceMatrix({
      cases: [
        { query: 'iPhone 15 Pro 256 GB', condition: 'like_new' },
        { query: 'Samsung Galaxy S24 Ultra 512 GB', condition: 'used_good' },
      ],
      source: incompleteProviderMatrixSource,
    }),
    {
      ok: false,
      reason: 'approved_provider_not_verified',
      missing_provider_ids: ['clevertronic'],
      verified_provider_ids: ['zoxs'],
      readiness: 'validation_incomplete',
    },
  );

  const completeProviderMatrixSource = {
    ...incompleteProviderMatrixSource,
    fetchBuybackOffersForVerification: async (query, condition) => ({
      configured: true,
      items: [{
        provider_id: query.startsWith('iPhone') ? 'zoxs' : 'clevertronic',
        condition,
        checked_at: '2026-09-24T08:00:00Z',
      }],
      best: null,
    }),
  };
  const completeProviderMatrix = await verifyBuybackSourceMatrix({
    cases: [
      { query: 'iPhone 15 Pro 256 GB', condition: 'like_new' },
      { query: 'Samsung Galaxy S24 Ultra 512 GB', condition: 'used_good' },
    ],
    source: completeProviderMatrixSource,
  });
  assert.strictEqual(completeProviderMatrix.ok, true);
  assert.deepStrictEqual(completeProviderMatrix.provider_ids, ['clevertronic', 'zoxs']);
  assert.strictEqual(completeProviderMatrix.activation_fingerprint, 'b'.repeat(64));

  const failingMatrixSource = {
    sourceStatus: () => ({ configured: true, readiness: 'ready' }),
    fetchBuybackOffers: async (_query, condition) => ({
      configured: true,
      items: condition === 'like_new'
        ? [{ provider_id: 'zoxs', condition, checked_at: '2026-09-24T08:00:00Z' }]
        : [],
      best: null,
    }),
  };
  assert.deepStrictEqual(
    await verifyBuybackSourceMatrix({
      cases: [
        { query: 'iPhone 15 Pro 256 GB', condition: 'like_new' },
        { query: 'Samsung Galaxy S24 Ultra 512 GB', condition: 'used_good' },
      ],
      source: failingMatrixSource,
    }),
    {
      ok: false,
      reason: 'case_failed',
      failed_case_index: 1,
      case_reason: 'no_exact_matching_offer',
      readiness: 'ready',
    },
  );

  console.log('buyback source verification tests passed');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
