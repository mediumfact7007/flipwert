'use strict';

const { CONDITIONS } = require('./buyback');
const defaultSource = require('./buyback_source');

const MIN_MATRIX_CASES = 3;
const MIN_MATRIX_PRODUCTS = 2;
const MIN_MATRIX_CONDITIONS = 2;

function cleanQuery(value) {
  return String(value || '').trim().replace(/\s+/g, ' ').slice(0, 160);
}

async function verifyBuybackSource({
  query,
  condition,
  source = defaultSource,
  includeActivationFingerprint = false,
} = {}) {
  const normalizedQuery = cleanQuery(query);
  const normalizedCondition = String(condition || '').trim();

  if (normalizedQuery.length < 3) {
    return { ok: false, reason: 'invalid_query' };
  }
  if (!CONDITIONS.has(normalizedCondition)) {
    return { ok: false, reason: 'invalid_condition' };
  }

  const status = source.sourceStatus();
  const pendingActivation = !status.configured &&
    status.readiness === 'missing_or_stale_validation' &&
    typeof source.fetchBuybackOffersForVerification === 'function';
  if (!status.configured && !pendingActivation) {
    return {
      ok: false,
      reason: 'source_not_ready',
      readiness: status.readiness || 'unknown',
    };
  }

  const fetchOffers = pendingActivation
    ? source.fetchBuybackOffersForVerification.bind(source)
    : source.fetchBuybackOffers.bind(source);
  const result = await fetchOffers(normalizedQuery, normalizedCondition);
  if (result.unavailable === true) {
    return { ok: false, reason: 'source_unavailable', readiness: 'ready' };
  }

  const items = Array.isArray(result.items) ? result.items : [];
  if (!items.length) {
    return {
      ok: false,
      reason: 'no_exact_matching_offer',
      readiness: 'ready',
    };
  }
  if (items.some((item) => item.condition !== normalizedCondition)) {
    return {
      ok: false,
      reason: 'unexpected_condition_in_result',
      readiness: 'ready',
    };
  }

  const providers = [...new Set(items.map((item) =>
    String(item.provider_id || '').trim().toLowerCase()).filter(Boolean))].sort();
  const checkedTimes = items
    .map((item) => Date.parse(String(item.checked_at || '')))
    .filter(Number.isFinite);

  const activationFingerprint = includeActivationFingerprint &&
    typeof source.activationFingerprint === 'function'
    ? source.activationFingerprint()
    : null;
  return {
    ok: true,
    readiness: status.configured ? 'ready' : 'validation_passed_activation_required',
    condition: normalizedCondition,
    offer_count: items.length,
    provider_count: providers.length,
    provider_ids: providers,
    newest_checked_at: checkedTimes.length
      ? new Date(Math.max(...checkedTimes)).toISOString()
      : null,
    ...(typeof activationFingerprint === 'string' &&
      /^[a-f0-9]{64}$/.test(activationFingerprint)
      ? { activation_fingerprint: activationFingerprint }
      : {}),
  };
}

