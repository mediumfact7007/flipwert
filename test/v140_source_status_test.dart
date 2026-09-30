import 'package:flutter_test/flutter_test.dart';
import 'package:flipwert/source_registry.dart';
import 'package:flipwert/source_status.dart';

void main() {
  test('parses configured and browser-only source status', () {
    final status = MarketBackendStatus.fromJson({
      'sources': {
        'ebay_de': {
          'configured': true,
          'mode': 'official_api',
          'estimate': 'used_fixed_price_active_listings',
        },
        'amazon_de': {
          'configured': false,
          'mode': 'keepa',
          'estimate': 'retail_reference',
        },
        'kleinanzeigen': {
          'configured': false,
          'mode': 'official_search_link',
        },
      },
    });

    expect(status.reachable, isTrue);
    expect(status.isLive('ebay_de'), isTrue);
    expect(status.isLive('amazon_de'), isFalse);
    expect(status.sources['kleinanzeigen']?.mode, 'official_search_link');
  });

  test('buyback is live only after rights, validation and providers are ready', () {
    final ready = MarketBackendStatus.fromJson({
      'sources': {
        'buyback': {
          'configured': true,
          'mode': 'approved_partner_adapter',
          'rights_gate': 'approved',
          'activation_gate': 'validated',
          'readiness': 'ready',
          'approved_provider_count': 2,
        },
      },
    });
    expect(ready.isLive('buyback'), isTrue);
    expect(ready.isBuybackRightsApproved, isTrue);
    expect(ready.isBuybackValidated, isTrue);
    expect(ready.buyback?.approvedProviderCount, 2);

    final stale = MarketBackendStatus.fromJson({
      'sources': {
        'buyback': {
          'configured': true,
          'mode': 'approved_partner_adapter',
          'rights_gate': 'approved',
          'activation_gate': 'missing_or_stale',
          'readiness': 'missing_or_stale_validation',
          'approved_provider_count': 2,
        },
      },
    });
    expect(stale.isLive('buyback'), isFalse);
    expect(stale.isBuybackRightsApproved, isTrue);
    expect(stale.isBuybackValidated, isFalse);
  });

  test('derives status endpoint from the configured Flipwert adapter', () {
    final sources = SourceRegistry.builtIns();
    final endpoint = MarketStatusClient.endpointFor(sources);

    expect(endpoint, isNotNull);
    expect(endpoint!.scheme, 'https');
    expect(endpoint.host, 'flipwert-api-production-ec00.up.railway.app');
    expect(endpoint.path, '/v1/status');
    expect(endpoint.query, isEmpty);
  });
}
