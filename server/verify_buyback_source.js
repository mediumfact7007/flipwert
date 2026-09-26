'use strict';

const { CONDITIONS } = require('./buyback');
const defaultSource = require('./buyback_source');

function cleanQuery(value) {
  return String(value || '').trim().replace(/\s+/g, ' ').slice(0, 160);
}

async function verifyBuybackSource({
  query,
  condition,
  source = defaultSource,
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
  if (!status.configured) {
    return {
      ok: false,
      reason: 'source_not_ready',
      readiness: status.readiness || 'unknown',
    };
  }

  const result = await source.fetchBuybackOffers(
    normalizedQuery,
    normalizedCondition,
  );
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

  return {
    ok: true,
    readiness: 'ready',
    condition: normalizedCondition,
    offer_count: items.length,
    provider_count: providers.length,
    provider_ids: providers,
    newest_checked_at: checkedTimes.length
      ? new Date(Math.max(...checkedTimes)).toISOString()
      : null,
  };
}

async function verifyBuybackSourceMatrix({
  cases,
  source = defaultSource,
} = {}) {
  if (!Array.isArray(cases) || cases.length < 1 || cases.length > 20 ||
      cases.some((item) => !item || typeof item !== 'object' || Array.isArray(item))) {
    return { ok: false, reason: 'invalid_cases' };
  }

  const results = [];
  for (let index = 0; index < cases.length; index += 1) {
    const item = cases[index];
    const result = await verifyBuybackSource({
      query: item.query,
      condition: item.condition,
      source,
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
  const checkedTimes = results
    .map((result) => Date.parse(String(result.newest_checked_at || '')))
    .filter(Number.isFinite);

  return {
    ok: true,
    readiness: 'ready',
    case_count: results.length,
    offer_count: results.reduce((sum, result) => sum + result.offer_count, 0),
    provider_count: providerIds.length,
    provider_ids: providerIds,
    newest_checked_at: checkedTimes.length
      ? new Date(Math.max(...checkedTimes)).toISOString()
      : null,
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
