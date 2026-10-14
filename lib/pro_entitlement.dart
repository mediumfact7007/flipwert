import 'dart:convert';

import 'package:http/http.dart' as http;

import 'source_registry.dart';

class ProEntitlementVerifier {
  final Uri endpoint;
  final http.Client _client;
  final DateTime Function() _now;

  ProEntitlementVerifier({
    Uri? endpoint,
    http.Client? client,
    DateTime Function()? now,
  })
      : endpoint = endpoint ??
            Uri.parse('${SourceRegistry.defaultBackend}/v1/entitlements/google-play'),
        _client = client ?? http.Client(),
        _now = now ?? DateTime.now;

  Future<bool> verify({
    required String productId,
    required String purchaseToken,
  }) async {
    final product = productId.trim();
    final token = purchaseToken.trim();
    if (product.isEmpty || token.length < 20 || token.length > 4096) return false;
    try {
      final response = await _client
          .post(
            endpoint,
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'product_id': product,
              'purchase_token': token,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200 || response.body.length > 16384) {
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return false;
      final expiresAt = DateTime.tryParse(
        decoded['expires_at']?.toString() ?? '',
      );
      return decoded['verified'] == true &&
          decoded['product_id'] == product &&
          expiresAt != null &&
          expiresAt.toUtc().isAfter(_now().toUtc());
    } catch (_) {
      return false;
    }
  }
}
