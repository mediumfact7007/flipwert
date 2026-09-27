import 'package:flipwert/buyback.dart';
import 'package:flipwert/buyback_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider deductions keep profit and ranking on net payout', () {
    final offer = BuybackOffer.fromJson({
      'provider_id': 'provider',
      'provider_name': 'Provider',
      'product_id': 'phone-256',
      'matched_title': 'Phone 256 GB',
      'condition': 'like_new',
      'price': 595,
      'listed_price': 620,
      'mandatory_deductions_eur': 25,
      'price_basis': 'net_after_mandatory_deductions',
      'currency': 'EUR',
      'offer_url': 'https://provider.example/offer/123',
      'checked_at': '2026-09-27T11:55:00Z',
      'price_kind': 'indicative_buyback',
      'payout_type': 'cash',
      'requires_inspection': true,
      'match_confidence': 0.98,
    });

    final summary = BuybackComparisonSummary(
      offer: offer,
      purchasePrice: 500,
      privateMarketValue: 640,
    );

    expect(offer.displayedListedPrice, 620);
    expect(offer.mandatoryDeductionsEur, 25);
    expect(summary.effectiveInstantProceeds, 595);
    expect(summary.instantMargin, 95);
  });

  test('inconsistent provider deduction fields fail closed', () {
    expect(
      () => BuybackOffer.fromJson({
        'provider_id': 'provider',
        'provider_name': 'Provider',
        'product_id': 'phone-256',
        'matched_title': 'Phone 256 GB',
        'condition': 'like_new',
        'price': 600,
        'listed_price': 620,
        'mandatory_deductions_eur': 25,
        'price_basis': 'net_after_mandatory_deductions',
        'currency': 'EUR',
        'offer_url': 'https://provider.example/offer/123',
        'checked_at': '2026-09-27T11:55:00Z',
        'price_kind': 'indicative_buyback',
        'payout_type': 'cash',
        'match_confidence': 0.98,
      }),
      throwsFormatException,
    );
  });
}
