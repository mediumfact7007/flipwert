import 'dart:convert';

import 'package:flipwert/pro_entitlement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('accepts only a matching server-verified entitlement', () async {
    final verifier = ProEntitlementVerifier(
      endpoint: Uri.parse('https://example.com/verify'),
      now: () => DateTime.parse('2026-10-13T12:00:00Z'),
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

    final result = await verifier.verify(
      productId: 'flipwert_pro_monthly',
      purchaseToken: 'purchase-token-value-123456',
    );
    expect(result.status, ProEntitlementStatus.verified);
    expect(result.productId, 'flipwert_pro_monthly');
    expect(result.expiresAt, DateTime.parse('2026-11-13T12:00:00Z'));
  });

  test('fails closed on errors and mismatched products', () async {
    final mismatch = ProEntitlementVerifier(
      endpoint: Uri.parse('https://example.com/verify'),
      now: () => DateTime.parse('2026-10-13T12:00:00Z'),
      client: MockClient((_) async => http.Response(jsonEncode({
        'verified': true,
        'product_id': 'flipwert_pro_yearly',
        'expires_at': '2026-11-13T12:00:00Z',
      }), 200)),
    );
    expect((await mismatch.verify(
      productId: 'flipwert_pro_monthly',
      purchaseToken: 'purchase-token-value-123456',
    )).status, ProEntitlementStatus.rejected);

    final failure = ProEntitlementVerifier(
      endpoint: Uri.parse('https://example.com/verify'),
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    expect((await failure.verify(
      productId: 'flipwert_pro_monthly',
      purchaseToken: 'purchase-token-value-123456',
    )).status, ProEntitlementStatus.unavailable);
  });

  test('fails closed when verified entitlement is expired or lacks expiry',
      () async {
    final now = DateTime.parse('2026-10-13T12:00:00Z');
    for (final expiresAt in [null, 'invalid', '2026-10-13T11:59:59Z']) {
      final verifier = ProEntitlementVerifier(
        endpoint: Uri.parse('https://example.com/verify'),
        now: () => now,
        client: MockClient((_) async => http.Response(jsonEncode({
          'verified': true,
          'product_id': 'flipwert_pro_monthly',
          if (expiresAt != null) 'expires_at': expiresAt,
        }), 200)),
      );
      expect((await verifier.verify(
        productId: 'flipwert_pro_monthly',
        purchaseToken: 'purchase-token-value-123456',
      )).status, ProEntitlementStatus.rejected);
    }
  });

  test('distinguishes temporary verification failures from rejections',
      () async {
    for (final status in [429, 500, 503]) {
      final verifier = ProEntitlementVerifier(
        endpoint: Uri.parse('https://example.com/verify'),
        client: MockClient((_) async => http.Response('{}', status)),
      );
      expect((await verifier.verify(
        productId: 'flipwert_pro_monthly',
        purchaseToken: 'purchase-token-value-123456',
      )).status, ProEntitlementStatus.unavailable);
    }
  });
}
