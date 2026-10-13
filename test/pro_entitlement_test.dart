import 'dart:convert';

import 'package:flipwert/pro_entitlement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('accepts only a matching server-verified entitlement', () async {
    final verifier = ProEntitlementVerifier(
      endpoint: Uri.parse('https://example.com/verify'),
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['purchase_token'], 'purchase-token-value-123456');
        return http.Response(jsonEncode({
          'verified': true,
          'product_id': 'flipwert_pro_monthly',
          'expires_at': '2026-11-13T12:00:00Z',
        }), 200);
      }),
    );

    expect(await verifier.verify(
      productId: 'flipwert_pro_monthly',
      purchaseToken: 'purchase-token-value-123456',
    ), isTrue);
  });

  test('fails closed on errors and mismatched products', () async {
    final mismatch = ProEntitlementVerifier(
      endpoint: Uri.parse('https://example.com/verify'),
      client: MockClient((_) async => http.Response(jsonEncode({
        'verified': true,
        'product_id': 'flipwert_pro_yearly',
      }), 200)),
    );
    expect(await mismatch.verify(
      productId: 'flipwert_pro_monthly',
      purchaseToken: 'purchase-token-value-123456',
    ), isFalse);

    final failure = ProEntitlementVerifier(
      endpoint: Uri.parse('https://example.com/verify'),
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    expect(await failure.verify(
      productId: 'flipwert_pro_monthly',
      purchaseToken: 'purchase-token-value-123456',
    ), isFalse);
  });
}
