import 'package:flipwert/buyback.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> payload(String expiresAt) => {
      'provider_id': 'provider',
      'provider_name': 'Provider',
      'product_id': 'phone-256',
      'matched_title': 'Phone 256 GB',
      'condition': 'like_new',
      'price': 620,
      'currency': 'EUR',
      'offer_url': 'https://provider.example/offer/123',
      'checked_at': '2026-09-27T12:00:00Z',
      'expires_at': expiresAt,
      'price_kind': 'indicative_buyback',
      'payout_type': 'cash',
      'requires_inspection': true,
      'match_confidence': 0.98,
    };

void main() {
  test('provider expiry limits offer freshness before the global maximum age', () {
    final offer = BuybackOffer.fromJson(payload('2026-09-27T12:15:00Z'));

    expect(offer.isFreshAt(DateTime.parse('2026-09-27T12:14:59Z')), isTrue);
    expect(offer.isFreshAt(DateTime.parse('2026-09-27T12:15:00Z')), isFalse);
    expect(
      bestComparableBuybackOffer(
        [offer],
        condition: BuybackCondition.likeNew,
        now: DateTime.parse('2026-09-27T12:15:00Z'),
      ),
      isNull,
    );
  });

  test('invalid or timezone-free provider expiry fails closed', () {
    for (final expiry in [
      '2026-09-27T11:59:00Z',
      '2026-09-27T12:15:00',
      'not-a-date',
    ]) {
      expect(
        () => BuybackOffer.fromJson(payload(expiry)),
        throwsFormatException,
        reason: expiry,
      );
    }
  });
}
