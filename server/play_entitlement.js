'use strict';

const crypto = require('crypto');

const ALLOWED_PRODUCTS = new Set([
  'flipwert_pro_monthly',
  'flipwert_pro_yearly',
]);
const ACTIVE_STATES = new Set([
  'SUBSCRIPTION_STATE_ACTIVE',
  'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
  // Google reports a user-cancelled subscription as cancelled until its paid
  // expiry. Access remains valid during that already-paid period.
  'SUBSCRIPTION_STATE_CANCELED',
]);

let cachedAccessToken = '';
let cachedAccessTokenExpiresAt = 0;

function base64Url(value) {
  return Buffer.from(value).toString('base64url');
}

function configured(env = process.env) {
  return Boolean(
    String(env.GOOGLE_PLAY_PACKAGE_NAME || '').trim() &&
    String(env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON || '').trim(),
  );
}

function serviceAccount(env = process.env) {
  if (!configured(env)) return null;
  try {
    const value = JSON.parse(env.GOOGLE_PLAY_SERVICE_ACCOUNT_JSON);
    if (!value || typeof value !== 'object') return null;
    if (!String(value.client_email || '').includes('@')) return null;
    if (!String(value.private_key || '').includes('BEGIN PRIVATE KEY')) return null;
    return value;
  } catch (_) {
    return null;
  }
}

async function accessToken(fetchImpl, account, now = Date.now()) {
  if (cachedAccessToken && now < cachedAccessTokenExpiresAt - 60_000) {
    return cachedAccessToken;
  }
  const issuedAt = Math.floor(now / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: 'https://oauth2.googleapis.com/token',
    iat: issuedAt,
    exp: issuedAt + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const signature = crypto.sign('RSA-SHA256', Buffer.from(unsigned), account.private_key)
    .toString('base64url');
  const response = await fetchImpl('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${signature}`,
    }),
  });
  if (!response.ok) throw new Error(`google_oauth_${response.status}`);
  const body = await response.json();
  const token = String(body.access_token || '');
  const expiresIn = Number(body.expires_in || 0);
  if (!token || !Number.isFinite(expiresIn) || expiresIn <= 0) {
    throw new Error('google_oauth_invalid_response');
  }
  cachedAccessToken = token;
  cachedAccessTokenExpiresAt = now + expiresIn * 1000;
  return token;
}

function activeEntitlement(payload, productId, now = Date.now()) {
  if (!payload || !ACTIVE_STATES.has(String(payload.subscriptionState || ''))) {
    return null;
  }
  const items = Array.isArray(payload.lineItems) ? payload.lineItems : [];
  const matching = items
    .filter((item) => String(item?.productId || '') === productId)
    .map((item) => ({ item, expiry: Date.parse(String(item?.expiryTime || '')) }))
    .filter((entry) => Number.isFinite(entry.expiry) && entry.expiry > now)
    .sort((a, b) => b.expiry - a.expiry);
  if (!matching.length) return null;
  return {
    productId,
    expiresAt: new Date(matching[0].expiry).toISOString(),
  };
}

async function verifyPlayEntitlement({
  productId,
  purchaseToken,
  fetchImpl = fetch,
  env = process.env,
  now = Date.now(),
}) {
  if (!ALLOWED_PRODUCTS.has(productId)) {
    return { verified: false, error: 'unsupported_product' };
  }
  if (!purchaseToken || purchaseToken.length < 20 || purchaseToken.length > 4096) {
    return { verified: false, error: 'invalid_purchase_token' };
  }
  const account = serviceAccount(env);
  const packageName = String(env.GOOGLE_PLAY_PACKAGE_NAME || '').trim();
  if (!account || !packageName) {
    return { verified: false, error: 'play_verification_not_configured' };
  }
  const token = await accessToken(fetchImpl, account, now);
  const url = 'https://androidpublisher.googleapis.com/androidpublisher/v3/' +
    `applications/${encodeURIComponent(packageName)}/purchases/subscriptionsv2/` +
    `tokens/${encodeURIComponent(purchaseToken)}`;
  const response = await fetchImpl(url, {
    headers: { authorization: `Bearer ${token}` },
  });
  if (!response.ok) {
    return { verified: false, error: `play_api_${response.status}` };
  }
  const entitlement = activeEntitlement(await response.json(), productId, now);
  return entitlement
    ? { verified: true, ...entitlement }
    : { verified: false, error: 'subscription_not_active' };
}

module.exports = {
  activeEntitlement,
  configured,
  verifyPlayEntitlement,
};
