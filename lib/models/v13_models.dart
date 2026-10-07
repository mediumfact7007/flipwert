part of '../v13_app.dart';

const _v13Primary = Color(0xFF4E50D8);
const _v13Ink = Color(0xFF20213F);
const _v13Bg = Color(0xFFF6F7FB);

String v13Euro(double value) {
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.005) return '${rounded.toStringAsFixed(0)} €';
  return '${value.toStringAsFixed(2).replaceAll('.', ',')} €';
}

double v13Money(String raw) {
  var value = raw
      .trim()
      .replaceAll('€', '')
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (value.isEmpty) return 0;
  final comma = value.lastIndexOf(',');
  final dot = value.lastIndexOf('.');
  if (comma >= 0 && dot >= 0) {
    value = comma > dot
        ? value.replaceAll('.', '').replaceAll(',', '.')
        : value.replaceAll(',', '');
  } else if (comma >= 0) {
    final decimals = value.length - comma - 1;
    value = decimals == 3 && comma > 0
        ? value.replaceAll(',', '')
        : value.replaceAll(',', '.');
  } else if (dot >= 0) {
    final decimals = value.length - dot - 1;
    if (decimals == 3 && dot > 0) value = value.replaceAll('.', '');
  }
  final parsed = double.tryParse(value);
  return parsed == null || !parsed.isFinite || parsed < 0 ? 0 : parsed;
}

double? v13ResolveExpectedSale({
  double? manualOverride,
  double? marketEstimate,
  double? snapshotFallback,
}) {
  for (final value in [manualOverride, marketEstimate, snapshotFallback]) {
    if (value != null && value.isFinite && value > 0) return value;
  }
  return null;
}

enum V13InputKind { text, url, ean, asin }

class V13SearchInput {
  final String raw;
  final String query;
  final V13InputKind kind;
  final String? correction;
  final double? detectedPrice;

  const V13SearchInput({required this.raw, required this.query, required this.kind, this.correction, this.detectedPrice});
}

