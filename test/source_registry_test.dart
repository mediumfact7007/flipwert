import 'package:flipwert/source_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('third-party source cannot influence automatic decision', () {
    final source = PriceSource.fromJson({
      'id': 'partner-shop',
      'name': 'Partner Shop',
      'search_url': 'https://partner.example/search?q={query}',
      'adapter_url': 'https://api.partner.example/search?q={query}',
      'role': 'resale',
      'color': 'ABCDEF',
    });
    expect(source.builtIn, isFalse);
    expect(source.trustedForDecision, isFalse);
    final listing = SourceListing.fromJson({
      'title': 'Manipulated result',
      'price': 9999,
      'shipping': 0,
      'live': true,
    }, source);
    expect(listing.role, 'reference');
  });

  test('private or insecure adapter URLs are rejected', () {
    expect(
      () => PriceSource.fromJson({
        'name': 'Unsafe',
        'search_url': 'https://example.com/?q={query}',
        'adapter_url': 'http://127.0.0.1:8080/?q={query}',
      }),
      throwsFormatException,
    );
    expect(
      () => PriceSource.fromJson({
        'name': 'Unsafe LAN',
        'search_url': 'https://example.com/?q={query}',
        'adapter_url': 'https://192.168.1.5/?q={query}',
      }),
      throwsFormatException,
    );
  });

  test('localized adapter prices parse while malformed LIVE stays non-live', () {
    const source = PriceSource(
      id: 'trusted-test',
      name: 'Trusted',
      subtitle: 'test',
      searchUrlTemplate: 'https://example.com/?q={query}',
      role: 'resale',
      trustedForDecision: true,
    );
    final listing = SourceListing.fromJson({
      'title': 'Item',
      'price': '1.299,99 €',
      'shipping': '4,99',
      'live': 'true',
    }, source);
    expect(listing.price, closeTo(1299.99, 0.001));
    expect(listing.shipping, closeTo(4.99, 0.001));
    expect(listing.total, closeTo(1304.98, 0.001));
    expect(listing.live, isFalse);
  });

  test('only explicit boolean true with fresh timestamp and link marks LIVE', () {
    const source = PriceSource(
      id: 'trusted-test',
      name: 'Trusted',
      subtitle: 'test',
      searchUrlTemplate: 'https://example.com/?q={query}',
      role: 'resale',
      trustedForDecision: true,
    );

    final now = DateTime.utc(2026, 10, 12);
    final missing = SourceListing.fromJson({
      'price': 100,
      'shipping': 0,
    }, source, now: now);
    final missingTimestamp = SourceListing.fromJson({
      'price': 100,
      'shipping': 0,
      'live': true,
    }, source, now: now);
    final explicit = SourceListing.fromJson({
      'price': 100,
      'shipping': 0,
      'url': 'https://example.com/item/100',
      'live': true,
      'checked_at': now.toIso8601String(),
    }, source, now: now);

    expect(missing.live, isFalse);
    expect(missingTimestamp.live, isFalse);
    expect(explicit.live, isTrue);
  });

  test('invalid color and role fall back safely', () {
    final source = PriceSource.fromJson({
      'name': 'Safe Source',
      'search_url': 'https://example.com/?q={query}',
      'role': 'super-trusted',
      'color': 'not-a-color',
    });
    expect(source.role, 'reference');
    expect(source.colorHex, '5146E5');
  });

  test('German quick-compare sources include Vinted and Geizhals', () {
    final sources = SourceRegistry.builtIns();
    final vinted = sources.singleWhere((s) => s.id == 'vinted');
    final geizhals = sources.singleWhere((s) => s.id == 'geizhals');
    expect(vinted.searchUrl('Nike Dunk'), contains('search_text=Nike+Dunk'));
    expect(vinted.canFetchInApp, isFalse);
    expect(geizhals.searchUrl('Galaxy S26'), contains('fs=Galaxy+S26'));
    expect(geizhals.canFetchInApp, isFalse);
  });

  test('adapter outages fail instead of looking like zero offers', () async {
    const source = PriceSource(
      id: 'trusted-test',
      name: 'Trusted',
      subtitle: 'test',
      searchUrlTemplate: 'https://example.com/?q={query}',
      adapterUrlTemplate: 'https://api.example.com/?q={query}',
    );

    await expectLater(
      SourceRegistry.fetch(
        source,
        'iPhone 15 Pro',
        request: (_) async => http.Response('unavailable', 503),
      ),
      throwsA(
        isA<SourceFetchException>()
            .having((error) => error.code, 'code', 'upstream_http_error')
            .having((error) => error.statusCode, 'statusCode', 503),
      ),
    );
  });

  test('valid empty response stays distinct from malformed response', () async {
    const source = PriceSource(
      id: 'trusted-test',
      name: 'Trusted',
      subtitle: 'test',
      searchUrlTemplate: 'https://example.com/?q={query}',
      adapterUrlTemplate: 'https://api.example.com/?q={query}',
    );

    expect(
      await SourceRegistry.fetch(
        source,
        'iPhone 15 Pro',
        request: (_) async => http.Response('{"items":[]}', 200),
      ),
      isEmpty,
    );
    await expectLater(
      SourceRegistry.fetch(
        source,
        'iPhone 15 Pro',
        request: (_) async => http.Response('{}', 200),
      ),
      throwsA(
        isA<SourceFetchException>().having(
          (error) => error.code,
          'code',
          'invalid_response_shape',
        ),
      ),
    );
  });

  test('rebuy buyback shortcut opens the selling flow and is not price evidence', () {
    final rebuy = SourceRegistry.builtIns().singleWhere((s) => s.id == 'rebuy');
    expect(rebuy.searchUrl('iPhone 15 Pro'), 'https://www.rebuy.de/verkaufen');
    expect(rebuy.searchUrl('iPhone 15 Pro'), isNot(contains('/kaufen/')));
    expect(rebuy.canFetchInApp, isFalse);
    expect(rebuy.trustedForDecision, isFalse);
  });

}
