'use strict';

const assert = require('node:assert/strict');
const { matchesBuybackQuery: matches } = require('./buyback_match');
const offer = (matched_title, extra = {}) => ({
  matched_title,
  product_id: 'internal-123',
  condition: 'used_good',
  ...extra,
});

assert.equal(matches('Apple iPhone 15 Pro 256 GB mit OVP', offer('Apple iPhone 15 Pro 256GB')), true);
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('iPhone 15 Pro Max 256GB')), false);
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('iPhone 15 Pro 128GB')), false);
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('iPhone 14 Pro 256GB')), false);
assert.equal(matches('Apple iPhone 15', offer('Apple iPhone 15 128GB')), false, 'unspecified storage must not claim an exact phone variant');
assert.equal(matches('Samsung Galaxy S24 Ultra 512 GB', offer('Samsung Galaxy S24 Ultra 512GB')), true);
assert.equal(matches('Samsung Galaxy S24 Ultra 512 GB', offer('Galaxy S24 Ultra 512GB')), true, 'brand may be implicit in its exclusive family');
assert.equal(matches('Samsung Galaxy S24 Ultra 512 GB', offer('Galaxy S24 Plus 512GB')), false);
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('Samsung iPhone 15 Pro 256GB')), false, 'a conflicting manufacturer must invalidate an otherwise exact family match');
assert.equal(matches('Google Pixel 9 Pro 256 GB', offer('Samsung Pixel 9 Pro 256GB')), false, 'provider titles cannot reuse another manufacturer\'s exclusive family');
assert.equal(matches('Google Pixel 9 Pro 256 GB', offer('Pixel 9 Pro 256GB')), true, 'an exclusive family can carry an omitted manufacturer name');
assert.equal(matches('Apple Watch Ultra 2', offer('Samsung Watch Ultra 2')), false, 'generic product families require the requested manufacturer');
assert.equal(matches('Apple Watch Ultra 2', offer('Watch Ultra 2')), false, 'a generic title without the requested manufacturer is ambiguous');
assert.equal(matches('Apple Watch Ultra 2', offer('Apple Watch Ultra 2')), true);
assert.equal(matches('Apple Watch Series 9 41 mm', offer('Apple Watch Series 9 45mm')), false, 'watch case sizes must not cross-match');
assert.equal(matches('Apple Watch Series 9 41mm', offer('Apple Watch Series 9 41 mm')), true, 'watch case-size spacing normalizes consistently');
assert.equal(matches('Apple Watch Series 9', offer('Apple Watch Series 9 45mm')), false, 'omitted standard watch size must remain ambiguous');
assert.equal(matches('Apple Watch Ultra 2', offer('Apple Watch Ultra 2 49mm')), true, 'the Ultra model has an inherent single case size');
assert.equal(matches('Nintendo Switch OLED weiß', offer('Nintendo Switch OLED Konsole')), true);
assert.equal(matches('Nintendo Switch OLED', offer('Nintendo Switch Lite')), false);
assert.equal(matches('Bosch GSR 12V 15', offer('Bosch GSR 18V 21')), false);
assert.equal(matches('Bosch GSR 12V 15', offer('Bosch GSR 12V 15 Akku Bohrschrauber')), true);
assert.equal(matches('Dyson V15 Detect Absolute', offer('Dyson V12 Detect Absolute')), false, 'numeric model tokens are exact identity constraints');
assert.equal(matches('Dyson V15 Detect Absolute', offer('Dyson V15 Detect Absolute Staubsauger')), true);
assert.equal(matches('Samsung Galaxy S24+', offer('Samsung Galaxy S24 Plus')), true, 'symbol and word variants normalize consistently');
assert.equal(matches('PlayStation 5 Slim', offer('Sony PS5 Slim Konsole')), true, 'common console aliases normalize consistently');
assert.equal(matches('PlayStation 5 Slim', offer('Sony PS5 Standard Konsole')), false);
assert.equal(matches('4006381333931', offer('iPhone 15 Pro', { ean: '4006381333931' })), true);
assert.equal(matches('4006381333931', offer('iPhone 15 Pro', { gtin: '04006381333931' })), true, 'EAN-13 and zero-padded GTIN-14 are the same product identifier');
assert.equal(matches('036000291452', offer('Product', { gtin: '00036000291452' })), true, 'UPC-A and zero-padded GTIN-14 normalize consistently');
assert.equal(matches('4006381333931', offer('iPhone 15 Pro')), false);
assert.equal(matches('4006381333931', offer('iPhone 15 Pro', { product_id: '4006381333931' })), false, 'internal product IDs must never prove barcode identity');
assert.equal(matches('4006381333932', offer('iPhone 15 Pro', { ean: '4006381333932' })), false, 'invalid GS1 check digits must be rejected');
assert.equal(matches('123456789', offer('Product', { ean: '123456789' })), false, 'unsupported numeric lengths are not valid GTINs');
assert.equal(matches('iPhone', offer('iPhone 15 Pro 256GB')), false);
assert.equal(matches('Steam Deck OLED 512 GB', offer('Steam Deck OLED 1 TB')), false, 'storage must match outside phone families too');
assert.equal(matches('Steam Deck OLED 512 GB', offer('Steam Deck OLED 512GB')), true, 'exact generic storage variant should match');
assert.equal(matches('Steam Deck OLED', offer('Steam Deck OLED 512GB')), false, 'ambiguous generic storage must not become an exact LIVE SKU');
assert.equal(matches('Nintendo Switch OLED', offer('Nintendo Switch OLED 64GB Konsole')), true, 'console family keeps inherent-storage exception');
assert.equal(matches('Apple iPad Air M2 256 GB Wi-Fi', offer('Apple iPad Air M2 256GB Cellular')), false, 'tablet connectivity variants must not cross-match');
assert.equal(matches('Apple iPad Air M2 256 GB WLAN', offer('Apple iPad Air M2 256GB Wi-Fi')), true, 'common Wi-Fi aliases normalize consistently');
assert.equal(matches('Apple iPad Air M2 256 GB', offer('Apple iPad Air M2 256GB Wi-Fi')), false, 'omitted tablet connectivity must remain ambiguous');
assert.equal(matches('PlayStation 5 Slim Digital Edition', offer('Sony PS5 Slim Disc Edition')), false, 'console editions must not cross-match');
assert.equal(matches('PlayStation 5 Slim ohne Laufwerk', offer('Sony PS5 Slim Digital Edition')), true, 'console edition aliases normalize consistently');
assert.equal(matches('PlayStation 5 Slim', offer('Sony PS5 Slim Disc Edition')), false, 'omitted console edition must remain ambiguous');
assert.equal(matches('Microsoft Xbox Series X 1 TB', offer('Xbox Series X 1024GB')), true, 'Xbox manufacturer and storage aliases normalize consistently');
assert.equal(matches('Xbox Series X', offer('Microsoft Xbox Series S')), false, 'Xbox Series X and Series S must not cross-match');
assert.equal(matches('Xbox One X', offer('Microsoft Xbox One S')), false, 'Xbox One X and One S must not cross-match');
assert.equal(matches('Xbox Series X', offer('Microsoft Xbox Series X 1TB')), true, 'named Xbox console models may use their inherent base storage');
assert.equal(matches('Xbox Series X 1TB', offer('Microsoft Xbox Series X 2TB')), false, 'an explicit Xbox storage request must still match exactly');
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('Hülle für Apple iPhone 15 Pro 256GB')), false, 'accessory-only titles must not become LIVE device matches');
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('Apple iPhone 15 Pro 256GB mit Hülle und Kabel')), true, 'bundled accessories after the device name remain valid');
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('Apple iPhone 15 Pro 256GB Displaybruch')), false, 'damage in a non-defective condition is a conflicting mapping');
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('Apple iPhone 15 Pro 256GB Display Bruch')), false, 'split damage wording must also fail closed');
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('Apple iPhone 15 Pro 256GB Wasser Schaden')), false, 'split water-damage wording must fail closed');
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('Apple iPhone 15 Pro 256GB ohne Funktion')), false, 'a non-functional device must not match a functional condition');
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('Apple iPhone 15 Pro 256GB startet nicht')), false, 'a device that does not start must not match a functional condition');
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('Apple iPhone 15 Pro 256GB Face ID funktioniert nicht')), false, 'a failed device function must not match a functional condition');
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('Apple iPhone 15 Pro 256GB no power')), false, 'common English failure wording must fail closed');
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('Apple iPhone 15 Pro 256GB Displaybruch', { condition: 'defective' })), true, 'damage wording is valid for the explicit defective condition');
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('Apple iPhone 15 Pro 256GB ohne Funktion', { condition: 'defective' })), true, 'multi-word damage wording is valid for the explicit defective condition');

console.log('buyback_match_test: ok');
