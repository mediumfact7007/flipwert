import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SourceListing {
  static const liveFreshness = Duration(minutes: 5);

  final String sourceId;
  final String sourceName;
  final String role;
  final String title;
  final double price;
  final double shipping;
  final String url;
  final String condition;
  final bool live;
  final DateTime? checkedAt;

  const SourceListing({
    required this.sourceId,
    required this.sourceName,
    required this.role,
    required this.title,
    required this.price,
    required this.shipping,
    required this.url,
    required this.condition,
    required this.live,
    this.checkedAt,
  });

  double get total => price + shipping;

  factory SourceListing.fromJson(
    Map<String, dynamic> json,
    PriceSource source, {
    DateTime? now,
  }) {
    final current = (now ?? DateTime.now()).toUtc();
    final checkedAt =
        DateTime.tryParse(json['checked_at']?.toString() ?? '')?.toUtc();
    final age = checkedAt == null ? null : current.difference(checkedAt);
    final fresh = age != null && !age.isNegative && age <= liveFreshness;
    return SourceListing(
      sourceId: source.id,
      sourceName: source.name,
      // Third-party manifests must never be able to promote themselves into
      // Flipwert's automatic BUY/SKIP calculation. Unverified sources remain
      // visible as references until Flipwert explicitly trusts them.
      role: source.trustedForDecision ? source.role : 'reference',
      title: json['title']?.toString().trim().isNotEmpty == true
          ? json['title'].toString().trim()
          : 'Listing',
      price: _toDouble(json['price']),
      shipping: _toDouble(json['shipping']),
      url: json['url']?.toString() ?? '',
      condition: json['condition']?.toString() ?? '',
      // LIVE is an explicit trust boundary. Missing, malformed or stringified
      // values must never promote an adapter result into automatic valuation.
      live: json['live'] is bool && (json['live'] as bool) && fresh,
      checkedAt: checkedAt,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.isFinite ? value.toDouble() : 0;
    var raw = value?.toString().trim() ?? '';
    raw = raw
        .replaceAll('€', '')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (raw.isEmpty) return 0;
    final comma = raw.lastIndexOf(',');
    final dot = raw.lastIndexOf('.');
    if (comma >= 0 && dot >= 0) {
      raw = comma > dot
          ? raw.replaceAll('.', '').replaceAll(',', '.')
          : raw.replaceAll(',', '');
    } else if (comma >= 0) {
      final decimals = raw.length - comma - 1;
      raw = decimals == 3 && comma > 0
          ? raw.replaceAll(',', '')
          : raw.replaceAll(',', '.');
    } else if (dot >= 0) {
      final decimals = raw.length - dot - 1;
      if (decimals == 3 && dot > 0) raw = raw.replaceAll('.', '');
    }
    final parsed = double.tryParse(raw);
    return parsed == null || !parsed.isFinite ? 0 : parsed;
  }
}

class PriceSource {
  final String id;
  final String name;
  final String subtitle;
  final String searchUrlTemplate;
  final String? adapterUrlTemplate;
  final String role;
  final bool enabled;
  final bool builtIn;
  final bool recommended;
  final bool trustedForDecision;
  final String colorHex;

  const PriceSource({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.searchUrlTemplate,
    this.adapterUrlTemplate,
    this.role = 'reference',
    this.enabled = true,
    this.builtIn = true,
    this.recommended = false,
    this.trustedForDecision = false,
    this.colorHex = '5146E5',
  });

  bool get canFetchInApp => (adapterUrlTemplate ?? '').trim().isNotEmpty;
  bool get isResaleMarket => role == 'resale' || role == 'local';
  bool get isRetailReference => role == 'retail' || role == 'refurb';
  bool get isBuyback => role == 'buyback';

  PriceSource copyWith({bool? enabled, String? adapterUrlTemplate}) {
    return PriceSource(
      id: id,
      name: name,
      subtitle: subtitle,
      searchUrlTemplate: searchUrlTemplate,
      adapterUrlTemplate: adapterUrlTemplate ?? this.adapterUrlTemplate,
      role: role,
      enabled: enabled ?? this.enabled,
      builtIn: builtIn,
      recommended: recommended,
      trustedForDecision: trustedForDecision,
      colorHex: colorHex,
    );
  }

  String searchUrl(String query) =>
      searchUrlTemplate.replaceAll('{query}', Uri.encodeQueryComponent(query));

  String? adapterUrl(String query) {
    final value = adapterUrlTemplate;
    if (value == null || value.trim().isEmpty) return null;
    return value.replaceAll('{query}', Uri.encodeQueryComponent(query));
  }

  Map<String, dynamic> toJson() => {
        'version': 2,
        'id': id,
        'name': name,
        'subtitle': subtitle,
        'search_url': searchUrlTemplate,
        'adapter_url': adapterUrlTemplate,
        'role': role,
        'enabled': enabled,
        'built_in': builtIn,
        'recommended': recommended,
        'color': colorHex,
      };

  factory PriceSource.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString().trim() ?? '';
    final search = json['search_url']?.toString().trim() ?? '';
    if (name.isEmpty || search.isEmpty || !search.contains('{query}')) {
      throw const FormatException('Source manifest needs name and search_url with {query}.');
    }
    _validateSearchTemplate(search);

    final adapterRaw = json['adapter_url']?.toString().trim();
    if (adapterRaw != null && adapterRaw.isNotEmpty) {
      if (!adapterRaw.contains('{query}')) {
        throw const FormatException('adapter_url needs {query}.');
      }
      _validateAdapterTemplate(adapterRaw);
    }

    final rawId = json['id']?.toString().trim();
    final generated = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final requestedRole = json['role']?.toString() ?? 'reference';
    final safeRole = const {'reference', 'resale', 'local', 'retail', 'refurb', 'buyback'}
            .contains(requestedRole)
        ? requestedRole
        : 'reference';

    return PriceSource(
      id: (rawId == null || rawId.isEmpty) ? generated : rawId,
      name: name,
      subtitle: json['subtitle']?.toString() ?? 'Eigene Quelle',
      searchUrlTemplate: search,
      adapterUrlTemplate: adapterRaw?.isEmpty == true ? null : adapterRaw,
      role: safeRole,
      enabled: json['enabled'] as bool? ?? true,
      builtIn: false,
      recommended: false,
      // Never trust this flag from downloaded JSON.
      trustedForDecision: false,
      colorHex: _safeColor(json['color']?.toString()),
    );
  }

  static String _safeColor(String? raw) {
    final value = (raw ?? '').replaceAll('#', '').trim().toUpperCase();
    return RegExp(r'^[0-9A-F]{6}$').hasMatch(value) ? value : '5146E5';
  }

  static void _validateSearchTemplate(String template) {
    final uri = Uri.tryParse(template.replaceAll('{query}', 'flipwert'));
    if (uri == null || uri.host.isEmpty || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('search_url must be an HTTP(S) URL.');
    }
  }

  static void _validateAdapterTemplate(String template) {
    final uri = Uri.tryParse(template.replaceAll('{query}', 'flipwert'));
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || _isPrivateHost(uri.host)) {
      throw const FormatException('adapter_url must use public HTTPS.');
    }
  }

  static bool _isPrivateHost(String rawHost) {
    final host = rawHost.toLowerCase().replaceAll('[', '').replaceAll(']', '');
    if (host == 'localhost' || host == '::1' || host.endsWith('.local')) return true;
    if (host.startsWith('127.') || host.startsWith('10.') || host.startsWith('192.168.') || host.startsWith('169.254.')) {
      return true;
    }
    final match = RegExp(r'^172\.(\d{1,2})\.').firstMatch(host);
    if (match != null) {
      final second = int.tryParse(match.group(1) ?? '');
      if (second != null && second >= 16 && second <= 31) return true;
    }
    return false;
  }
}

