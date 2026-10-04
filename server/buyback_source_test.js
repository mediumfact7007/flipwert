'use strict';

const assert = require('assert');

const MODULE = require.resolve('./buyback_source');

function loadSource(env = {}) {
  const previous = {
    BUYBACK_SOURCE_URL: process.env.BUYBACK_SOURCE_URL,
    BUYBACK_SOURCE_TOKEN: process.env.BUYBACK_SOURCE_TOKEN,
    BUYBACK_SOURCE_TIMEOUT_MS: process.env.BUYBACK_SOURCE_TIMEOUT_MS,
    BUYBACK_SOURCE_CACHE_TTL_MS: process.env.BUYBACK_SOURCE_CACHE_TTL_MS,
    BUYBACK_SOURCE_POLICY_ACK: process.env.BUYBACK_SOURCE_POLICY_ACK,
    BUYBACK_SOURCE_APPROVALS_JSON: process.env.BUYBACK_SOURCE_APPROVALS_JSON,
    BUYBACK_SOURCE_ACTIVATION_FINGERPRINT: process.env.BUYBACK_SOURCE_ACTIVATION_FINGERPRINT,
  };
  if (env.url === undefined) delete process.env.BUYBACK_SOURCE_URL;
  else process.env.BUYBACK_SOURCE_URL = env.url;
  if (env.token === undefined) delete process.env.BUYBACK_SOURCE_TOKEN;
  else process.env.BUYBACK_SOURCE_TOKEN = env.token;
  if (env.timeout === undefined) delete process.env.BUYBACK_SOURCE_TIMEOUT_MS;
  else process.env.BUYBACK_SOURCE_TIMEOUT_MS = String(env.timeout);
  if (env.cacheTtl === undefined) delete process.env.BUYBACK_SOURCE_CACHE_TTL_MS;
  else process.env.BUYBACK_SOURCE_CACHE_TTL_MS = String(env.cacheTtl);
  if (env.policyAck === undefined) delete process.env.BUYBACK_SOURCE_POLICY_ACK;
  else process.env.BUYBACK_SOURCE_POLICY_ACK = env.policyAck;
  if (env.approvals === undefined) delete process.env.BUYBACK_SOURCE_APPROVALS_JSON;
  else process.env.BUYBACK_SOURCE_APPROVALS_JSON = env.approvals;
  if (env.activation === undefined || env.activation === 'auto') {
    delete process.env.BUYBACK_SOURCE_ACTIVATION_FINGERPRINT;
  } else {
    process.env.BUYBACK_SOURCE_ACTIVATION_FINGERPRINT = env.activation;
  }
  delete require.cache[MODULE];
  let source = require('./buyback_source');
  if (env.activation === 'auto') {
    const fingerprint = source.activationFingerprint(
      env.activationNow || Date.parse('2026-09-20T08:00:00Z'),
    );
    process.env.BUYBACK_SOURCE_ACTIVATION_FINGERPRINT = fingerprint || '';
    delete require.cache[MODULE];
    source = require('./buyback_source');
  }
  return {
    source,
    restore() {
      delete require.cache[MODULE];
      for (const [key, value] of Object.entries(previous)) {
        if (value === undefined) delete process.env[key];
        else process.env[key] = value;
      }
    },
  };
}

function approvedEnv(overrides = {}) {
  return {
    url: 'https://partner.example/quotes',
    cacheTtl: 0,
    policyAck: 'approved-feed-and-price-display-v1',
    activation: 'auto',
    approvals: JSON.stringify([{
      provider_id: 'clevertronic',
      provider_name: 'Clevertronic',
      approval_reference: 'partner-contract-2026-01',
      reviewed_at: '2026-09-01T10:00:00Z',
      valid_until: '2099-12-31T23:59:59Z',
      feed_access: true,
      price_display: true,
      offer_links: true,
      provider_identity_display: true, affiliate_links: false,
      feed_hosts: ['partner.example'],
      offer_hosts: ['partner.example'],
      max_cache_seconds: 60,
    }]),
    ...overrides,
  };
}

