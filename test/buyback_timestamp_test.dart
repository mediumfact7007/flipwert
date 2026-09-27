import 'package:flipwert/buyback.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> payload(String checkedAt) => {
  'provider_id': 'example', 'provider_name': 'Example',
  'product_id': 'phone', 'matched_title': 'Phone 256 GB',
  'condition': 'like_new', 'price': 620, 'currency': 'EUR',
  'offer_url': 'https://example.com/offer', 'checked_at': checkedAt,
  'price_kind': 'indicative_buyback', 'payout_type': 'cash',
  'requires_inspection': true,
  'match_confidence': 0.98,
};

void main() {
  test('requires provider timestamps to carry an explicit timezone', () {
    expect(() => BuybackOffer.fromJson(payload('2026-09-23T10:00:00')), throwsFormatException);
    expect(BuybackOffer.fromJson(payload('2026-09-23T10:00:00Z')).checkedAt.isUtc, isTrue);
    expect(BuybackOffer.fromJson(payload('2026-09-23T12:00:00+02:00')).checkedAt.toUtc(), DateTime.parse('2026-09-23T10:00:00Z'));
  });
}