async function verifyBuybackSourceMatrix({
  cases,
  source = defaultSource,
} = {}) {
  if (!Array.isArray(cases) || cases.length < MIN_MATRIX_CASES || cases.length > 20 ||
      cases.some((item) => !item || typeof item !== 'object' || Array.isArray(item))) {
    return { ok: false, reason: 'invalid_cases' };
  }

  const normalizedCases = cases.map((item) => ({
    query: cleanQuery(item.query),
    condition: String(item.condition || '').trim(),
  }));
  if (normalizedCases.some((item) =>
    item.query.length < 3 || !CONDITIONS.has(item.condition))) {
    return { ok: false, reason: 'invalid_cases' };
  }

  // A repeated successful lookup is not representative validation. Require
  // distinct products and conditions before exposing the activation token so
  // a single SKU/state cannot accidentally unlock every approved LIVE feed.
  const pairs = normalizedCases.map((item) =>
    `${item.query.toLowerCase()}\u0000${item.condition}`);
  const productCount = new Set(normalizedCases.map((item) =>
    item.query.toLowerCase())).size;
  const conditionCount = new Set(normalizedCases.map((item) =>
    item.condition)).size;
  if (new Set(pairs).size !== pairs.length ||
      productCount < MIN_MATRIX_PRODUCTS ||
      conditionCount < MIN_MATRIX_CONDITIONS) {
    return {
      ok: false,
      reason: 'insufficient_matrix_coverage',
      readiness: 'validation_incomplete',
      required_case_count: MIN_MATRIX_CASES,
      required_product_count: MIN_MATRIX_PRODUCTS,
      required_condition_count: MIN_MATRIX_CONDITIONS,
      actual_case_count: cases.length,
      actual_product_count: productCount,
      actual_condition_count: conditionCount,
    };
  }

  const results = [];
  for (let index = 0; index < normalizedCases.length; index += 1) {
    const item = normalizedCases[index];
    const result = await verifyBuybackSource({
      query: item.query,
      condition: item.condition,
      source,
      includeActivationFingerprint: true,
    });
    if (!result.ok) {
      return {
        ok: false,
        reason: 'case_failed',
        failed_case_index: index,
        case_reason: result.reason,
        readiness: result.readiness || 'unknown',
      };
    }
    results.push(result);
  }

  const providerIds = [...new Set(results.flatMap((result) =>
    result.provider_ids || []))].sort();

  // Activation is configuration-wide. Every approved provider must have been
  // observed in this validation matrix before the configuration can go live.
  if (typeof source.approvedProviderIds === 'function') {
    const approved = source.approvedProviderIds()
      .map((value) => String(value || '').trim().toLowerCase())
      .filter(Boolean)
      .sort();
    const missing = approved.filter((providerId) => !providerIds.includes(providerId));
    if (missing.length) {
      return {
        ok: false,
        reason: 'approved_provider_not_verified',
        missing_provider_ids: missing,
        verified_provider_ids: providerIds,
        readiness: 'validation_incomplete',
      };
    }
  }

  const checkedTimes = results
    .map((result) => Date.parse(String(result.newest_checked_at || '')))
    .filter(Number.isFinite);

  const activationFingerprints = [...new Set(results
    .map((result) => result.activation_fingerprint)
    .filter(Boolean))];
  return {
    ok: true,
    readiness: results.every((result) => result.readiness === 'ready')
      ? 'ready'
      : 'validation_passed_activation_required',
    case_count: results.length,
    offer_count: results.reduce((sum, result) => sum + result.offer_count, 0),
    provider_count: providerIds.length,
    provider_ids: providerIds,
    newest_checked_at: checkedTimes.length
      ? new Date(Math.max(...checkedTimes)).toISOString()
      : null,
    ...(activationFingerprints.length === 1
      ? { activation_fingerprint: activationFingerprints[0] }
      : {}),
  };
}

async function main() {
  const rawCases = String(process.env.BUYBACK_VERIFY_CASES_JSON || '').trim();
  let result;
  if (rawCases) {
    let cases;
    try {
      cases = JSON.parse(rawCases);
    } catch (_) {
      result = { ok: false, reason: 'invalid_cases_json' };
    }
    if (!result) result = await verifyBuybackSourceMatrix({ cases });
  } else {
    result = await verifyBuybackSource({
      query: process.env.BUYBACK_VERIFY_QUERY,
      condition: process.env.BUYBACK_VERIFY_CONDITION,
    });
  }
  process.stdout.write(`${JSON.stringify(result)}\n`);
  if (!result.ok) process.exitCode = 1;
}

if (require.main === module) {
  main().catch(() => {
    process.stdout.write('{"ok":false,"reason":"verification_failed"}\n');
    process.exitCode = 1;
  });
}

module.exports = { verifyBuybackSource, verifyBuybackSourceMatrix };
