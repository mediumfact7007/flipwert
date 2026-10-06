import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_text.dart';
import 'package:flipwert/source_status.dart';

void main() {
  test('eBay Sandbox is configured but never reported as LIVE', () {
    final status = MarketBackendStatus.fromJson({
      'sources': {
        'ebay_de': {
          'configured': true,
          'mode': 'official_api',
          'environment': 'sandbox',
          'data_kind': 'sandbox_mock_data',
        },
      },
    });

    expect(status.reachable, isTrue);
    expect(status.isSandbox('ebay_de'), isTrue);
    expect(status.isLive('ebay_de'), isFalse);
    expect(status.sources['ebay_de']?.dataKind, 'sandbox_mock_data');
  });

  test('eBay Production can be reported as LIVE when configured', () {
    final status = MarketBackendStatus.fromJson({
      'sources': {
        'ebay_de': {
          'configured': true,
          'mode': 'official_api',
          'environment': 'production',
          'data_kind': 'active_marketplace_listings',
        },
      },
    });

    expect(status.isSandbox('ebay_de'), isFalse);
    expect(status.isLive('ebay_de'), isTrue);
  });

  test('automatic valuation filters out non-live listings', () {
    final app = readLibDartSource();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 0.14.2+25'));
    expect(app, contains('e.live && roles.contains(e.role)'));
    expect(app, contains('e.live && e.sourceId == id'));
    expect(app, contains('status.isSandbox(source.id)'));
    expect(app, contains('eBay Sandbox verbunden'));
  });
}
