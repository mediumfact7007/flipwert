'use strict';

const VARIANTS = new Set(['pro', 'max', 'plus', 'ultra', 'mini', 'air', 'oled', 'lite', 'fe', 'slim']);
const NOISE = new Set(['apple', 'samsung', 'google', 'mit', 'und', 'ohne', 'ovp', 'neu', 'gebraucht', 'top', 'zustand', 'versand', 'abholung', 'verkauf', 'original', 'inkl', 'in', 'der', 'das', 'die', 'the', 'with', 'for', 'new', 'used', 'black', 'white', 'schwarz', 'weiss']);
const FAMILIES = new Set(['iphone', 'ipad', 'galaxy', 'pixel', 'switch', 'macbook', 'playstation', 'ps5', 'ps4']);

function tokens(value) {
  const normalized = String(value || '').normalize('NFKD').toLowerCase()
    .replace(/\bplay\s*station\s*5\b/g, 'ps5')
    .replace(/\bps\s*5\b/g, 'ps5')
    .replace(/\bpromax\b/g, 'pro max')
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

// A partner's confidence is a claim about its own lookup, not evidence that
// the returned product matches the user's search. Check visible identity too.
function matchesBuybackQuery(query, offer) {
  const searched = tokens(query);
  const title = tokens(offer.matched_title);
  if (!searched.length || !title.length) return false;

  // Numeric EAN/GTIN searches need an explicit matching identifier. A title
  // or an unrelated internal product ID cannot establish barcode identity.
  if (/^\d{8,14}$/.test(String(query).trim())) {
    return [offer.ean, offer.gtin, offer.product_id]
      .some((value) => String(value || '').trim() === String(query).trim());
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
  // Listing titles contain seller prose; tolerate it while requiring the
  // actual product terms (including generation and storage) to be present.
  return meaningful.filter((part) => title.includes(part)).length / meaningful.length >= 0.75;
}

module.exports = { matchesBuybackQuery };