String _slugWords(String raw) => Uri.decodeComponent(raw)
    .replaceAll(RegExp(r'[-_+]+'), ' ')
    .replaceAll(RegExp(r'\b\d{7,}\b'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _commonCorrection(String input) {
  var value = input;
  const replacements = <String, String>{
    'iphnoe': 'iphone',
    'ipohne': 'iphone',
    'appel': 'apple',
    'samsng': 'samsung',
    'samsun': 'samsung',
    'playstaion': 'playstation',
    'playstion': 'playstation',
    'nintedo': 'nintendo',
    'makitta': 'makita',
    'airpod': 'airpods',
  };
  final words = value.split(RegExp(r'\s+'));
  for (var i = 0; i < words.length; i++) {
    final lower = words[i].toLowerCase();
    final replacement = replacements[lower];
    if (replacement != null) {
      final original = words[i];
      words[i] = RegExp(r'^[A-Z]').hasMatch(original)
          ? '${replacement[0].toUpperCase()}${replacement.substring(1)}'
          : replacement;
    }
  }
  return words.join(' ');
}

double? _detectSharedPrice(String raw) {
  final lines = raw.replaceAll('\u00a0', ' ').split(RegExp(r'[\r\n]+'));
  final pattern = RegExp(r'(\d{1,6}(?:[. ]\d{3})*(?:[,.]\d{1,2})?)\s*(?:€|EUR)(?=\s|$|[.,;:])', caseSensitive: false);
  for (final line in lines) {
    final lower = line.toLowerCase();
    final match = pattern.firstMatch(line);
    if (match == null) continue;
    final value = v13Money(match.group(1)!);
    if (value < 2 || value > 100000) continue;
    if (RegExp(r'\b(versand|porto|shipping)\b').hasMatch(lower)) {
      continue;
    }
    return value;
  }
  return null;
}

V13SearchInput normalizeV13Search(String rawInput) {
  final raw = rawInput.trim();
  if (raw.isEmpty) return const V13SearchInput(raw: '', query: '', kind: V13InputKind.text);
  final detectedPrice = _detectSharedPrice(raw);

  final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (RegExp(r'^\d{8,14}$').hasMatch(compact)) {
    return V13SearchInput(raw: raw, detectedPrice: detectedPrice, query: compact, kind: V13InputKind.ean);
  }
  if (RegExp(r'^[A-Z0-9]{10}$', caseSensitive: false).hasMatch(compact) && RegExp(r'[A-Z]', caseSensitive: false).hasMatch(compact)) {
    return V13SearchInput(raw: raw, detectedPrice: detectedPrice, query: compact.toUpperCase(), kind: V13InputKind.asin);
  }

  final urlMatch = RegExp(r'https?://[^\s]+', caseSensitive: false).firstMatch(compact);
  if (urlMatch != null) {
    final before = compact.substring(0, urlMatch.start).trim();
    final cleanBefore = before
        .replaceAll(RegExp(r'\b\d{1,6}(?:[.,]\d{1,2})?\s*(?:€|EUR)(?=\s|$)', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanBefore.length >= 4 && !cleanBefore.toLowerCase().contains('gerade bei')) {
      final corrected = _commonCorrection(cleanBefore);
      return V13SearchInput(
        raw: raw, detectedPrice: detectedPrice,
        query: corrected,
        kind: V13InputKind.url,
        correction: corrected == cleanBefore ? null : corrected,
      );
    }

    final uri = Uri.tryParse(urlMatch.group(0)!);
    if (uri != null) {
      for (final key in ['_nkw', 'q', 'query', 'search_text', 'fs', 'k']) {
        final value = uri.queryParameters[key];
        if (value != null && value.trim().isNotEmpty) {
          final query = _commonCorrection(_slugWords(value));
          return V13SearchInput(raw: raw, detectedPrice: detectedPrice, query: query, kind: V13InputKind.url);
        }
      }
      final path = uri.path;
      final asin = RegExp(r'/(?:dp|gp/product)/([A-Z0-9]{10})(?:/|$)', caseSensitive: false).firstMatch(path);
      if (asin != null) {
        return V13SearchInput(raw: raw, detectedPrice: detectedPrice, query: asin.group(1)!.toUpperCase(), kind: V13InputKind.asin);
      }
      if (uri.host.contains('kleinanzeigen')) {
        final match = RegExp(r'/s-anzeige/([^/]+)').firstMatch(path);
        if (match != null) {
          return V13SearchInput(raw: raw, detectedPrice: detectedPrice, query: _commonCorrection(_slugWords(match.group(1)!)), kind: V13InputKind.url);
        }
      }
      if (uri.host.contains('ebay.')) {
        final segments = uri.pathSegments.where((e) => e.isNotEmpty).toList();
        if (segments.length >= 2 && segments.first != 'itm') {
          final candidate = _slugWords(segments[segments.length - 2]);
          if (candidate.length >= 4) return V13SearchInput(raw: raw, detectedPrice: detectedPrice, query: _commonCorrection(candidate), kind: V13InputKind.url);
        }
      }
      final slug = uri.pathSegments.reversed.firstWhere(
        (e) => e.length >= 5 && !RegExp(r'^\d+$').hasMatch(e),
        orElse: () => '',
      );
      if (slug.isNotEmpty) return V13SearchInput(raw: raw, detectedPrice: detectedPrice, query: _commonCorrection(_slugWords(slug)), kind: V13InputKind.url);
    }
  }

  final corrected = _commonCorrection(compact);
  return V13SearchInput(
    raw: raw, detectedPrice: detectedPrice,
    query: corrected,
    kind: V13InputKind.text,
    correction: corrected == compact ? null : corrected,
  );
}

String v13Category(String raw) {
  final q = raw.toLowerCase();
  if (RegExp(r'(iphone|samsung|galaxy|pixel|smartphone|handy)').hasMatch(q)) return 'Smartphone';
  if (RegExp(r'(macbook|laptop|notebook|thinkpad|surface)').hasMatch(q)) return 'Laptop';
  if (RegExp(r'(playstation|ps5|xbox|switch|konsole)').hasMatch(q)) return 'Konsole';
  if (RegExp(r'(nike|adidas|jordan|yeezy|sneaker|schuh)').hasMatch(q)) return 'Sneaker';
  if (RegExp(r'(kamera|canon|nikon|sony alpha|objektiv|lens)').hasMatch(q)) return 'Kamera';
  if (RegExp(r'(makita|bosch|festool|dewalt|milwaukee|werkzeug)').hasMatch(q)) return 'Werkzeug';
  if (RegExp(r'(airpods|kopfhörer|headphone|speaker|lautsprecher)').hasMatch(q)) return 'Audio';
  if (RegExp(r'(lego|pokemon|karte|sammler|collect)').hasMatch(q)) return 'Sammler';
  if (RegExp(r'(jacke|hose|shirt|kleid|pullover|tasche|gucci|prada|vuitton)').hasMatch(q)) return 'Mode';
  return 'Sonstiges';
}

String v147AgeLabel(DateTime checkedAt, bool english, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(checkedAt);
  if (age.isNegative || age.inMinutes < 2) return english ? 'just now' : 'gerade eben';
  if (age.inMinutes < 60) return english ? '${age.inMinutes} min ago' : 'vor ${age.inMinutes} Min';
  if (age.inHours < 24) return english ? '${age.inHours} h ago' : 'vor ${age.inHours} Std';
  if (age.inDays < 30) return english ? '${age.inDays} d ago' : 'vor ${age.inDays} T';
  final months = (age.inDays / 30).floor();
  return english ? '${months} mo ago' : 'vor ${months} Mon';
}

String _v147SourceUrl(String raw) {
  final match = RegExp(r'https?://[^\s]+', caseSensitive: false).firstMatch(raw);
  return match?.group(0)?.trim() ?? '';
}

List<V13Flip> v148PrioritizeSaved(Iterable<V13Flip> input) {
  final out = input.where((e) => e.isSaved).toList();
  out.sort((a, b) => a.checkedAt.compareTo(b.checkedAt));
  return out;
}

class V13Flip {
  final String id;
  final String name;
  final String category;
  final double buy;
  final double expectedAtBuy;
  final double costs;
  final double buybackSafetyReserve;
  final int sourceCount;
  final String confidence;
  final String status;
  final DateTime createdAt;
  final DateTime checkedAt;
  final DateTime? listedAt;
  final DateTime? soldAt;
  final double actualSell;
  final String soldPlatform;
  final String sourceUrl;
  final double maxBuyAtCheck;
  final double profitAtCheck;
  final double roiAtCheck;
  final int confidenceScore;
  final double buybackPriceAtCheck;
  final String buybackProviderAtCheck;
  final String buybackConditionAtCheck;
  final DateTime? buybackCheckedAt;
  final String buybackQuoteKindAtCheck;
  final double forecastLikelyAtBuy;
  final double forecastLowAtBuy;
  final double forecastHighAtBuy;
  final double ebayReferenceAtBuy;
  final double ebayDiscountAtBuy;

  const V13Flip({
    required this.id,
    required this.name,
    required this.category,
    required this.buy,
    required this.expectedAtBuy,
    required this.costs,
    this.buybackSafetyReserve = 0,
    required this.sourceCount,
    required this.confidence,
    required this.status,
    required this.createdAt,
    DateTime? checkedAt,
    this.listedAt,
    this.soldAt,
    this.actualSell = 0,
    this.soldPlatform = '',
    this.sourceUrl = '',
    this.maxBuyAtCheck = 0,
    this.profitAtCheck = 0,
    this.roiAtCheck = 0,
    this.confidenceScore = 0,
    this.buybackPriceAtCheck = 0,
    this.buybackProviderAtCheck = '',
    this.buybackConditionAtCheck = '',
    this.buybackCheckedAt,
    this.buybackQuoteKindAtCheck = '',
    this.forecastLikelyAtBuy = 0,
    this.forecastLowAtBuy = 0,
    this.forecastHighAtBuy = 0,
    this.ebayReferenceAtBuy = 0,
    this.ebayDiscountAtBuy = 0,
  })  : assert(buybackSafetyReserve >= 0),
        checkedAt = checkedAt ?? createdAt;

  bool get isSaved => status == 'Saved';
  bool get isArchived => status == 'Archived';
  bool get isOpen => status == 'Bought' || status == 'Listed';
  double get realizedProfit => actualSell > 0 ? actualSell - buy - costs : 0;
  double get realizedRoi => buy <= 0 ? 0 : realizedProfit / buy * 100;
  int? get daysToSell => soldAt == null ? null : math.max(0, soldAt!.difference(createdAt).inDays);

  V13Flip copyWith({
    String? status,
    DateTime? createdAt,
    DateTime? checkedAt,
    DateTime? listedAt,
    DateTime? soldAt,
    double? actualSell,
    String? soldPlatform,
  }) =>
      V13Flip(
        id: id,
        name: name,
        category: category,
        buy: buy,
        expectedAtBuy: expectedAtBuy,
        costs: costs,
        buybackSafetyReserve: buybackSafetyReserve,
        sourceCount: sourceCount,
        confidence: confidence,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        checkedAt: checkedAt ?? this.checkedAt,
        listedAt: listedAt ?? this.listedAt,
        soldAt: soldAt ?? this.soldAt,
        actualSell: actualSell ?? this.actualSell,
        soldPlatform: soldPlatform ?? this.soldPlatform,
        sourceUrl: sourceUrl,
        maxBuyAtCheck: maxBuyAtCheck,
        profitAtCheck: profitAtCheck,
        roiAtCheck: roiAtCheck,
        confidenceScore: confidenceScore,
        buybackPriceAtCheck: buybackPriceAtCheck,
        buybackProviderAtCheck: buybackProviderAtCheck,
        buybackConditionAtCheck: buybackConditionAtCheck,
        buybackCheckedAt: buybackCheckedAt,
        buybackQuoteKindAtCheck: buybackQuoteKindAtCheck,
        forecastLikelyAtBuy: forecastLikelyAtBuy,
        forecastLowAtBuy: forecastLowAtBuy,
        forecastHighAtBuy: forecastHighAtBuy,
        ebayReferenceAtBuy: ebayReferenceAtBuy,
        ebayDiscountAtBuy: ebayDiscountAtBuy,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'buy': buy,
        'expectedAtBuy': expectedAtBuy,
        'costs': costs,
        'buybackSafetyReserve': buybackSafetyReserve,
        'sourceCount': sourceCount,
        'confidence': confidence,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'checkedAt': checkedAt.toIso8601String(),
        'listedAt': listedAt?.toIso8601String(),
        'soldAt': soldAt?.toIso8601String(),
        'actualSell': actualSell,
        'soldPlatform': soldPlatform,
        'sourceUrl': sourceUrl,
        'maxBuyAtCheck': maxBuyAtCheck,
        'profitAtCheck': profitAtCheck,
        'roiAtCheck': roiAtCheck,
        'confidenceScore': confidenceScore,
        'buybackPriceAtCheck': buybackPriceAtCheck,
        'buybackProviderAtCheck': buybackProviderAtCheck,
        'buybackConditionAtCheck': buybackConditionAtCheck,
        'buybackCheckedAt': buybackCheckedAt?.toUtc().toIso8601String(),
        'buybackQuoteKindAtCheck': buybackQuoteKindAtCheck,
        'forecastLikelyAtBuy': forecastLikelyAtBuy,
        'forecastLowAtBuy': forecastLowAtBuy,
        'forecastHighAtBuy': forecastHighAtBuy,
        'ebayReferenceAtBuy': ebayReferenceAtBuy,
        'ebayDiscountAtBuy': ebayDiscountAtBuy,
      };

  factory V13Flip.fromJson(Map<String, dynamic> j) {
    final status = j['status']?.toString() ?? 'Bought';
    final legacySell = (j['sell'] as num?)?.toDouble() ?? 0;
    final actual = (j['actualSell'] as num?)?.toDouble() ?? (status == 'Sold' ? legacySell : 0);
    final created = DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now();
    final buybackPrice = (j['buybackPriceAtCheck'] as num?)?.toDouble() ?? 0;
    final storedBuybackReserve =
        (j['buybackSafetyReserve'] as num?)?.toDouble() ?? 0;
    final storedBuybackKind = j['buybackQuoteKindAtCheck']?.toString() ?? '';
    return V13Flip(
      id: j['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: j['name']?.toString() ?? 'Artikel',
      category: j['category']?.toString() ?? v13Category(j['name']?.toString() ?? ''),
      buy: (j['buy'] as num?)?.toDouble() ?? 0,
      expectedAtBuy: (j['expectedAtBuy'] as num?)?.toDouble() ?? legacySell,
      costs: (j['costs'] as num?)?.toDouble() ?? 0,
      buybackSafetyReserve:
          storedBuybackReserve.isFinite && storedBuybackReserve > 0
              ? storedBuybackReserve
              : 0,
      sourceCount: (j['sourceCount'] as num?)?.toInt() ?? 0,
      confidence: j['confidence']?.toString() ?? 'Unbekannt',
      status: status,
      createdAt: created,
      checkedAt: DateTime.tryParse(j['checkedAt']?.toString() ?? '') ?? created,
      listedAt: DateTime.tryParse(j['listedAt']?.toString() ?? ''),
      soldAt: DateTime.tryParse(j['soldAt']?.toString() ?? '') ?? (status == 'Sold' ? created : null),
      actualSell: actual,
      soldPlatform: j['soldPlatform']?.toString() ?? '',
      sourceUrl: j['sourceUrl']?.toString() ?? '',
      maxBuyAtCheck: (j['maxBuyAtCheck'] as num?)?.toDouble() ?? 0,
      profitAtCheck: (j['profitAtCheck'] as num?)?.toDouble() ?? 0,
      roiAtCheck: (j['roiAtCheck'] as num?)?.toDouble() ?? 0,
      confidenceScore: (j['confidenceScore'] as num?)?.toInt() ?? 0,
      buybackPriceAtCheck: buybackPrice,
      buybackProviderAtCheck: j['buybackProviderAtCheck']?.toString() ?? '',
      buybackConditionAtCheck: j['buybackConditionAtCheck']?.toString() ?? '',
      buybackCheckedAt: DateTime.tryParse(j['buybackCheckedAt']?.toString() ?? ''),
      buybackQuoteKindAtCheck: storedBuybackKind.isNotEmpty
          ? storedBuybackKind
          : buybackPrice > 0
              ? 'live_provider'
              : '',
      forecastLikelyAtBuy:
          (j['forecastLikelyAtBuy'] as num?)?.toDouble() ?? 0,
      forecastLowAtBuy:
          (j['forecastLowAtBuy'] as num?)?.toDouble() ?? 0,
      forecastHighAtBuy:
          (j['forecastHighAtBuy'] as num?)?.toDouble() ?? 0,
      ebayReferenceAtBuy:
          (j['ebayReferenceAtBuy'] as num?)?.toDouble() ?? 0,
      ebayDiscountAtBuy:
          (j['ebayDiscountAtBuy'] as num?)?.toDouble() ?? 0,
    );
  }
}

List<ForecastObservation> v13ForecastObservations(Iterable<V13Flip> flips) =>
    flips
        .where((flip) =>
            flip.status == 'Sold' &&
            flip.forecastLikelyAtBuy > 0 &&
            flip.actualSell > 0)
        .map((flip) => ForecastObservation(
              category: flip.category,
              estimatedLikely: flip.forecastLikelyAtBuy,
              estimatedLow: flip.forecastLowAtBuy,
              estimatedHigh: flip.forecastHighAtBuy,
              actualSalePrice: flip.actualSell,
              ebayAskingReference: flip.ebayReferenceAtBuy,
            ))
        .toList();

class V13PersonalStats {
  final int sample;
  final double? avgDays;
  final double? avgRoi;
  final double? saleFactor;

  const V13PersonalStats({required this.sample, this.avgDays, this.avgRoi, this.saleFactor});

  factory V13PersonalStats.forCategory(List<V13Flip> flips, String category) {
    final sold = flips.where((f) => f.status == 'Sold' && f.actualSell > 0 && f.category == category).toList();
    if (sold.isEmpty) return const V13PersonalStats(sample: 0);
    final days = sold.map((e) => e.daysToSell).whereType<int>().toList();
    final rois = sold.where((e) => e.buy > 0).map((e) => e.realizedRoi).toList();
    final factors = sold
        .where((e) => e.expectedAtBuy > 0)
        .map((e) => e.actualSell / e.expectedAtBuy)
        .where((e) => e.isFinite && e > 0)
        .toList()
      ..sort();
    final factor = factors.isEmpty
        ? null
        : factors.length.isOdd
            ? factors[factors.length ~/ 2]
            : (factors[factors.length ~/ 2 - 1] + factors[factors.length ~/ 2]) / 2;
    return V13PersonalStats(
      sample: sold.length,
      avgDays: days.isEmpty ? null : days.reduce((a, b) => a + b) / days.length,
      avgRoi: rois.isEmpty ? null : rois.reduce((a, b) => a + b) / rois.length,
      saleFactor: factor?.clamp(.82, 1.15).toDouble(),
    );
  }

  String speedLabel(bool english) {
    if (avgDays == null || sample < 2) return english ? 'Unknown' : 'Offen';
    if (avgDays! <= 14) return english ? 'Fast' : 'Schnell';
    if (avgDays! <= 45) return english ? 'Medium' : 'Mittel';
    return english ? 'Slow' : 'Langsam';
  }
}

enum V13TaxMode { privateSeller, smallBusiness, business, marginScheme }

String v13TaxLabel(V13TaxMode mode, bool english) {
  switch (mode) {
    case V13TaxMode.privateSeller:
      return english ? 'Private' : 'Privat';
    case V13TaxMode.smallBusiness:
      return english ? 'Small business' : 'Kleinunternehmer';
    case V13TaxMode.business:
      return english ? 'Business' : 'Gewerblich';
    case V13TaxMode.marginScheme:
      return english ? 'Margin scheme' : 'Differenzbesteuerung';
  }
}

class V13StoreProduct {
  final String id;
  final String price;
  const V13StoreProduct({required this.id, required this.price});
}

class V13Monetization extends ChangeNotifier {
  static const monthlyId = 'flipwert_pro_monthly';
  static const yearlyId = 'flipwert_pro_yearly';
  static const androidBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const androidRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const iosBanner = 'ca-app-pub-3940256099942544/2934735716';
  static const iosRewarded = 'ca-app-pub-3940256099942544/1712485313';

  final VoidCallback onProUnlocked;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final Map<String, ProductDetails> _nativeProducts = <String, ProductDetails>{};
  bool adsAllowed = false;
  bool billingAvailable = false;
  bool loadingBilling = false;
  bool _billingPrepared = false;
  bool _adsPrepared = false;
  bool _adsLoading = false;
  List<V13StoreProduct> products = const [];

  V13Monetization({required this.onProUnlocked});

  String get bannerId => Platform.isAndroid ? androidBanner : iosBanner;
  String get rewardedId => Platform.isAndroid ? androidRewarded : iosRewarded;

  // SAFE RECOVERY STEP 1: nothing native is touched during normal app boot.
  // Billing is initialized lazily by V13Paywall only.
  // Legacy CI markers, intentionally not executable:
  // _scheduleBillingInit();
  // unawaited(monetization.init());
  Future<void> init() async {
    if (_billingPrepared || loadingBilling) return;
    _billingPrepared = true;
    loadingBilling = true;
    notifyListeners();
    try {
      _purchaseSub ??= InAppPurchase.instance.purchaseStream.listen(
        _purchaseUpdate,
        onError: (_) {},
      );
      billingAvailable = await InAppPurchase.instance
          .isAvailable()
          .timeout(const Duration(seconds: 8), onTimeout: () => false);
      if (billingAvailable) {
        final response = await InAppPurchase.instance
            .queryProductDetails({monthlyId, yearlyId})
            .timeout(const Duration(seconds: 10));
        _nativeProducts
          ..clear()
          ..addEntries(response.productDetails.map((p) => MapEntry(p.id, p)));
        products = response.productDetails
            .map((p) => V13StoreProduct(id: p.id, price: p.price))
            .toList(growable: false);
      } else {
        _nativeProducts.clear();
        products = const [];
      }
    } catch (_) {
      billingAvailable = false;
      _nativeProducts.clear();
      products = const [];
    } finally {
      loadingBilling = false;
      notifyListeners();
    }
  }

  // SAFE RECOVERY STEP 2: test ads are prepared only after an explicit
  // ad/privacy action. Normal app boot never calls this method.
  Future<bool> prepareAds() async {
    if (_adsPrepared) return adsAllowed;
    if (_adsLoading) return adsAllowed;
    _adsLoading = true;
    notifyListeners();
    try {
      final completer = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((_) {
            if (!completer.isCompleted) completer.complete();
          });
        },
        (_) {
          if (!completer.isCompleted) completer.complete();
        },
      );
      await completer.future.timeout(const Duration(seconds: 30), onTimeout: () {});
      adsAllowed = await ConsentInformation.instance.canRequestAds();
      if (adsAllowed) {
        await MobileAds.instance.initialize();
      }
    } catch (_) {
      adsAllowed = false;
    } finally {
      _adsPrepared = true;
      _adsLoading = false;
      notifyListeners();
    }
    return adsAllowed;
  }

  Future<void> showPrivacyOptions() async {
    await prepareAds();
    try {
      ConsentForm.showPrivacyOptionsForm((_) {});
    } catch (_) {}
  }

  V13StoreProduct? product(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> buy(V13StoreProduct product) async {
    await init();
    final native = _nativeProducts[product.id];
    if (native == null) return;
    try {
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: native),
      );
    } catch (_) {}
  }

  Future<void> restore() async {
    await init();
    if (!billingAvailable) return;
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (_) {}
  }

  Future<void> _purchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if ((purchase.productID == monthlyId || purchase.productID == yearlyId) &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        // Test-track behavior only. Production must verify the Play token on a
        // trusted server before granting a durable entitlement.
        onProUnlocked();
      }
      if (purchase.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(purchase);
        } catch (_) {}
      }
    }
  }

  Future<bool> rewardedUnlock() async {
    if (!await prepareAds()) return false;
    final completer = Completer<bool>();
    var earned = false;
    try {
      await RewardedAd.load(
        adUnitId: rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (value) {
                value.dispose();
                if (!completer.isCompleted) completer.complete(earned);
              },
              onAdFailedToShowFullScreenContent: (value, _) {
                value.dispose();
                if (!completer.isCompleted) completer.complete(false);
              },
            );
            ad.show(onUserEarnedReward: (_, __) => earned = true);
          },
          onAdFailedToLoad: (_) {
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
    }
    return completer.future.timeout(const Duration(seconds: 45), onTimeout: () => false);
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}

