import 'package:flipwert/buyback_source_bridge.dart';
import 'package:flipwert/source_registry.dart';
import 'package:flutter_test/flutter_test.dart';

const buybackSource = PriceSource(
  id: 'buyback-test',
  name: 'Buyback Test',
  subtitle: 'test',
  searchUrlTemplate: 'https://example.com/?q={query}',
  role: 'buyback',
  trustedForDecision: true,
);

Map<String, dynamic> payload(
  DateTime checkedAt, {
  double price = 620,
  String providerId = 'provider',
  double confidence = 0.98,
}) => {
      'title': 'Apple iPhone 15 Pro 256 GB',
      'provider_id': providerId,
      'provider_name': providerId,
      'product_id': 'iphone-15-pro-256',
      'matched_title': 'Apple iPhone 15 Pro 256 GB',
      'condition': 'like_new',
      'price': price,
      'currency': 'EUR',
      'offer_url': 'https://example.com/offer',
      'checked_at': checkedAt.toIso8601String(),
      'price_kind': 'indicative_buyback',
      'payout_type': 'cash',
      'requires_inspection': true,
      'match_confidence': confidence,
      'live': true,
    };

void main() {
  test('bridge only promotes fresh comparable buyback offers', () {
    final now = DateTime.parse('2026-09-22T08:00:00Z');
    final fresh = parseBuybackSourceItem(payload(now.subtract(const Duration(hours: 2))), buybackSource);
    final stale = parseBuybackSourceItem(payload(now.subtract(const Duration(hours: 25)), price: 700), buybackSource);
    final future = parseBuybackSourceItem(payload(now.add(const Duration(minutes: 6)), price: 800), buybackSource);

    expect(fresh.hasFreshComparableOfferAt(now), isTrue);
    expect(stale.hasFreshComparableOfferAt(now), isFalse);
    expect(future.hasFreshComparableOfferAt(now), isFalse);
    expect(comparableBuybackOffers([fresh, stale, future], now: now).map((offer) => offer.price), [620]);
  });

  test('bridge preserves a custom freshness window through deduplication', () {
    final now = DateTime.parse('2026-09-22T08:00:00Z');
    final older = parseBuybackSourceItem(
      payload(now.subtract(const Duration(hours: 30))),
      buybackSource,
    );

    expect(
      comparableBuybackOffers(
        [older],
        now: now,
        maxAge: const Duration(hours: 36),
      ).map((offer) => offer.price),
      [620],
    );
  });

  test('bridge keeps one trustworthy quote per provider', () {
    final now = DateTime.parse('2026-09-22T08:00:00Z');
    final highPriceWeakMatch = parseBuybackSourceItem(payload(now, price: 690, confidence: 0.91), buybackSource);
    final trustedMatch = parseBuybackSourceItem(payload(now, price: 620, confidence: 0.99), buybackSource);
    final independentProvider = parseBuybackSourceItem(
      payload(now, price: 610, providerId: 'other-provider', confidence: 0.98),
      buybackSource,
    );

    final offers = comparableBuybackOffers([highPriceWeakMatch, trustedMatch, independentProvider], now: now);

    expect(offers, hasLength(2));
    expect(offers.first.providerId, 'provider');
    expect(offers.first.price, 620);
    expect(offers.last.providerId, 'other-provider');
  });

  test('malformed buyback payload remains visible but never comparable', () {
    final now = DateTime.parse('2026-09-22T08:00:00Z');
    final json = payload(now)..remove('offer_url');
    final result = parseBuybackSourceItem(json, buybackSource);

    expect(result.listing.title, 'Apple iPhone 15 Pro 256 GB');
    expect(result.offer, isNull);
    expect(result.hasComparableOffer, isFalse);
    expect(comparableBuybackOffers([result], now: now), isEmpty);
  });

  test('store credit remains visible but never becomes a comparable payout', () {
    final now = DateTime.parse('2026-09-22T08:00:00Z');
    final json = payload(now)..['payout_type'] = 'store_credit';
    final result = parseBuybackSourceItem(json, buybackSource);

    expect(result.listing.title, 'Apple iPhone 15 Pro 256 GB');
    expect(result.offer, isNull);
    expect(comparableBuybackOffers([result], now: now), isEmpty);
  });
}