(async () => {
  let loaded = loadSource();
  assert.strictEqual(loaded.source.configured(), false);
  assert.strictEqual(loaded.source.sourceStatus().readiness, 'missing_source_url');
  assert.deepStrictEqual(await loaded.source.fetchBuybackOffers('iPhone 15', 'like_new'), {
    configured: false,
    items: [],
    best: null,
  });
  loaded.restore();

  loaded = loadSource({ url: 'http://partner.example/quotes' });
  assert.strictEqual(loaded.source.configured(), false, 'plain HTTP must never become a live source');
  assert.strictEqual(loaded.source.sourceStatus().readiness, 'invalid_source_url');
  loaded.restore();

  loaded = loadSource({ url: 'https://partner.example/quotes' });
  assert.strictEqual(loaded.source.configured(), false, 'a URL alone must never enable live provider prices');
  assert.strictEqual(loaded.source.sourceStatus().rights_gate, 'not_approved_or_expired');
  assert.strictEqual(loaded.source.sourceStatus().readiness, 'missing_policy_ack');
  loaded.restore();

  loaded = loadSource(approvedEnv({ url: 'https://unapproved-feed.example/quotes' }));
  assert.strictEqual(loaded.source.configured(), false, 'approval must be bound to the configured feed host');
  assert.strictEqual(loaded.source.sourceStatus().readiness, 'source_host_not_approved');
  loaded.restore();

  const wildcardHostApproval = JSON.parse(approvedEnv().approvals);
  wildcardHostApproval[0].feed_hosts = ['*.partner.example'];
  loaded = loadSource(approvedEnv({ approvals: JSON.stringify(wildcardHostApproval) }));
  assert.strictEqual(loaded.source.configured(), false, 'host approvals must be exact, not wildcard patterns');
  loaded.restore();

  loaded = loadSource(approvedEnv({ policyAck: 'affiliate-link-only' }));
  assert.strictEqual(loaded.source.configured(), false, 'affiliate access is not price-display approval');
  loaded.restore();

  loaded = loadSource(approvedEnv({ activation: '' }));
  assert.strictEqual(
    loaded.source.configured(),
    false,
    'rights alone must not activate a feed before representative validation',
  );
  assert.strictEqual(
    loaded.source.sourceStatus().readiness,
    'missing_or_stale_validation',
  );
  const baselineFingerprint = loaded.source.activationFingerprint();
  assert.match(
    baselineFingerprint,
    /^[a-f0-9]{64}$/,
    'a rights-approved pre-activation source must expose a non-secret validation fingerprint',
  );
  loaded.restore();

  const renamedProviderApproval = JSON.parse(approvedEnv().approvals);
  renamedProviderApproval[0].provider_name = 'Clevertronic Partner';
  loaded = loadSource(approvedEnv({
    activation: '',
    approvals: JSON.stringify(renamedProviderApproval),
  }));
  assert.notStrictEqual(
    loaded.source.activationFingerprint(),
    baselineFingerprint,
    'changing the approved visible provider identity must invalidate activation',
  );
  loaded.restore();

  const reducedCacheApproval = JSON.parse(approvedEnv().approvals);
  reducedCacheApproval[0].max_cache_seconds = 15;
  loaded = loadSource(approvedEnv({
    activation: '',
    approvals: JSON.stringify(reducedCacheApproval),
  }));
  assert.notStrictEqual(
    loaded.source.activationFingerprint(),
    baselineFingerprint,
    'changing the contractual cache limit must invalidate activation',
  );
  loaded.restore();

  loaded = loadSource(approvedEnv({ approvals: '[]' }));
  assert.strictEqual(loaded.source.configured(), false, 'provider approvals are required');
  loaded.restore();

  loaded = loadSource(approvedEnv({ approvals: '{broken-json' }));
  assert.strictEqual(loaded.source.configured(), false, 'malformed approval metadata must fail closed');
  loaded.restore();

  const missingProviderName = JSON.parse(approvedEnv().approvals);
  delete missingProviderName[0].provider_name;
  loaded = loadSource(approvedEnv({ approvals: JSON.stringify(missingProviderName) }));
  assert.strictEqual(
    loaded.source.configured(),
    false,
    'an approval must bind the provider ID to its visible name',
  );
  loaded.restore();

  for (const invalidCacheLimit of [undefined, -1, 301, 1.5, '60']) {
    const invalidCacheApproval = JSON.parse(approvedEnv().approvals);
    if (invalidCacheLimit === undefined) {
      delete invalidCacheApproval[0].max_cache_seconds;
    } else {
      invalidCacheApproval[0].max_cache_seconds = invalidCacheLimit;
    }
    loaded = loadSource(approvedEnv({ approvals: JSON.stringify(invalidCacheApproval) }));
    assert.strictEqual(
      loaded.source.configured(),
      false,
      `invalid provider cache limit must fail closed: ${String(invalidCacheLimit)}`,
    );
    loaded.restore();
  }

  loaded = loadSource(approvedEnv({ approvals: JSON.stringify([{
    provider_id: 'clevertronic', provider_name: 'Clevertronic',
    approval_reference: 'expired-contract',
    reviewed_at: '2019-01-01T00:00:00Z', valid_until: '2020-01-01T00:00:00Z',
    feed_access: true, price_display: true, offer_links: true,
    provider_identity_display: true, affiliate_links: false,
    feed_hosts: ['partner.example'],
    offer_hosts: ['partner.example'],
    max_cache_seconds: 60,
  }]) }));
  assert.strictEqual(loaded.source.configured(), false, 'expired approval must fail closed');
  loaded.restore();

  for (const missingRight of ['feed_access', 'price_display', 'offer_links', 'provider_identity_display']) {
    const approval = {
      provider_id: 'clevertronic', provider_name: 'Clevertronic',
      approval_reference: 'limited-contract',
      reviewed_at: '2026-09-01T10:00:00Z', valid_until: '2099-12-31T23:59:59Z',
      feed_access: true, price_display: true, offer_links: true,
      provider_identity_display: true, affiliate_links: false,
      feed_hosts: ['partner.example'],
      offer_hosts: ['partner.example'],
      max_cache_seconds: 60,
    };
    approval[missingRight] = false;
    loaded = loadSource(approvedEnv({ approvals: JSON.stringify([approval]) }));
    assert.strictEqual(loaded.source.configured(), false, `${missingRight} must be explicitly approved`);
    loaded.restore();
  }

  loaded = loadSource(approvedEnv({ approvals: JSON.stringify([{
    provider_id: 'clevertronic', provider_name: 'Clevertronic',
    approval_reference: 'future-review',
    reviewed_at: '2099-01-01T00:00:00Z', valid_until: '2099-12-31T23:59:59Z',
    feed_access: true, price_display: true, offer_links: true,
    provider_identity_display: true, affiliate_links: false,
    feed_hosts: ['partner.example'],
    offer_hosts: ['partner.example'],
    max_cache_seconds: 60,
  }]) }));
  assert.strictEqual(loaded.source.configured(), false, 'a future review timestamp must fail closed');
  loaded.restore();

  const duplicateApproval = {
    provider_id: 'clevertronic', provider_name: 'Clevertronic',
    approval_reference: 'duplicate-contract',
    reviewed_at: '2026-09-01T10:00:00Z', valid_until: '2099-12-31T23:59:59Z',
    feed_access: true, price_display: true, offer_links: true,
    provider_identity_display: true, affiliate_links: false,
    feed_hosts: ['partner.example'],
    offer_hosts: ['partner.example'],
    max_cache_seconds: 60,
  };
  loaded = loadSource(approvedEnv({ approvals: JSON.stringify([duplicateApproval, duplicateApproval]) }));
  assert.strictEqual(loaded.source.configured(), false, 'duplicate provider approvals must fail closed');
  loaded.restore();

  loaded = loadSource({ url: 'https://user:password@partner.example/quotes' });
  assert.strictEqual(loaded.source.configured(), false, 'credentials must not be embedded in the partner URL');
  loaded.restore();

  for (const url of ['https://localhost/quotes', 'https://partner.local/quotes', 'https://127.0.0.1/quotes', 'https://10.0.0.8/quotes', 'https://169.254.1.2/quotes', 'https://192.168.1.5/quotes', 'https://[::1]/quotes', 'https://[fd12:3456::1]/quotes']) {
    loaded = loadSource({ url });
    assert.strictEqual(loaded.source.configured(), false, `non-public partner host must be rejected: ${url}`);
    loaded.restore();
  }

  loaded = loadSource(approvedEnv({ token: 'server-secret' }));
  let fetchCalls = 0;
  const emptyResult = await loaded.source.fetchBuybackOffers('  ', 'like_new', {
    fetchImpl: async () => { fetchCalls += 1; throw new Error('must not fetch an empty query'); },
  });
  assert.deepStrictEqual(emptyResult, { configured: true, items: [], best: null });
  assert.strictEqual(fetchCalls, 0);

  const invalidConditionResult = await loaded.source.fetchBuybackOffers('iPhone 15', 'mint-ish', {
    fetchImpl: async () => { fetchCalls += 1; throw new Error('must not fetch an invalid condition'); },
  });
  assert.deepStrictEqual(invalidConditionResult, { configured: true, items: [], best: null });
  assert.strictEqual(fetchCalls, 0, 'invalid conditions must not consume partner requests');

  const missingConditionResult = await loaded.source.fetchBuybackOffers('iPhone 15', '', {
    fetchImpl: async () => { fetchCalls += 1; throw new Error('must not fetch without an exact condition'); },
  });
  assert.deepStrictEqual(missingConditionResult, { configured: true, items: [], best: null });
  assert.strictEqual(fetchCalls, 0, 'missing conditions must not consume partner requests');

  const outageResult = await loaded.source.fetchBuybackOffers('iPhone 15', 'like_new', {
    fetchImpl: async () => { throw new Error('partner offline'); },
  });
  assert.deepStrictEqual(outageResult, { configured: true, items: [], best: null, unavailable: true });
  loaded.restore();

  loaded = loadSource(approvedEnv({ timeout: 1 }));
  let timeoutSignal;
  const timeoutResult = await loaded.source.fetchBuybackOffers('iPhone 15', 'like_new', {
    fetchImpl: async (_url, options) => {
      timeoutSignal = options.signal;
      return new Promise((resolve, reject) => {
        options.signal.addEventListener('abort', () => reject(new Error('aborted')), { once: true });
      });
    },
  });
  assert.strictEqual(timeoutSignal.aborted, true, 'partner request must be aborted at the bounded timeout');
  assert.deepStrictEqual(timeoutResult, { configured: true, items: [], best: null, unavailable: true });
  loaded.restore();

  loaded = loadSource(approvedEnv({ token: 'server-secret' }));
  let requestedUrl;
  let requestedOptions;
  const now = Date.parse('2026-09-20T08:00:00Z');
  const result = await loaded.source.fetchBuybackOffers(' Apple iPhone 15 Pro 256 GB ', 'like_new', {
    now,
    fetchImpl: async (url, options) => {
      requestedUrl = new URL(url.toString());
      requestedOptions = options;
      return {
        ok: true,
        async json() {
          return { items: [{
            provider_id: 'clevertronic', provider_name: 'Clevertronic', product_id: 'iphone-15-pro-256',
            matched_title: 'Apple iPhone 15 Pro 256 GB', condition: 'like_new', price: 615,
            mandatory_deductions_eur: 0, currency: 'EUR',
            offer_url: 'https://partner.example/offer/123', checked_at: '2026-09-20T07:55:00Z',
            price_kind: 'indicative_buyback', payout_type: 'cash', requires_inspection: true, match_confidence: 0.98,
          }] };
        },
      };
    },
  });

  assert.strictEqual(requestedUrl.origin + requestedUrl.pathname, 'https://partner.example/quotes');
  assert.strictEqual(requestedUrl.searchParams.get('q'), 'Apple iPhone 15 Pro 256 GB');
  assert.strictEqual(requestedUrl.searchParams.get('condition'), 'like_new');
  assert.strictEqual(requestedOptions.headers.authorization, 'Bearer server-secret');
  assert.strictEqual(requestedOptions.redirect, 'error', 'partner auth requests must never follow redirects');
  assert.strictEqual(result.configured, true);
  assert.strictEqual(result.items.length, 1);
  assert.strictEqual(result.best.provider_id, 'clevertronic');
  assert.strictEqual(result.best.price, 615);
  assert.strictEqual(result.best.affiliate_link, false);

  const lateVariantQuery = `${'Apple iPhone 15 Pro '.padEnd(165, 'x')} 256 GB`;
  assert.ok(lateVariantQuery.length > 160 && lateVariantQuery.length <= 180);
  let forwardedLateVariant;
  await loaded.source.fetchBuybackOffers(lateVariantQuery, 'like_new', {
    now,
    fetchImpl: async (url) => {
      forwardedLateVariant = new URL(url.toString()).searchParams.get('q');
      return { ok: true, async json() { return { items: [] }; } };
    },
  });
  assert.strictEqual(
    forwardedLateVariant,
    lateVariantQuery,
    'the partner query must retain variant attributes after character 160',
  );

  const mixed = await loaded.source.fetchBuybackOffers('Apple iPhone 15 Pro 256 GB', 'like_new', {
    now,
    fetchImpl: async () => ({
      ok: true,
      async json() {
        const good = {
          provider_id: 'clevertronic', provider_name: 'Clevertronic', product_id: 'iphone-15-pro-256',
          matched_title: 'Apple iPhone 15 Pro 256 GB', condition: 'like_new', price: 615,
          mandatory_deductions_eur: 0,
          currency: 'EUR', offer_url: 'https://partner.example/offer/good',
          checked_at: '2026-09-20T07:55:00Z', price_kind: 'indicative_buyback', payout_type: 'cash',
          match_confidence: 0.98,
        };
        return { items: [good, {
          ...good, provider_id: 'wrong-variant', product_id: 'iphone-15-pro-max-256',
          matched_title: 'Apple iPhone 15 Pro Max 256 GB', price: 900, match_confidence: 1,
        }, {
          ...good, condition: 'used_good', price: 850,
        }, {
          ...good, offer_url: 'https://unapproved-offer.example/offer/redirected', price: 999,
        }, {
          ...good, provider_name: 'Different Brand', price: 998,
        }, {
          ...good, matched_title: 'Samsung iPhone 15 Pro 256 GB', price: 997,
        }, {
          ...good, provider_id: 'store-credit', payout_type: 'store_credit', price: 999,
        }, {
          ...good, provider_id: 'missing-deductions', mandatory_deductions_eur: undefined,
        }, {
          ...good, provider_id: 'string-deductions', mandatory_deductions_eur: '0',
        }] };
      },
    }),
  });
  assert.strictEqual(mixed.items.length, 1, 'wrong variants, conditions, manufacturers, provider names, offer hosts, non-cash payouts and untyped deductions must not enter the comparison');
  assert.strictEqual(mixed.items[0].condition, 'like_new', 'only the explicitly requested condition may reach the app');
  assert.strictEqual(mixed.best.provider_id, 'clevertronic');

  const blockedAffiliate = await loaded.source.fetchBuybackOffers(
    'Apple iPhone 15 Pro 256 GB', 'like_new', {
      now,
      fetchImpl: async () => ({
        ok: true,
        async json() {
          return { items: [{
            provider_id: 'clevertronic', provider_name: 'Clevertronic',
            product_id: 'iphone-15-pro-256',
            matched_title: 'Apple iPhone 15 Pro 256 GB',
            condition: 'like_new', price: 620, mandatory_deductions_eur: 0, currency: 'EUR',
            offer_url: 'https://partner.example/offer/affiliate',
            checked_at: '2026-09-20T07:55:00Z',
            price_kind: 'indicative_buyback', payout_type: 'cash', match_confidence: 0.98,
            affiliate_link: true,
          }] };
        },
      }),
    },
  );
  assert.strictEqual(
    blockedAffiliate.items.length,
    0,
    'affiliate links must fail closed without explicit affiliate rights',
  );
  loaded.restore();

  const affiliateApproval = JSON.parse(approvedEnv().approvals);
  affiliateApproval[0].affiliate_links = true;
  loaded = loadSource(approvedEnv({ approvals: JSON.stringify(affiliateApproval) }));
  const approvedAffiliate = await loaded.source.fetchBuybackOffers(
    'Apple iPhone 15 Pro 256 GB', 'like_new', {
      now,
      fetchImpl: async () => ({
        ok: true,
        async json() {
          return { items: [{
            provider_id: 'clevertronic', provider_name: 'Clevertronic',
            product_id: 'iphone-15-pro-256',
            matched_title: 'Apple iPhone 15 Pro 256 GB',
            condition: 'like_new', price: 620, mandatory_deductions_eur: 0, currency: 'EUR',
            offer_url: 'https://partner.example/offer/affiliate',
            checked_at: '2026-09-20T07:55:00Z',
            price_kind: 'indicative_buyback', payout_type: 'cash', match_confidence: 0.98,
            affiliate_link: true,
          }] };
        },
      }),
    },
  );
  assert.strictEqual(approvedAffiliate.items.length, 1);
  assert.strictEqual(approvedAffiliate.items[0].affiliate_link, true);
  loaded.restore();

  loaded = loadSource(approvedEnv({ approvals: JSON.stringify([
    {
      provider_id: 'clevertronic', provider_name: 'Clevertronic',
      approval_reference: 'clevertronic-contract',
      reviewed_at: '2026-09-01T10:00:00Z', valid_until: '2099-12-31T23:59:59Z',
      feed_access: true, price_display: true, offer_links: true,
      provider_identity_display: true, affiliate_links: false,
      feed_hosts: ['partner.example'],
      offer_hosts: ['partner.example'],
      max_cache_seconds: 60,
    },
    {
      provider_id: 'zoxs', provider_name: 'ZOXS',
      approval_reference: 'zoxs-contract',
      reviewed_at: '2026-09-02T10:00:00Z', valid_until: '2099-12-31T23:59:59Z',
      feed_access: true, price_display: true, offer_links: true,
      provider_identity_display: true, affiliate_links: false,
      feed_hosts: ['partner.example'],
      offer_hosts: ['partner.example'],
      max_cache_seconds: 60,
    },
  ]) }));
  const approvalFiltered = await loaded.source.fetchBuybackOffers('Apple iPhone 15 Pro 256 GB', 'like_new', {
    now,
    fetchImpl: async () => ({
      ok: true,
      async json() {
        const offer = {
          provider_name: 'Clevertronic', product_id: 'iphone-15-pro-256',
          matched_title: 'Apple iPhone 15 Pro 256 GB', condition: 'like_new', price: 615,
          mandatory_deductions_eur: 0,
          currency: 'EUR', offer_url: 'https://partner.example/offer/good',
          checked_at: '2026-09-20T07:55:00Z', price_kind: 'indicative_buyback', payout_type: 'cash',
          requires_inspection: true, match_confidence: 0.98,
        };
        return { items: [
          { ...offer, provider_id: 'clevertronic' },
          { ...offer, provider_id: 'unapproved-provider', provider_name: 'Unknown', price: 999 },
        ] };
      },
    }),
  });
  assert.strictEqual(approvalFiltered.items.length, 1, 'unapproved feed providers must never become live offers');
  assert.strictEqual(approvalFiltered.items[0].provider_id, 'clevertronic');
  assert.deepStrictEqual(loaded.source.sourceStatus(), {
    configured: true,
    mode: 'approved_partner_adapter',
    data_kind: 'indicative_buyback',
    max_age_hours: 24,
    cache_ttl_seconds: 0,
    minimum_match_confidence: 0.9,
    rights_gate: 'approved',
    activation_gate: 'validated',
    readiness: 'ready',
    approval_model: 'per_provider_identity_hosts_affiliate_cache_and_activation_v6',
    activation_model: 'configuration_fingerprint_v1',
    approved_provider_count: 2,
  });
  loaded.restore();

  loaded = loadSource(approvedEnv({ approvals: JSON.stringify([
    {
      provider_id: 'clevertronic', provider_name: 'Clevertronic',
      approval_reference: 'expired-clevertronic-contract',
      reviewed_at: '2019-01-01T00:00:00Z', valid_until: '2020-01-01T00:00:00Z',
      feed_access: true, price_display: true, offer_links: true,
      provider_identity_display: true, affiliate_links: false,
      feed_hosts: ['partner.example'],
      offer_hosts: ['partner.example'],
      max_cache_seconds: 60,
    },
    {
      provider_id: 'zoxs', provider_name: 'ZOXS',
      approval_reference: 'current-zoxs-contract',
      reviewed_at: '2026-09-01T10:00:00Z', valid_until: '2099-12-31T23:59:59Z',
      feed_access: true, price_display: true, offer_links: true,
      provider_identity_display: true, affiliate_links: false,
      feed_hosts: ['partner.example'],
      offer_hosts: ['partner.example'],
      max_cache_seconds: 60,
    },
  ]) }));
  assert.strictEqual(loaded.source.configured(), true, 'one expired provider must not disable another current approval');
  assert.strictEqual(loaded.source.sourceStatus().approved_provider_count, 1);
  loaded.restore();

  loaded = loadSource(approvedEnv({ cacheTtl: 60000 }));
  let cachedFetchCalls = 0;
  const cachedNow = Date.parse('2026-09-20T08:00:00Z');
  const cachedResponse = () => ({
    ok: true,
    async json() {
      return { items: [{
        provider_id: 'clevertronic', provider_name: 'Clevertronic',
        product_id: 'iphone-15-pro-256', matched_title: 'Apple iPhone 15 Pro 256 GB',
        condition: 'like_new', price: 615, mandatory_deductions_eur: 0, currency: 'EUR',
        offer_url: 'https://partner.example/offer/cached',
        checked_at: '2026-09-20T07:55:00Z', price_kind: 'indicative_buyback', payout_type: 'cash',
        requires_inspection: true, match_confidence: 0.98,
      }] };
    },
  });
  const cachedFetch = async () => {
    cachedFetchCalls += 1;
    return cachedResponse();
  };
  const firstCached = await loaded.source.fetchBuybackOffers(
    'Apple iPhone 15 Pro 256 GB', 'like_new',
    { now: cachedNow, fetchImpl: cachedFetch },
  );
  const secondCached = await loaded.source.fetchBuybackOffers(
    ' apple iphone 15 pro 256 gb ', 'like_new',
    { now: cachedNow + 30000, fetchImpl: cachedFetch },
  );
  assert.strictEqual(cachedFetchCalls, 1, 'equivalent product/condition rechecks should reuse the short cache');
  assert.deepStrictEqual(secondCached, firstCached);
  await loaded.source.fetchBuybackOffers(
    'Apple iPhone 15 Pro 256 GB', 'like_new',
    { now: cachedNow + 60001, fetchImpl: cachedFetch },
  );
  assert.strictEqual(cachedFetchCalls, 2, 'expired cache entries must refresh from the partner');
  loaded.restore();

  const cappedCacheApproval = JSON.parse(approvedEnv().approvals);
  cappedCacheApproval[0].max_cache_seconds = 15;
  cappedCacheApproval.push({
    ...cappedCacheApproval[0],
    provider_id: 'zoxs',
    provider_name: 'ZOXS',
    approval_reference: 'zoxs-contract-2026-01',
    max_cache_seconds: 10,
  });
  loaded = loadSource(approvedEnv({
    cacheTtl: 60000,
    approvals: JSON.stringify(cappedCacheApproval),
  }));
  let cappedCacheFetchCalls = 0;
  const cappedCacheFetch = async () => {
    cappedCacheFetchCalls += 1;
    return cachedResponse();
  };
  await loaded.source.fetchBuybackOffers('Apple iPhone 15 Pro 256 GB', 'like_new', {
    now: cachedNow,
    fetchImpl: cappedCacheFetch,
  });
  await loaded.source.fetchBuybackOffers('Apple iPhone 15 Pro 256 GB', 'like_new', {
    now: cachedNow + 9999,
    fetchImpl: cappedCacheFetch,
  });
  assert.strictEqual(cappedCacheFetchCalls, 1, 'cache may be reused within the provider limit');
  await loaded.source.fetchBuybackOffers('Apple iPhone 15 Pro 256 GB', 'like_new', {
    now: cachedNow + 10001,
    fetchImpl: cappedCacheFetch,
  });
  assert.strictEqual(cappedCacheFetchCalls, 2, 'the shortest provider limit must govern a shared feed');
  assert.strictEqual(loaded.source.sourceStatus(cachedNow).cache_ttl_seconds, 10);
  loaded.restore();

  loaded = loadSource(approvedEnv({ cacheTtl: 60000 }));
  let expiringCacheFetchCalls = 0;
  const expiringCacheFetch = async () => {
    expiringCacheFetchCalls += 1;
    const response = cachedResponse();
    const originalJson = response.json;
    response.json = async () => {
      const payload = await originalJson();
      payload.items[0].expires_at = '2026-09-20T08:00:15Z';
      return payload;
    };
    return response;
  };
  const expiringFirst = await loaded.source.fetchBuybackOffers(
    'Apple iPhone 15 Pro 256 GB', 'like_new',
    { now: cachedNow, fetchImpl: expiringCacheFetch },
  );
  const expiringSecond = await loaded.source.fetchBuybackOffers(
    'Apple iPhone 15 Pro 256 GB', 'like_new',
    { now: cachedNow + 10000, fetchImpl: expiringCacheFetch },
  );
  assert.strictEqual(expiringCacheFetchCalls, 1, 'an unexpired offer may use the short cache');
  assert.deepStrictEqual(expiringSecond, expiringFirst);
  const afterOfferExpiry = await loaded.source.fetchBuybackOffers(
    'Apple iPhone 15 Pro 256 GB', 'like_new',
    { now: cachedNow + 16000, fetchImpl: expiringCacheFetch },
  );
  assert.strictEqual(expiringCacheFetchCalls, 2, 'an offer expiry must invalidate the cache');
  assert.deepStrictEqual(afterOfferExpiry.items, [], 'an expired price must not be served after refresh');
  loaded.restore();

  const noCacheApproval = JSON.parse(approvedEnv().approvals);
  noCacheApproval[0].max_cache_seconds = 0;
  loaded = loadSource(approvedEnv({
    cacheTtl: 60000,
    approvals: JSON.stringify(noCacheApproval),
  }));
  let noCacheFetchCalls = 0;
  const noCacheFetch = async () => {
    noCacheFetchCalls += 1;
    return cachedResponse();
  };
  await loaded.source.fetchBuybackOffers('Apple iPhone 15 Pro 256 GB', 'like_new', {
    now: cachedNow,
    fetchImpl: noCacheFetch,
  });
  await loaded.source.fetchBuybackOffers('Apple iPhone 15 Pro 256 GB', 'like_new', {
    now: cachedNow + 1,
    fetchImpl: noCacheFetch,
  });
  assert.strictEqual(noCacheFetchCalls, 2, 'a zero provider limit must disable caching');
  assert.strictEqual(loaded.source.sourceStatus(cachedNow).cache_ttl_seconds, 0);
  loaded.restore();

  loaded = loadSource(approvedEnv({
    cacheTtl: 60000,
    approvals: JSON.stringify([
      {
        provider_id: 'clevertronic', provider_name: 'Clevertronic',
        approval_reference: 'short-clevertronic-contract',
        reviewed_at: '2026-09-01T10:00:00Z', valid_until: '2026-09-20T08:00:30Z',
        feed_access: true, price_display: true, offer_links: true,
        provider_identity_display: true, affiliate_links: false,
        feed_hosts: ['partner.example'],
        offer_hosts: ['partner.example'],
        max_cache_seconds: 60,
      },
      {
        provider_id: 'zoxs', provider_name: 'ZOXS',
        approval_reference: 'current-zoxs-contract',
        reviewed_at: '2026-09-01T10:00:00Z', valid_until: '2099-12-31T23:59:59Z',
        feed_access: true, price_display: true, offer_links: true,
        provider_identity_display: true, affiliate_links: false,
        feed_hosts: ['partner.example'],
        offer_hosts: ['partner.example'],
        max_cache_seconds: 60,
      },
    ]),
  }));
  let approvalExpiryFetchCalls = 0;
  const approvalExpiryFetch = async () => {
    approvalExpiryFetchCalls += 1;
    return cachedResponse();
  };
  const beforeApprovalExpiry = await loaded.source.fetchBuybackOffers(
    'Apple iPhone 15 Pro 256 GB', 'like_new',
    { now: cachedNow, fetchImpl: approvalExpiryFetch },
  );
  assert.strictEqual(beforeApprovalExpiry.items.length, 1);
  const afterApprovalExpiry = await loaded.source.fetchBuybackOffers(
    'Apple iPhone 15 Pro 256 GB', 'like_new',
    { now: cachedNow + 31000, fetchImpl: approvalExpiryFetch },
  );
  assert.strictEqual(
    approvalExpiryFetchCalls,
    1,
    'a changed approval set must invalidate activation before another partner request',
  );
  assert.deepStrictEqual(afterApprovalExpiry, {
    configured: false,
    items: [],
    best: null,
  });
  assert.strictEqual(
    loaded.source.sourceStatus(cachedNow + 31000).readiness,
    'missing_or_stale_validation',
  );
  loaded.restore();

  loaded = loadSource(approvedEnv({ cacheTtl: 60000 }));
  let concurrentFetchCalls = 0;
  let releaseConcurrentFetch;
  const concurrentFetch = async () => {
    concurrentFetchCalls += 1;
    await new Promise((resolve) => { releaseConcurrentFetch = resolve; });
    return cachedResponse();
  };
  const concurrentFirst = loaded.source.fetchBuybackOffers(
    'Apple iPhone 15 Pro 256 GB', 'like_new',
    { now: cachedNow, fetchImpl: concurrentFetch },
  );
  const concurrentSecond = loaded.source.fetchBuybackOffers(
    'Apple iPhone 15 Pro 256 GB', 'like_new',
    { now: cachedNow, fetchImpl: concurrentFetch },
  );
  assert.strictEqual(concurrentFetchCalls, 1, 'simultaneous identical requests must share one partner call');
  releaseConcurrentFetch();
  const concurrentResults = await Promise.all([concurrentFirst, concurrentSecond]);
  assert.deepStrictEqual(concurrentResults[1], concurrentResults[0]);
  loaded.restore();

  loaded = loadSource(approvedEnv({ cacheTtl: 60000 }));
  let outageFetchCalls = 0;
  const unavailableFetch = async () => {
    outageFetchCalls += 1;
    throw new Error('partner offline');
  };
  await loaded.source.fetchBuybackOffers('Apple iPhone 15 Pro 256 GB', 'like_new', {
    now: cachedNow,
    fetchImpl: unavailableFetch,
  });
  await loaded.source.fetchBuybackOffers('Apple iPhone 15 Pro 256 GB', 'like_new', {
    now: cachedNow + 1,
    fetchImpl: unavailableFetch,
  });
  assert.strictEqual(outageFetchCalls, 2, 'provider outages must never be cached as a valid empty result');
  loaded.restore();

  console.log('buyback source tests passed');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
