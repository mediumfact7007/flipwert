import 'dart:convert';

import 'package:http/http.dart' as http;

import 'source_registry.dart';

enum ProEntitlementStatus { verified, rejected, unavailable }

class ProEntitlementResult {
  final ProEntitlementStatus status;
  final String? productId;
  final DateTime? expiresAt;

  const ProEntitlementResult._(this.status, {this.productId, this.expiresAt});

  const ProEntitlementResult.verified({
    required String productId,
    required DateTime expiresAt,
  }) : this._(
          ProEntitlementStatus.verified,
          productId: productId,
          expiresAt: expiresAt,
        );

  const ProEntitlementResult.rejected()
      : this._(ProEntitlementStatus.rejected);

  const ProEntitlementResult.unavailable()
      : this._(ProEntitlementStatus.unavailable);

  bool get isVerified => status == ProEntitlementStatus.verified;
}

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

  Future<ProEntitlementResult> verify({
    required String productId,
    required String purchaseToken,
  }) async {
    final product = productId.trim();
    final token = purchaseToken.trim();
    if (product.isEmpty || token.length < 20 || token.length > 4096) {
      return const ProEntitlementResult.rejected();
    }
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
      if (response.statusCode != 200) {
        return response.statusCode == 429 || response.statusCode >= 500
            ? const ProEntitlementResult.unavailable()
            : const ProEntitlementResult.rejected();
      }
      if (response.body.length > 16384) {
        return const ProEntitlementResult.unavailable();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const ProEntitlementResult.unavailable();
      }
      final expiresAt = DateTime.tryParse(
        decoded['expires_at']?.toString() ?? '',
      );
      if (decoded['verified'] != true ||
          decoded['product_id'] != product ||
          expiresAt == null ||
          !expiresAt.toUtc().isAfter(_now().toUtc())) {
        return const ProEntitlementResult.rejected();
      }
      return ProEntitlementResult.verified(
        productId: product,
        expiresAt: expiresAt.toUtc(),
      );
    } catch (_) {
      return const ProEntitlementResult.unavailable();
    }
  }
}