class SourceRegistry {
  static const _customKey = 'custom_sources_v05';
  static const _enabledKey = 'enabled_sources_v05';
  static const defaultBackend = 'https://flipwert-api-production-ec00.up.railway.app';

  static String _backendAdapter(String backendBase, String source) {
    final manual = backendBase.trim().replaceAll(RegExp(r'/+$'), '');
    final b = manual.isEmpty ? defaultBackend : manual;
    return '$b/v1/market/search?source=$source&q={query}';
  }

  static List<PriceSource> builtIns({String backendBase = ''}) {
    return [
      PriceSource(
        id: 'ebay_de',
        name: 'eBay DE',
        subtitle: 'Wiederverkauf · gebrauchte Festpreis-Angebote',
        searchUrlTemplate: 'https://www.ebay.de/sch/i.html?_nkw={query}',
        adapterUrlTemplate: _backendAdapter(backendBase, 'ebay_de'),
        role: 'resale',
        recommended: true,
        trustedForDecision: true,
        colorHex: '3665F3',
      ),
      const PriceSource(
        id: 'kleinanzeigen',
        name: 'Kleinanzeigen',
        subtitle: 'Lokaler Wiederverkauf',
        searchUrlTemplate: 'https://www.kleinanzeigen.de/s-{query}/k0',
        role: 'local',
        recommended: true,
        trustedForDecision: true,
        colorHex: '00A98F',
      ),
      const PriceSource(
        id: 'vinted',
        name: 'Vinted',
        subtitle: 'Secondhand · Mode, Elektronik & mehr',
        searchUrlTemplate: 'https://www.vinted.de/catalog?search_text={query}',
        role: 'local',
        recommended: true,
        colorHex: '007782',
      ),
      PriceSource(
        id: 'amazon_de',
        name: 'Amazon DE',
        subtitle: 'Neupreis-Referenz · Keepa',
        searchUrlTemplate: 'https://www.amazon.de/s?k={query}',
        adapterUrlTemplate: _backendAdapter(backendBase, 'amazon_de'),
        role: 'retail',
        recommended: true,
        trustedForDecision: true,
        colorHex: 'FF9900',
      ),
      const PriceSource(
        id: 'mediamarkt',
        name: 'MediaMarkt',
        subtitle: 'Neupreis-Referenz',
        searchUrlTemplate: 'https://www.mediamarkt.de/de/search.html?query={query}',
        role: 'retail',
        trustedForDecision: true,
        colorHex: 'DF0000',
      ),
      const PriceSource(
        id: 'saturn',
        name: 'SATURN',
        subtitle: 'Neupreis-Referenz',
        searchUrlTemplate: 'https://www.saturn.de/de/search.html?query={query}',
        role: 'retail',
        trustedForDecision: true,
        colorHex: '1454A3',
      ),
      const PriceSource(
        id: 'idealo',
        name: 'idealo',
        subtitle: 'Neupreis-Vergleich',
        searchUrlTemplate: 'https://www.idealo.de/preisvergleich/MainSearchProductCategory.html?q={query}',
        role: 'retail',
        recommended: true,
        trustedForDecision: true,
        colorHex: 'FF6600',
      ),
      const PriceSource(
        id: 'geizhals',
        name: 'Geizhals',
        subtitle: 'Neupreis- & Angebotsvergleich',
        searchUrlTemplate: 'https://geizhals.de/?fs={query}&hloc=de',
        role: 'retail',
        recommended: true,
        colorHex: '0096D6',
      ),
      const PriceSource(
        id: 'rebuy',
        name: 'rebuy',
        subtitle: 'Sofort-Ankauf · externe Preisprüfung',
        searchUrlTemplate: 'https://www.rebuy.de/verkaufen',
        role: 'buyback',
        colorHex: '1B9E77',
      ),
      const PriceSource(
        id: 'backmarket',
        name: 'Back Market',
        subtitle: 'Refurbished-Referenz',
        searchUrlTemplate: 'https://www.backmarket.de/de-de/search?q={query}',
        role: 'refurb',
        trustedForDecision: true,
        colorHex: '111111',
      ),
    ];
  }

