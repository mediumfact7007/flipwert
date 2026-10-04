'use strict';

const VARIANTS = new Set(['pro', 'max', 'plus', 'ultra', 'mini', 'air', 'oled', 'lite', 'fe', 'slim']);
const NOISE = new Set(['apple', 'samsung', 'google', 'mit', 'und', 'ohne', 'ovp', 'neu', 'gebraucht', 'top', 'zustand', 'versand', 'abholung', 'verkauf', 'original', 'inkl', 'in', 'der', 'das', 'die', 'the', 'with', 'for', 'new', 'used', 'black', 'white', 'schwarz', 'weiss']);
const FAMILIES = new Set(['iphone', 'ipad', 'galaxy', 'pixel', 'switch', 'macbook', 'playstation', 'ps5', 'ps4']);
const BRAND_FAMILIES = new Map([
  ['apple', new Set(['iphone', 'ipad', 'macbook'])],
  ['samsung', new Set(['galaxy'])],
  ['google', new Set(['pixel'])],
]);
const CONNECTIVITY_VARIANTS = new Set(['wifi', 'cellular', 'lte', '5g']);
const CONSOLE_EDITIONS = new Set(['digital', 'disc']);
const DAMAGE_TERMS = new Set([
  'defekt', 'kaputt', 'bastler', 'bastlergerat', 'displaybruch', 'glasbruch',
  'bruch', 'wasserschaden', 'reparatur', 'ersatzteile', 'funktionsunfahig',
  'broken', 'damaged', 'cracked', 'repair', 'parts',
]);

// A provider title may mention bundled accessories after the device name, but
// an accessory sold "for" a device is not the requested device itself. This
// guards approved partner feeds against accidental category/SKU leakage.
function isAccessoryOnlyTitle(value) {
  const normalized = tokens(value);
  if (!normalized.length) return false;
  const accessory = new Set([
    'hulle', 'case', 'cover', 'schutzglas', 'panzerglas', 'display', 'akku',
    'batterie', 'ladegerat', 'charger', 'kabel', 'cable', 'ersatzteil',
    'replacement',
  ]);
  const firstAccessory = normalized.findIndex((part) => accessory.has(part));
  if (firstAccessory < 0 || firstAccessory > 2) return false;
  return normalized.slice(firstAccessory + 1, firstAccessory + 4)
    .some((part) => part === 'fur' || part === 'for');
}

function tokens(value) {
  const normalized = String(value || '').normalize('NFKD').toLowerCase()
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\bplay\s*station\s*5\b/g, 'ps5')
    .replace(/\bps\s*5\b/g, 'ps5')
    .replace(/ß/g, 'ss')
    .replace(/\bpromax\b/g, 'pro max')
    .replace(/\bwi[\s-]?fi\b|\bwlan\b/g, 'wifi')
    .replace(/\b4g\b/g, 'lte')
    .replace(/\bohne\s+(?:disc|disk|laufwerk)\b/g, 'digital')
    .replace(/\bmit\s+(?:disc|disk|laufwerk)\b/g, 'disc')
    .replace(/\bdisk\s+edition\b/g, 'disc')
    .replace(/\bdisc\s+edition\b/g, 'disc')
    .replace(/\bdigital\s+edition\b/g, 'digital')
    .replace(/([a-z0-9])\+/g, '$1 plus')
    .replace(/(\d+)\s*(tb|gb)\b/g, (_, size, unit) => `${Number(size) * (unit === 'tb' ? 1024 : 1)}gb`)
    .replace(/[^a-z0-9]+/g, ' ').trim();
  return normalized ? normalized.split(/\s+/) : [];
}

function storage(parts) {
  return parts.filter((part) => /^\d+gb$/.test(part));
}

function criticalIdentity(parts) {
  return [...new Set(parts.filter((part) => /\d/.test(part) || VARIANTS.has(part)))];
}

function hasExactDimension(searched, title, values) {
  const requested = [...new Set(searched.filter((part) => values.has(part)))];
  const offered = [...new Set(title.filter((part) => values.has(part)))];
  return requested.length === offered.length &&
    requested.every((part) => offered.includes(part));
}

function hasCompatibleBrand(searched, title) {
  const requested = [...BRAND_FAMILIES.keys()].filter((brand) => searched.includes(brand));
  const offered = [...BRAND_FAMILIES.keys()].filter((brand) => title.includes(brand));
  if (requested.length > 1 || offered.length > 1) return false;
  if (requested.length && offered.length) return requested[0] === offered[0];

  const implicitBrand = (brand, parts) =>
    [...BRAND_FAMILIES.get(brand)].some((family) => parts.includes(family));
  if (requested.length) {
    return implicitBrand(requested[0], searched) && implicitBrand(requested[0], title);
  }
  if (offered.length) {
    return implicitBrand(offered[0], searched) && implicitBrand(offered[0], title);
  }
  return true;
}

