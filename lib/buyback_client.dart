import 'dart:convert';

import 'package:http/http.dart' as http;

import 'buyback.dart';
import 'source_registry.dart';

// Shared/copied listing titles can contain invisible Unicode separators,
// bidirectional formatting marks, or ASCII/C1 control characters that make an
// otherwise exact provider search miss. Treat them as boundaries: removing a
// control outright can join adjacent title words and silently reduce provider
// match quality.
String normalizeBuybackQuery(String query) => query
    .replaceAll(RegExp(r'[\u0000-\u001F\u007F-\u009F]'), ' ')
    .replaceAll(RegExp(r'[\u200B-\u200D\u2060\uFEFF]'), ' ')
    .replaceAll(RegExp(r'[\u202A-\u202E\u2066-\u2069]'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

/// Keeps long marketplace titles useful for provider search instead of
/// dropping the whole buyback comparison. Prefer a word boundary so copied
/// listing suffixes (shipping, condition notes, seller text) are discarded
/// before the identifying product terms at the beginning of the title.
String limitBuybackQuery(String query, {int maxLength = 180}) {
  if (maxLength <= 0 || query.isEmpty) return '';
  if (query.length <= maxLength) return query;
  final prefix = query.substring(0, maxLength);
  final boundary = prefix.lastIndexOf(' ');
  return (boundary >= maxLength ~/ 2 ? prefix.substring(0, boundary) : prefix).trim();
}

/// Keeps one trustworthy quote per provider so a noisy adapter cannot make one
/// provider look like multiple independent market signals.
///
/// Invalid or low-confidence quotes are discarded here as a second trust
/// boundary, so future callers cannot accidentally bypass [BuybackOffer]'s
/// comparison rules. When [now] is supplied, stale or implausibly future-dated
/// quotes are rejected here as well. [maxAge] lets callers keep one explicit
/// freshness policy through filtering and provider deduplication.
List<BuybackOffer> distinctBuybackOffers(
  Iterable<BuybackOffer> offers, {
  DateTime? now,
  Duration maxAge = const Duration(hours: 24),
}) {
  final checkedNow = now?.toUtc();
  final byProvider = <String, BuybackOffer>{};
  for (final offer in offers) {
    if (!offer.isEligibleForComparison) continue;
    if (checkedNow != null && !offer.isFreshAt(checkedNow, maxAge: maxAge)) continue;
    final key = offer.providerId.trim().toLowerCase();
    if (key.isEmpty) continue;
    final current = byProvider[key];
    if (current == null || _isBetterProviderQuote(offer, current)) {
      byProvider[key] = offer;
    }
  }
  final result = byProvider.values.toList()..sort(_compareProviderQuotes);
  return List.unmodifiable(result);
}

bool _isBetterProviderQuote(BuybackOffer candidate, BuybackOffer current) =>
    _compareProviderQuotes(candidate, current) < 0;

int _compareProviderQuotes(BuybackOffer a, BuybackOffer b) {
  final confidence = b.matchConfidence.compareTo(a.matchConfidence);
  if (confidence != 0) return confidence;
  final freshness = b.checkedAt.toUtc().compareTo(a.checkedAt.toUtc());
  if (freshness != 0) return freshness;
  final price = b.price.compareTo(a.price);
  if (price != 0) return price;
  final providerName = a.providerName.trim().toLowerCase().compareTo(b.providerName.trim().toLowerCase());
  if (providerName != 0) return providerName;
  return a.providerId.trim().toLowerCase().compareTo(b.providerId.trim().toLowerCase());
}

/// Result metadata keeps an unavailable partner separate from an enabled
/// source that simply has no matching quote. Empty prices are never estimated.
class BuybackSearchResult {
  const BuybackSearchResult({
    required this.offers,
    required this.configured,
    required this.live,
    required this.unavailable,
  });

  final List<BuybackOffer> offers;
  final bool configured;
  final bool live;
  final bool unavailable;
}

/// Isolated client for Flipwert's buyback endpoint.
class BuybackClient {
  const BuybackClient({
    this.backendBase = SourceRegistry.defaultBackend,
    this.client,
  });

  final String backendBase;
  final http.Client? client;

  Future<List<BuybackOffer>> search(
    String query, {
    required BuybackCondition condition,
    DateTime? now,
    Duration maxAge = const Duration(hours: 24),
  }) async => (await searchDetailed(
    query,
    condition: condition,
    now: now,
    maxAge: maxAge,
  )).offers;

  Future<BuybackSearchResult> searchDetailed(
    String query, {
    required BuybackCondition condition,
    DateTime? now,
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final q = limitBuybackQuery(normalizeBuybackQuery(query));
    if (q.isEmpty || maxAge.isNegative) {
      return const BuybackSearchResult(offers: [], configured: false, live: false, unavailable: false);
    }

    final base = backendBase.trim().replaceAll(RegExp(r'/+$'), '');
    final baseUri = Uri.tryParse(base);
    if (baseUri == null || baseUri.scheme != 'https' || baseUri.host.isEmpty) {
      return const BuybackSearchResult(offers: [], configured: false, live: false, unavailable: true);
    }

    final endpoint = Uri.parse('$base/v1/buyback/search').replace(
      queryParameters: {'q': q, 'condition': condition.wireValue},
    );

    try {
      final response = await (client?.get(endpoint) ?? http.get(endpoint)).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const BuybackSearchResult(offers: [], configured: false, live: false, unavailable: true);
      }
      if (response.bodyBytes.length > 512 * 1024) {
        return const BuybackSearchResult(offers: [], configured: false, live: false, unavailable: true);
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        return const BuybackSearchResult(offers: [], configured: false, live: false, unavailable: true);
      }
      final configured = decoded['configured'] == true;
      final unavailable = decoded['unavailable'] == true;
      // Fail closed at the app boundary too: an unconfigured backend must not
      // be able to surface provider rows as comparable quotes, even if a stale
      // or malformed response happens to contain items.
      if (!configured) {
        return BuybackSearchResult(
          offers: const [],
          configured: false,
          live: false,
          unavailable: unavailable,
        );
      }
      final rawItems = decoded['items'];
      if (rawItems is! List) {
        return BuybackSearchResult(offers: const [], configured: configured, live: false, unavailable: true);
      }

      final checkedNow = (now ?? DateTime.now()).toUtc();
      final offers = <BuybackOffer>[];
      for (final item in rawItems.take(50)) {
        if (item is! Map<String, dynamic>) continue;
        try {
          final offer = BuybackOffer.fromJson(item);
          if (offer.condition != condition || !offer.isEligibleForComparison) continue;
          if (!offer.isFreshAt(checkedNow, maxAge: maxAge)) continue;
          offers.add(offer);
        } on FormatException {
          // Invalid provider payloads are ignored rather than shown as trusted.
        } on TypeError {
          // Wrongly typed provider payloads are treated as unavailable data.
        }
      }
      final distinct = distinctBuybackOffers(
        offers,
        now: checkedNow,
        maxAge: maxAge,
      );
      return BuybackSearchResult(
        offers: distinct,
        configured: configured,
        live: configured && decoded['live'] == true && distinct.isNotEmpty,
        unavailable: unavailable,
      );
    } catch (_) {
      // Buyback is optional: network/provider failure must never break the
      // primary deal check or the Kleinanzeigen share flow.
      return const BuybackSearchResult(offers: [], configured: false, live: false, unavailable: true);
    }
  }
}
