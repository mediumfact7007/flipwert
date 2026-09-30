import 'dart:convert';

import 'package:http/http.dart' as http;

import 'source_registry.dart';

class SourceRuntimeStatus {
  final bool configured;
  final String mode;
  final String estimate;
  final String environment;
  final String dataKind;
  final String rightsGate;
  final String activationGate;
  final String readiness;
  final int approvedProviderCount;

  const SourceRuntimeStatus({
    required this.configured,
    required this.mode,
    this.estimate = '',
    this.environment = '',
    this.dataKind = '',
    this.rightsGate = '',
    this.activationGate = '',
    this.readiness = '',
    this.approvedProviderCount = 0,
  });

  bool get isSandbox => environment.toLowerCase() == 'sandbox';
  bool get isProduction => environment.toLowerCase() == 'production';

  factory SourceRuntimeStatus.fromJson(Map<String, dynamic> json) =>
      SourceRuntimeStatus(
        configured: json['configured'] == true,
        mode: json['mode']?.toString() ?? '',
        estimate: json['estimate']?.toString() ?? '',
        environment: json['environment']?.toString() ?? '',
        dataKind: json['data_kind']?.toString() ?? '',
        rightsGate: json['rights_gate']?.toString() ?? '',
        activationGate: json['activation_gate']?.toString() ?? '',
        readiness: json['readiness']?.toString() ?? '',
        approvedProviderCount: int.tryParse(json['approved_provider_count']?.toString() ?? '') ?? 0,
      );
}

class MarketBackendStatus {
  final bool reachable;
  final Map<String, SourceRuntimeStatus> sources;
  final String error;

  const MarketBackendStatus({
    required this.reachable,
    required this.sources,
    this.error = '',
  });

  const MarketBackendStatus.offline([String message = ''])
      : reachable = false,
        sources = const <String, SourceRuntimeStatus>{},
        error = message;

  bool isSandbox(String sourceId) {
    final source = sources[sourceId];
    return reachable && source != null && source.configured && source.isSandbox;
  }

  bool isLive(String sourceId) {
    final source = sources[sourceId];
    if (!reachable || source == null || !source.configured) return false;
    if (sourceId == 'ebay_de' && source.isSandbox) return false;
    if (sourceId == 'buyback') {
      return source.rightsGate == 'approved' &&
          source.activationGate == 'validated' &&
          source.readiness == 'ready' &&
          source.approvedProviderCount > 0;
    }
    return true;
  }

  SourceRuntimeStatus? get buyback => sources['buyback'];

  bool get isBuybackRightsApproved =>
      reachable && buyback?.rightsGate == 'approved';

  bool get isBuybackValidated =>
      isBuybackRightsApproved &&
      buyback?.activationGate == 'validated' &&
      buyback?.readiness == 'ready' &&
      (buyback?.approvedProviderCount ?? 0) > 0;

  factory MarketBackendStatus.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'];
    final parsed = <String, SourceRuntimeStatus>{};
    if (rawSources is Map) {
      for (final entry in rawSources.entries) {
        final value = entry.value;
        if (value is Map) {
          parsed[entry.key.toString()] = SourceRuntimeStatus.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      }
    }
    return MarketBackendStatus(reachable: true, sources: parsed);
  }
}

class MarketStatusClient {
  static Uri? endpointFor(List<PriceSource> sources) {
    for (final source in sources) {
      if (!source.builtIn || !source.canFetchInApp) continue;
      final adapter = source.adapterUrl('flipwert-status');
      final uri = adapter == null ? null : Uri.tryParse(adapter);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) continue;
      return Uri(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: '/v1/status',
      );
    }
    return null;
  }

  static Future<MarketBackendStatus> fetch(List<PriceSource> sources) async {
    final endpoint = endpointFor(sources);
    if (endpoint == null) {
      return const MarketBackendStatus.offline('no_backend');
    }
    try {
      final response = await http
          .get(endpoint)
          .timeout(const Duration(seconds: 6));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return MarketBackendStatus.offline('http_${response.statusCode}');
      }
      if (response.bodyBytes.length > 256 * 1024) {
        return const MarketBackendStatus.offline('response_too_large');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const MarketBackendStatus.offline('invalid_response');
      }
      return MarketBackendStatus.fromJson(decoded);
    } catch (_) {
      return const MarketBackendStatus.offline('unreachable');
    }
  }
}
