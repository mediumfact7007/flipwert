'use strict';

const assert = require('node:assert/strict');
const { matchesBuybackQuery: matches } = require('./buyback_match');
const offer = (matched_title, extra = {}) => ({ matched_title, product_id: 'internal-123', ...extra });

assert.equal(matches('Apple iPhone 15 Pro 256 GB mit OVP', offer('Apple iPhone 15 Pro 256GB')), true);
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('iPhone 15 Pro Max 256GB')), false);
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('iPhone 15 Pro 128GB')), false);
assert.equal(matches('Apple iPhone 15 Pro 256 GB', offer('iPhone 14 Pro 256GB')), false);
assert.equal(matches('Apple iPhone 15', offer('Apple iPhone 15 128GB')), false, 'unspecified storage must not claim an exact phone variant');
assert.equal(matches('Samsung Galaxy S24 Ultra 512 GB', offer('Samsung Galaxy S24 Ultra 512GB')), true);
assert.equal(matches('Samsung Galaxy S24 Ultra 512 GB', offer('Galaxy S24 Plus 512GB')), false);
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
assert.equal(matches('4006381333931', offer('iPhone 15 Pro')), false);
assert.equal(matches('iPhone', offer('iPhone 15 Pro 256GB')), false);
assert.equal(matches('Steam Deck OLED 512 GB', offer('Steam Deck OLED 1 TB')), false, 'storage must match outside phone families too');
assert.equal(matches('Steam Deck OLED 512 GB', offer('Steam Deck OLED 512GB')), true, 'exact generic storage variant should match');
assert.equal(matches('Steam Deck OLED', offer('Steam Deck OLED 512GB')), false, 'ambiguous generic storage must not become an exact LIVE SKU');
assert.equal(matches('Nintendo Switch OLED', offer('Nintendo Switch OLED 64GB Konsole')), true, 'console family keeps inherent-storage exception');

console.log('buyback_match_test: ok');
