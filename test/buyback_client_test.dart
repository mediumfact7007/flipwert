import 'dart:convert';

import 'package:flipwert/buyback.dart';
import 'package:flipwert/buyback_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

BuybackOffer offer(
  String provider,
  double price, {
  double confidence = 0.98,
  String checkedAt = '2026-09-22T12:00:00Z',
}) =>
    BuybackOffer(
      providerId: provider,
      providerName: provider,
      productId: 'iphone-15-pro-256',
      matchedTitle: 'Apple iPhone 15 Pro 256 GB',
      condition: BuybackCondition.usedGood,
      price: price,
      currency: 'EUR',
      offerUrl: Uri.parse('https://example.com/$provider'),
      checkedAt: DateTime.parse(checkedAt),
      requiresInspection: true,
      matchConfidence: confidence,
    );

void main() {
  test('normalizes whitespace before buyback searches', () {
    expect(
      normalizeBuybackQuery('  Apple\t iPhone 15 Pro\n256 GB  '),
      'Apple iPhone 15 Pro 256 GB',
    );
  });

  test('preserves word boundaries for embedded control characters', () {
    expect(
      normalizeBuybackQuery('Apple\u0000iPhone\u001F15\u007FPro\u0085256 GB'),
      'Apple iPhone 15 Pro 256 GB',
    );
  });

  test('preserves word boundaries for invisible copy-paste separators', () {
    expect(
      normalizeBuybackQuery('Apple\u200BiPhone 15 Pro\u2060 256 GB\uFEFF'),
      'Apple iPhone 15 Pro 256 GB',
    );
  });

  test('preserves word boundaries around bidi formatting marks', () {
    expect(
      normalizeBuybackQuery('Apple\u202EiPhone 15\u2067Pro\u2069 256 GB'),
      'Apple iPhone 15 Pro 256 GB',
    );
  });

  test('keeps long shared titles searchable at a word boundary', () {
    final suffix = List.filled(12, 'sehr guter Zustand ').join();
    final title = 'Apple iPhone 15 Pro 256 GB $suffix';
    final limited = limitBuybackQuery(normalizeBuybackQuery(title));

    expect(limited, startsWith('Apple iPhone 15 Pro 256 GB'));
    expect(limited.length, lessThanOrEqualTo(180));
    expect(limited, isNot(endsWith(' ')));
  });

  test('keeps only the best quote from each buyback provider', () {
    final result = distinctBuybackOffers([
      offer('rebuy', 510),
      offer('rebuy', 525),
      offer('wirkaufens', 520),
    ]);

    expect(result.map((item) => item.providerId), ['rebuy', 'wirkaufens']);
    expect(result.map((item) => item.price), [525, 520]);
  });

  test('normalizes provider ids before deduplication', () {
    final result = distinctBuybackOffers([
      offer(' Rebuy ', 500),
      offer('rebuy', 515),
    ]);

    expect(result, hasLength(1));
    expect(result.single.price, 515);
  });

  test('prefers a more confident provider match over a higher price', () {
    final result = distinctBuybackOffers([
      offer('rebuy', 550, confidence: 0.91),
      offer('rebuy', 510, confidence: 0.99),
    ]);

    expect(result, hasLength(1));
    expect(result.single.price, 510);
    expect(result.single.matchConfidence, 0.99);
  });

  test('prefers a fresher quote when provider match confidence is equal', () {
    final result = distinctBuybackOffers([
      offer('rebuy', 540, checkedAt: '2026-09-22T10:00:00Z'),
      offer('rebuy', 515, checkedAt: '2026-09-22T12:00:00Z'),
    ]);

    expect(result, hasLength(1));
    expect(result.single.price, 515);
    expect(result.single.checkedAt, DateTime.parse('2026-09-22T12:00:00Z'));
  });

  test('ranks trustworthy provider matches before higher indicative prices', () {
    final result = distinctBuybackOffers([
      offer('high-price', 590, confidence: 0.91),
      offer('trusted', 510, confidence: 0.99),
    ]);

    expect(result.map((item) => item.providerId), ['trusted', 'high-price']);
  });

  test('keeps equally strong providers stable across response order', () {
    final first = distinctBuybackOffers([
      offer('zeta', 510),
      offer('alpha', 510),
    ]);
    final reversed = distinctBuybackOffers([
      offer('alpha', 510),
      offer('zeta', 510),
    ]);

    expect(first.map((item) => item.providerId), ['alpha', 'zeta']);
    expect(reversed.map((item) => item.providerId), ['alpha', 'zeta']);
  });

  test('drops stale and implausibly future-dated quotes when rechecking', () {
    final result = distinctBuybackOffers(
      [
        offer('stale', 600, checkedAt: '2026-09-21T11:59:59Z'),
        offer('fresh', 510, checkedAt: '2026-09-22T12:00:00Z'),
        offer('future', 700, checkedAt: '2026-09-22T12:06:00Z'),
      ],
      now: DateTime.parse('2026-09-22T12:00:00Z'),
    );

    expect(result.map((item) => item.providerId), ['fresh']);
  });

  test('respects a caller-defined freshness window when rechecking', () {
    final result = distinctBuybackOffers(
      [offer('older', 510, checkedAt: '2026-09-21T06:00:00Z')],
      now: DateTime.parse('2026-09-22T12:00:00Z'),
      maxAge: const Duration(hours: 36),
    );

    expect(result.map((item) => item.providerId), ['older']);
  });

  test('preserves configured live-source status with validated offers', () async {
    final client = BuybackClient(
      backendBase: 'https://api.flipwert.example',
      client: MockClient((request) async {
        expect(request.url.path, '/v1/buyback/search');
        expect(request.url.queryParameters['condition'], 'used_good');
        return http.Response(
          jsonEncode({
            'configured': true,
            'readiness': 'ready',
            'live': true,
            'unavailable': false,
            'items': [
              {
                'provider_id': 'rebuy',
                'provider_name': 'reBuy',
                'product_id': 'iphone-15-pro-256',
                'matched_title': 'Apple iPhone 15 Pro 256 GB',
                'condition': 'used_good',
                'price': 510,
                'currency': 'EUR',
                'offer_url': 'https://example.com/rebuy',
                'checked_at': '2026-09-22T12:00:00Z',
                'price_kind': 'indicative_buyback',
                'requires_inspection': true,
                'match_confidence': 0.98,
              },
              {
                'provider_id': 'rebuy',
                'provider_name': 'reBuy',
                'product_id': 'iphone-15-pro-256',
                'matched_title': 'Apple iPhone 15 Pro 256 GB',
                'condition': 'like_new',
                'price': 700,
                'currency': 'EUR',
                'offer_url': 'https://example.com/rebuy-like-new',
                'checked_at': '2026-09-22T12:00:00Z',
                'price_kind': 'indicative_buyback',
                'requires_inspection': true,
                'match_confidence': 0.99,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final result = await client.searchDetailed(
      'Apple iPhone 15 Pro 256 GB',
      condition: BuybackCondition.usedGood,
      now: DateTime.parse('2026-09-22T12:00:00Z'),
    );

    expect(result.configured, isTrue);
    expect(result.live, isTrue);
    expect(result.unavailable, isFalse);
    expect(result.readiness, BuybackReadiness.ready);
    expect(result.offers.single.providerId, 'rebuy');
    expect(result.offers.single.condition, BuybackCondition.usedGood);
  });

  test('distinguishes disabled, empty and unavailable buyback sources', () async {
    Future<BuybackSearchResult> resultFor(Map<String, Object> payload) => BuybackClient(
      backendBase: 'https://api.flipwert.example',
      client: MockClient((_) async => http.Response(jsonEncode(payload), 200)),
    ).searchDetailed('Apple iPhone 15 Pro', condition: BuybackCondition.usedGood);

    final disabled = await resultFor({'configured': false, 'live': false, 'items': <Object>[]});
    final empty = await resultFor({'configured': true, 'live': false, 'items': <Object>[]});
    final unavailable = await resultFor({'configured': true, 'live': false, 'unavailable': true, 'items': <Object>[]});

    expect(disabled.configured, isFalse);
    expect(disabled.unavailable, isFalse);
    expect(empty.configured, isTrue);
    expect(empty.unavailable, isFalse);
    expect(unavailable.configured, isTrue);
    expect(unavailable.unavailable, isTrue);
  });

  test('maps only documented readiness reasons to safe app states', () {
    expect(
      parseBuybackReadiness('missing_or_stale_validation'),
      BuybackReadiness.awaitingValidation,
    );
    expect(
      parseBuybackReadiness('no_current_provider_approvals'),
      BuybackReadiness.approvalsMissing,
    );
    expect(
      parseBuybackReadiness('missing_token'),
      BuybackReadiness.notConfigured,
    );
    expect(parseBuybackReadiness({'unexpected': true}), isNull);
  });
}
