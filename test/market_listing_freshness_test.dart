import 'package:flutter_test/flutter_test.dart';
import 'package:flipwert/source_registry.dart';

void main() {
  const source = PriceSource(
    id: 'ebay_de',
    name: 'eBay.de',
    subtitle: 'LIVE',
    searchUrlTemplate: 'https://www.ebay.de/sch/i.html?_nkw={query}',
    role: 'resale',
    trustedForDecision: true,
  );
  final now = DateTime.utc(2026, 10, 12, 0);

  Map<String, dynamic> payload({String? checkedAt}) => {
        'title': 'Apple iPhone 15 Pro 256 GB',
        'price': 700,
        'shipping': 5,
        'url': 'https://www.ebay.de/itm/123',
        'condition': 'Gut',
        'live': true,
        if (checkedAt != null) 'checked_at': checkedAt,
      };

  test('fresh timestamp keeps approved listing LIVE', () {
    final listing = SourceListing.fromJson(
      payload(
        checkedAt: now
            .subtract(const Duration(minutes: 4))
            .toIso8601String(),
      ),
      source,
      now: now,
    );

    expect(listing.live, isTrue);
    expect(listing.checkedAt, now.subtract(const Duration(minutes: 4)));
  });

  test('missing, future and stale timestamps fail closed', () {
    for (final checkedAt in <String?>[
      null,
      'invalid',
      now.add(const Duration(seconds: 1)).toIso8601String(),
      now.subtract(const Duration(minutes: 6)).toIso8601String(),
    ]) {
      expect(
        SourceListing.fromJson(
          payload(checkedAt: checkedAt),
          source,
          now: now,
        ).live,
        isFalse,
        reason: 'checked_at=$checkedAt',
      );
    }
  });

  test('non-boolean live flag remains non-LIVE despite fresh timestamp', () {
    final raw = payload(checkedAt: now.toIso8601String())..['live'] = 'true';
    expect(SourceListing.fromJson(raw, source, now: now).live, isFalse);
  });
}
