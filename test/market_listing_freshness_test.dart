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

  test('fresh timestamp with an explicit offset is normalized to UTC', () {
    final listing = SourceListing.fromJson(
      payload(checkedAt: '2026-10-12T01:56:00+02:00'),
      source,
      now: now,
    );

    expect(listing.live, isTrue);
    expect(listing.checkedAt, now.subtract(const Duration(minutes: 4)));
    expect(listing.checkedAt!.isUtc, isTrue);
  });

  test('timezone-free timestamps never become LIVE evidence', () {
    for (final checkedAt in <String>[
      '2026-10-12',
      '2026-10-12T00:00:00',
      '2026-10-12 00:00:00',
    ]) {
      final listing = SourceListing.fromJson(
        payload(checkedAt: checkedAt),
        source,
        now: now,
      );

      expect(listing.live, isFalse, reason: checkedAt);
      expect(listing.checkedAt, isNull, reason: checkedAt);
    }
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

  test('missing or unsafe offer links cannot become LIVE evidence', () {
    for (final url in <String>[
      '',
      'http://www.ebay.de/itm/123',
      'https://user:secret@www.ebay.de/itm/123',
      'https://localhost/itm/123',
      'https://api.localhost./itm/123',
      'https://192.168.1.2/itm/123',
      'https://[fd00::1]/itm/123',
      'https://[::ffff:127.0.0.1]/itm/123',
      'https://[2001:db8::1]/itm/123',
      'https://[ff02::1]/itm/123',
      'https://www.ebay.de:8443/itm/123',
    ]) {
      final raw = payload(checkedAt: now.toIso8601String())..['url'] = url;
      final listing = SourceListing.fromJson(raw, source, now: now);
      expect(listing.live, isFalse, reason: url);
      expect(listing.hasSafeOfferUrl, isFalse, reason: url);
    }
  });

  test('public HTTPS offer link on the standard port stays eligible', () {
    final raw = payload(checkedAt: now.toIso8601String())
      ..['url'] = 'https://www.ebay.de:443/itm/123';
    final listing = SourceListing.fromJson(raw, source, now: now);

    expect(listing.live, isTrue);
    expect(listing.hasSafeOfferUrl, isTrue);
  });
}