// EAN-8, UPC-A, EAN-13 and GTIN-14 share the same GS1 modulo-10 check
// digit. Canonicalizing valid values to GTIN-14 lets a scanner's EAN-13 match
// a partner's zero-padded GTIN-14 without accepting arbitrary numeric product
// IDs as barcodes.
function canonicalGtin(value) {
  const digits = String(value || '').trim();
  if (![8, 12, 13, 14].includes(digits.length) || !/^\d+$/.test(digits)) {
    return null;
  }
  const body = digits.slice(0, -1);
  let sum = 0;
  for (let index = body.length - 1, weight = 3; index >= 0; index -= 1) {
    sum += Number(body[index]) * weight;
    weight = weight === 3 ? 1 : 3;
  }
  const expectedCheckDigit = (10 - (sum % 10)) % 10;
  if (expectedCheckDigit !== Number(digits.at(-1))) return null;
  return digits.padStart(14, '0');
}

// A partner's confidence is a claim about its own lookup, not evidence that
// the returned product matches the user's search. Check visible identity too.
function matchesBuybackQuery(query, offer) {
  const rawQuery = String(query || '').trim();
  const searched = tokens(query);
  const title = tokens(offer.matched_title);
  if (!searched.length || !title.length) return false;
  if (isAccessoryOnlyTitle(offer.matched_title)) return false;
  if (!hasCompatibleBrand(searched, title)) return false;

  // The structured condition remains authoritative, but a conflicting damage
  // marker in the visible provider title is evidence that the mapping is not
  // trustworthy. Prefer no LIVE quote over a price for a damaged/parts unit.
  if (offer.condition !== 'defective' &&
      title.some((part) => DAMAGE_TERMS.has(part))) return false;

  // Numeric barcode searches need an explicit, checksum-valid EAN/GTIN. A
  // title or an unrelated internal product ID cannot establish barcode
  // identity. Treat invalid numeric barcode-shaped input as unmatched instead
  // of falling through to fuzzy title matching.
  if (/^\d+$/.test(rawQuery)) {
    const requestedGtin = canonicalGtin(rawQuery);
    if (!requestedGtin) return false;
    return [offer.ean, offer.gtin]
      .some((value) => canonicalGtin(value) === requestedGtin);
  }

  // Model numbers and named variants are hard identity constraints for every
  // category, not just the explicitly modelled phone/console families. This
  // prevents a mostly similar title (for example Dyson V12 vs V15) from
  // passing the generic token threshold.
  if (criticalIdentity(searched).some((part) => !title.includes(part))) return false;

  const family = searched.find((part) => FAMILIES.has(part));

  // Storage is an exact variant dimension even for products outside the
  // explicitly modelled families (for example Steam Deck or laptops). Do not
  // accept a provider's storage-specific SKU when the user's query omitted
  // storage: that would turn an ambiguous search into a falsely exact LIVE
  // price. Consoles whose base storage is inherent in the named model remain
  // compatible with the existing family exception below.
  const requestedStorage = storage(searched);
  const offeredStorage = storage(title);
  const storageOptionalFamily = ['switch', 'ps5', 'ps4'].includes(family);
  if (requestedStorage.length &&
      !requestedStorage.some((part) => offeredStorage.includes(part))) return false;
  if (!requestedStorage.length && offeredStorage.length && !storageOptionalFamily) return false;

  // Connectivity is a price-defining SKU dimension for tablets and watches.
  // Keep it scoped to those categories so incidental laptop terms such as
  // "Wi-Fi 6" do not turn into a false mismatch.
  const connectivityProduct = ['ipad', 'tablet', 'tab', 'watch']
    .some((part) => searched.includes(part) || title.includes(part));
  if (connectivityProduct &&
      !hasExactDimension(searched, title, CONNECTIVITY_VARIANTS)) return false;

  // Console disc/digital editions are different products and commonly carry
  // different buyback prices. An omitted edition is ambiguous and must not be
  // promoted to an exact LIVE match.
  const consoleProduct = ['ps5', 'ps4', 'playstation', 'xbox']
    .some((part) => searched.includes(part) || title.includes(part));
  if (consoleProduct &&
      !hasExactDimension(searched, title, CONSOLE_EDITIONS)) return false;

  if (family) {
    if (!title.includes(family)) return false;
    const model = searched.slice(searched.indexOf(family) + 1, searched.indexOf(family) + 5)
      .find((part) => /^(?:[a-z]?\d+[a-z]?|m[1-9])$/.test(part));
    if (model && !title.includes(model)) return false;
    if (!model && !['switch', 'ps5', 'ps4'].includes(family)) return false;
    const requestedVariants = searched.filter((part) => VARIANTS.has(part));
    const offeredVariants = title.filter((part) => VARIANTS.has(part));
    if (requestedVariants.some((part) => !offeredVariants.includes(part)) ||
        offeredVariants.some((part) => !requestedVariants.includes(part))) return false;
  }

  const meaningful = [...new Set(searched.filter((part) => part.length > 1 && !NOISE.has(part)))];
  if (meaningful.length < 2) return false;
  // LIVE buyback prices must identify the exact requested product, not just a
  // mostly similar title. Noise/prose has already been removed above, so every
  // remaining query token must be represented by the provider title. Failing
  // closed here deliberately prefers no LIVE price over a wrong SKU price
  // (for example a colour/material or accessory token that changes the SKU).
  return meaningful.every((part) => title.includes(part));
}

module.exports = { matchesBuybackQuery };
