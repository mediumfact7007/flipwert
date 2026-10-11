'use strict';

const assert = require('assert');
const {
  assessMarketListings,
  filterMarketListings,
  listingMatchesQuery,
} = require('./market_quality');

const good = 'Apple iPhone 15 Pro 256GB Titan';
assert.strictEqual(listingMatchesQuery('Apple iPhone 15 Pro 256GB', good), true);
for (const bad of [
  'Hülle Case für Apple iPhone 15 Pro 256GB',
  'Apple iPhone 15 Pro 128GB',
  'Apple iPhone 15 Pro Max 256GB',
  'Apple iPhone 15 Pro 256GB defekt für Bastler',
  'Apple iPhone 15 Pro 256GB funktioniert nicht',
  'Apple iPhone 15 Pro 256GB spares or repair',
  'Apple iPhone 15 Pro 256GB zum Ausschlachten',
  'Apple iPhone 15 Pro 256GB nur Karton',
  'Apple iPhone 15 Pro 256GB Karton ohne Gerät',
  'Apple iPhone 15 Pro 256GB box without device',
  'Apple iPhone 15 Pro 256GB original box only',
  'Apple iPhone 15 Pro 256GB Originalverpackung leer',
  'Apple iPhone 15 Pro 256GB OVP leer',
  'Apple iPhone 15 Pro 256GB nur OVP',
  'Apple iPhone 15 Pro 256GB Displaybruch',
  'Apple iPhone 15 Pro 256GB Glasbruch',
  'Apple iPhone 15 Pro 256GB Wasserschaden',
  'Apple iPhone 15 Pro 256GB water damage',
  'Apple iPhone 15 Pro 256GB iCloud locked',
  'Apple iPhone 15 Pro 256GB activation lock',
  'Apple iPhone 15 Pro 256GB Rückseite gebrochen',
  'Apple iPhone 15 Pro 256GB back glass cracked',
  'Apple iPhone 15 Pro 256GB Face ID defekt',
  'Apple iPhone 15 Pro 256GB Face ID not working',
  'Apple iPhone 15 Pro 256GB Kamera defekt',
  'Apple iPhone 15 Pro 256GB camera not working',
  'Apple MacBook Pro 15 256GB',
  'Apple iPhone 15 Pro 256GB + Apple Watch Bundle',
  '2x Apple iPhone 15 Pro 256GB',
  'Apple iPhone 15 Pro 256GB mit Vertrag monatlich',
  'Apple iPhone 15 Pro 256GB nur 99 EUR Anzahlung',
]) assert.strictEqual(listingMatchesQuery('Apple iPhone 15 Pro 256GB', bad), false, bad);

for (const intentional of [
  'Apple iPhone 15 Pro 256GB defekt',
  'Apple iPhone 15 Pro 256GB reparaturbedürftig',
  'Apple iPhone 15 Pro 256GB funktioniert nicht',
  'Apple iPhone 15 Pro 256GB spares or repair',
  'Apple iPhone 15 Pro 256GB repair only',
  'Apple iPhone 15 Pro 256GB zum Ausschlachten',
  'Apple iPhone 15 Pro 256GB Displaybruch',
  'Apple iPhone 15 Pro 256GB Wasserschaden',
  'Apple iPhone 15 Pro 256GB iCloud locked',
  'Apple iPhone 15 Pro 256GB Face ID defekt',
  'Apple iPhone 15 Pro 256GB Kamera defekt',
]) assert.strictEqual(listingMatchesQuery(intentional, intentional), true, intentional);

assert.strictEqual(listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB OVP vollständig'), true);
assert.strictEqual(listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB mit Originalverpackung'), true);
assert.strictEqual(listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB voll funktionsfähig'), true);
assert.strictEqual(listingMatchesQuery('Apple iPhone 15 Pro 256GB', 'Apple iPhone 15 Pro 256GB frisch repariert voll funktionsfähig'), true);
assert.strictEqual(listingMatchesQuery('PlayStation 5 Slim', 'Sony PS5 Slim Konsole 1TB'), true);
assert.strictEqual(listingMatchesQuery('PlayStation 5 Slim', 'PS5 Slim Halterung Wall Mount'), false);
assert.strictEqual(listingMatchesQuery('Nintendo Switch', 'Nintendo Switch OLED Konsole'), false);
assert.strictEqual(listingMatchesQuery('Nintendo Switch OLED', 'Nintendo Switch OLED Konsole'), true);
assert.strictEqual(listingMatchesQuery('Xbox Series X', 'Microsoft Xbox Series X 1TB Konsole'), true);
assert.strictEqual(listingMatchesQuery('Xbox Series X', 'Microsoft Xbox Series S 512GB Konsole'), false);
assert.strictEqual(listingMatchesQuery('Xbox Series S', 'Microsoft Xbox Series X 1TB Konsole'), false);
assert.strictEqual(
  listingMatchesQuery('Samsung S25 Ultra 256GB', 'Samsung Galaxy S25 Ultra 256GB'),
  true,
  'an omitted family word must not reject an otherwise exact model',
);
assert.strictEqual(
  listingMatchesQuery(
    'Apple iPhone 15 Pro 256GB mit Vertrag',
    'Apple iPhone 15 Pro 256GB mit Vertrag monatlich',
  ),
  false,
  'an unrequested monthly-payment qualifier must still fail closed',
);
assert.strictEqual(
  listingMatchesQuery(
    'Apple iPhone 15 Pro 256GB Bundle Apple Watch',
    'Apple iPhone 15 Pro 256GB Bundle Apple Watch',
  ),
  true,
  'explicitly requested bundles remain searchable',
);

const filtered = filterMarketListings('Apple iPhone 15 Pro 256GB', [
  { title: good },
  { title: 'Apple iPhone 15 Pro 128GB' },
  { title: 'Case für Apple iPhone 15 Pro 256GB' },
  { title: 'Apple iPhone 15 Pro Max 256GB' },
  { title: 'Apple iPhone 15 Pro 256GB Displaybruch' },
  { title: 'Apple iPhone 15 Pro 256GB iCloud locked' },
  { title: 'Apple iPhone 15 Pro 256GB Face ID defekt' },
]);
assert.deepStrictEqual(filtered.map((item) => item.title), [good]);

const assessed = assessMarketListings('Apple iPhone 15 Pro 256GB', [
  { title: good, price: 800 },
  { title: 'Apple iPhone 15 Pro 128GB', price: 700 },
]);
assert.deepStrictEqual(assessed.items, [{ title: good, price: 800 }]);
assert.strictEqual(assessed.rejectedCount, 1);

console.log('market_quality_test: ok');
