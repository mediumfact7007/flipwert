'use strict';

function normalizeMarketText(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/ß/g, 'ss')
    .replace(/\+/g, ' plus ')
    .replace(/\bps\s*5\b/g, ' playstation 5 ')
    .replace(/\bps\s*4\b/g, ' playstation 4 ')
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function hasPhrase(text, phrase) {
  if (!text || !phrase) return false;
  return (` ${text} `).includes(` ${phrase} `);
}

const ACCESSORY_PHRASES = [
  'hulle', 'case', 'cover', 'schutzglas', 'panzerglas', 'schutzfolie',
  'screen protector', 'display schutz', 'ladekabel', 'charging cable',
  'usb kabel', 'halterung', 'wall mount', 'controller halter', 'ersatzteil',
  'spare parts', 'replacement screen', 'ersatz display', 'lcd ersatz',
  'leer karton', 'leerkarton', 'empty box', 'box only', 'original box only',
  'empty original box', 'nur karton', 'nur verpackung', 'packaging only',
  'karton ohne gerat', 'verpackung ohne gerat', 'box without device',
  'box no device', 'leere originalverpackung', 'originalverpackung leer',
  'leere ovp', 'ovp leer', 'nur ovp', 'ovp only', 'empty packaging',
  'dummy', 'attrappe',
];

const RISK_PHRASES = [
  'defekt', 'kaputt', 'bastler', 'ersatzteiltrager', 'parts only', 'for parts',
  'spares or repair', 'repair only', 'zum ausschlachten', 'reparaturbedurftig',
  'not working', 'does not work', 'funktioniert nicht', 'ohne funktion',
  'nicht funktionsfahig', 'ungetestet',
  // Common damage/lock wording that otherwise creates unrealistically cheap
  // comparables and can make a normal used device look like a strong deal.
  'displaybruch', 'display bruch', 'glasbruch', 'glas bruch', 'wasserschaden',
  'water damage', 'icloud lock', 'icloud locked', 'activation lock',
  // Frequent phone defects that can be easy to miss in otherwise normal-looking
  // listings but materially reduce resale value.
  'ruckglas defekt', 'ruckseite gebrochen', 'back glass broken', 'back glass cracked',
  'face id defekt', 'face id funktioniert nicht', 'face id not working',
  'kamera defekt', 'camera not working', 'kamerafehler', 'camera fault',
];

const VARIANT_PHRASES = [
  'pro max', 'series x', 'series s', 'pro', 'ultra', 'plus', 'mini', 'slim',
  'oled', 'lite', 'digital edition', 'digital', 'disc edition',
];

const STOP_WORDS = new Set([
  'der', 'die', 'das', 'ein', 'eine', 'einer', 'mit', 'ohne', 'fur', 'und',
  'the', 'a', 'an', 'with', 'without', 'for', 'and', 'von', 'aus', 'neu',
  'new', 'gebraucht', 'used', 'original', 'edition', 'modell', 'model',
]);

function maxCapacityGb(text) {
  let max = null;
  const regex = /\b(\d{1,4})\s*(gb|tb)\b/g;
  let match;
  while ((match = regex.exec(text)) !== null) {
    const raw = Number(match[1]);
    if (!Number.isFinite(raw) || raw <= 0) continue;
    const value = match[2] === 'tb' ? raw * 1024 : raw;
    if (max == null || value > max) max = value;
  }
  return max;
}

function identifiers(text) {
  const withoutCapacity = text.replace(/\b\d{1,4}\s*(?:gb|tb)\b/g, ' ');
  return withoutCapacity.split(/\s+/).filter(Boolean)
    .filter((token) => /\d/.test(token))
    .filter((token) => /[a-z]/.test(token) || token.length >= 2);
}

function significantWords(text) {
  return text.split(/\s+/).filter((token) => token.length >= 3)
    .filter((token) => !STOP_WORDS.has(token))
    .filter((token) => !VARIANT_PHRASES.includes(token))
    .filter((token) => !/^\d/.test(token));
}

function containsUnrequestedPhrase(title, query, phrases) {
  return phrases.some((phrase) => hasPhrase(title, phrase) && !hasPhrase(query, phrase));
}

function listingMatchesQuery(queryValue, titleValue) {
  const query = normalizeMarketText(queryValue);
  const title = normalizeMarketText(titleValue);
  if (!query || !title) return false;
  if (/^\d{8,14}$/.test(query)) {
    return !containsUnrequestedPhrase(title, query, [...ACCESSORY_PHRASES, ...RISK_PHRASES]);
  }
  if (containsUnrequestedPhrase(title, query, ACCESSORY_PHRASES)) return false;
  if (containsUnrequestedPhrase(title, query, RISK_PHRASES)) return false;
  const queryCapacity = maxCapacityGb(query);
  const titleCapacity = maxCapacityGb(title);
  if (queryCapacity != null && titleCapacity != null && queryCapacity !== titleCapacity) return false;
  const queryVariants = VARIANT_PHRASES.filter((phrase) => hasPhrase(query, phrase));
  const titleVariants = VARIANT_PHRASES.filter((phrase) => hasPhrase(title, phrase));
  if (queryVariants.some((variant) => !hasPhrase(title, variant))) return false;
  if (titleVariants.some((variant) => !hasPhrase(query, variant))) return false;
  const queryIds = [...new Set(identifiers(query))];
  for (const id of queryIds) if (!hasPhrase(title, id)) return false;
  const words = [...new Set(significantWords(query))];
  if (words.length > 0) {
    const matches = words.filter((word) => hasPhrase(title, word)).length;
    const required = words.length >= 3 ? Math.ceil(words.length * 0.5) : 1;
    if (matches < required) return false;
  }
  return true;
}

function filterMarketListings(query, items) {
  if (!Array.isArray(items)) return [];
  return items.filter((item) => listingMatchesQuery(query, item?.title || ''));
}

function assessMarketListings(query, items) {
  const rawItems = Array.isArray(items) ? items : [];
  const filteredItems = filterMarketListings(query, rawItems);
  return {
    items: filteredItems,
    rejectedCount: rawItems.length - filteredItems.length,
  };
}

module.exports = {
  assessMarketListings,
  filterMarketListings,
  listingMatchesQuery,
  normalizeMarketText,
};