  static Uri? sharedListingUrl(String raw) {
    final matches = RegExp(r'https?://[^\s]+', caseSensitive: false).allMatches(raw);
    for (final match in matches) {
      var value = match.group(0) ?? '';
      value = value.replaceAll(RegExp(r'[\]\[),.;:]+$'), '');
      final uri = Uri.tryParse(value);
      if (uri == null || uri.scheme != 'https') continue;
      final host = uri.host.toLowerCase();
      if (host != 'kleinanzeigen.de' && host != 'www.kleinanzeigen.de') continue;
      if (!uri.path.contains('/s-anzeige/')) continue;
      return uri;
    }
    return null;
  }

  static Future<List<PriceSource>> load({String backendBase = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getStringList(_enabledKey)?.toSet();

    final built = builtIns(backendBase: backendBase)
        .map((s) => s.copyWith(enabled: enabled == null ? s.enabled : enabled.contains(s.id)))
        .toList();

    final custom = <PriceSource>[];
    for (final raw in prefs.getStringList(_customKey) ?? <String>[]) {
      try {
        final source = PriceSource.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        custom.add(source.copyWith(enabled: enabled == null ? source.enabled : enabled.contains(source.id)));
      } catch (_) {}
    }
    return [...built, ...custom];
  }

  static Future<void> save(List<PriceSource> sources) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _enabledKey,
      sources.where((s) => s.enabled).map((s) => s.id).toList(),
    );
    await prefs.setStringList(
      _customKey,
      sources.where((s) => !s.builtIn).map((s) => jsonEncode(s.toJson())).toList(),
    );
  }

  static Future<PriceSource> importManifest(String manifestUrl) async {
    final uri = Uri.tryParse(manifestUrl.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || PriceSource._isPrivateHost(uri.host)) {
      throw const FormatException('Partner-Manifeste müssen eine öffentliche HTTPS-Adresse verwenden.');
    }

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Manifest konnte nicht geladen werden (${response.statusCode}).');
    }
    if (response.bodyBytes.length > 256 * 1024) {
      throw const FormatException('Partner-Manifest ist zu groß.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Ungültiges Partner-Manifest.');
    }
    return PriceSource.fromJson(decoded);
  }

  static Future<List<SourceListing>> fetch(PriceSource source, String query) async {
    final q = query.trim();
    if (q.isEmpty || q.length > 180) return [];
    final target = source.adapterUrl(q);
    if (target == null) return [];
    final uri = Uri.tryParse(target);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return [];

    // Imported adapters are already checked at import time. Recheck here too so
    // corrupted/local preferences cannot silently turn into background requests.
    if (!source.builtIn && PriceSource._isPrivateHost(uri.host)) return [];

    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) return [];
    if (response.bodyBytes.length > 2 * 1024 * 1024) return [];

    final decoded = jsonDecode(response.body);
    final items = decoded is Map<String, dynamic>
        ? (decoded['items'] as List<dynamic>? ?? const [])
        : decoded is List<dynamic>
            ? decoded
            : const <dynamic>[];

    return items
        .take(100)
        .whereType<Map<String, dynamic>>()
        .map((e) => SourceListing.fromJson(e, source))
        .where((e) => e.price > 0 && e.price.isFinite && e.shipping.isFinite && e.shipping >= 0)
        .toList();
  }
}
