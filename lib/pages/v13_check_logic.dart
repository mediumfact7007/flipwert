part of '../v13_app.dart';

abstract class _V13CheckPageLogic extends State<V13CheckPage> {
  late final TextEditingController query;
  final buy = TextEditingController();
  final costs = TextEditingController(text: '0');
  final buybackReserve = TextEditingController(text: '0');
  final manualSell = TextEditingController();
  final buyFocus = FocusNode();
  final manualFocus = FocusNode();
  List<SourceListing> listings = [];
  final Set<String> pending = {};
  final Set<String> failed = {};
  bool manualMode = false;
  double? manualCommitted;
  double? snapshotExpectedFallback;
  bool deepUnlocked = false;
  bool deepLoading = false;
  bool savedBought = false;
  bool savedWatch = false;
  BuybackCondition? buybackCondition;
  List<BuybackOffer> buybackOffers = const [];
  BuybackSearchResult? buybackResult;
  bool buybackLoading = false;
  ManualBuybackQuote? manualBuybackQuote;
  int buybackToken = 0;
  int token = 0;
  V13Decision? lastHaptic;

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    query = TextEditingController(text: widget.input.query);
    final detected = widget.input.detectedPrice;
    final existing = widget.existingSnapshot;
    buybackCondition = BuybackConditionWire.tryParse(
      existing?.buybackConditionAtCheck ?? '',
    );
    if (existing != null &&
        existing.buybackQuoteKindAtCheck == 'manual_user' &&
        existing.buybackPriceAtCheck > 0 &&
        existing.buybackProviderAtCheck.trim().isNotEmpty) {
      manualBuybackQuote = ManualBuybackQuote(
        providerName: existing.buybackProviderAtCheck,
        price: existing.buybackPriceAtCheck,
      );
    }
    if (detected != null && detected > 0) {
      buy.text = detected == detected.roundToDouble()
          ? detected.toStringAsFixed(0)
          : detected.toStringAsFixed(2).replaceAll('.', ',');
    } else if (existing != null && existing.buy > 0) {
      buy.text = existing.buy == existing.buy.roundToDouble()
          ? existing.buy.toStringAsFixed(0)
          : existing.buy.toStringAsFixed(2).replaceAll('.', ',');
    }
    if (existing != null && existing.expectedAtBuy > 0) {
      manualSell.text = existing.expectedAtBuy == existing.expectedAtBuy.roundToDouble()
          ? existing.expectedAtBuy.toStringAsFixed(0)
          : existing.expectedAtBuy.toStringAsFixed(2).replaceAll('.', ',');
    }
    if (existing != null && existing.costs > 0) {
      costs.text = existing.costs == existing.costs.roundToDouble()
          ? existing.costs.toStringAsFixed(0)
          : existing.costs.toStringAsFixed(2).replaceAll('.', ',');
    }
    if (existing != null && existing.buybackSafetyReserve > 0) {
      buybackReserve.text =
          existing.buybackSafetyReserve ==
                  existing.buybackSafetyReserve.roundToDouble()
              ? existing.buybackSafetyReserve.toStringAsFixed(0)
              : existing.buybackSafetyReserve
                  .toStringAsFixed(2)
                  .replaceAll('.', ',');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _search();
    });
  }

  Future<void> _search() async {
    final q = normalizeV13Search(query.text).query;
    if (q.isEmpty) return;
    final preserveSnapshotFallback = widget.existingSnapshot != null && token == 0;
    final myToken = ++token;
    ++buybackToken; // Invalidate quotes still loading for the previous query.
    widget.onHistory(q);
    setState(() {
      listings = [];
      pending.clear();
      failed.clear();
      manualCommitted = null;
      snapshotExpectedFallback = preserveSnapshotFallback &&
              widget.existingSnapshot!.expectedAtBuy.isFinite &&
              widget.existingSnapshot!.expectedAtBuy > 0
          ? widget.existingSnapshot!.expectedAtBuy
          : null;
      if (!preserveSnapshotFallback) manualSell.clear();
      manualMode = false;
      savedBought = false;
      savedWatch = false;
      buybackOffers = const [];
      buybackResult = null;
      buybackLoading = false;
      if (!preserveSnapshotFallback) manualBuybackQuote = null;
    });
    final direct = widget.sources.where((s) => s.enabled && s.canFetchInApp).toList();
    pending.addAll(direct.map((e) => e.id));
    if (mounted) setState(() {});
    final selectedCondition = buybackCondition;
    if (selectedCondition != null) unawaited(_loadBuyback(selectedCondition));
    if (direct.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => buyFocus.requestFocus());
      return;
    }
    for (final source in direct) {
      unawaited(_fetchOne(source, q, myToken));
    }
  }

  Future<void> _fetchOne(PriceSource source, String q, int myToken) async {
    List<SourceListing> result = [];
    var didFail = false;
    try {
      result = await SourceRegistry.fetch(source, q);
    } catch (_) {
      didFail = true;
    }
    if (!mounted || myToken != token) return;
    final combined = [...listings, ...result];
    final dedupe = <String, SourceListing>{};
    for (final item in combined) {
      if (!item.total.isFinite || item.total <= 0) continue;
      final key = item.url.trim().isNotEmpty
          ? '${item.sourceId}|${item.url}'
          : '${item.sourceId}|${item.title.toLowerCase()}|${item.total.toStringAsFixed(2)}';
      dedupe[key] = item;
    }
    pending.remove(source.id);
    if (didFail) {
      failed.add(source.id);
    } else {
      failed.remove(source.id);
    }
    setState(() => listings = dedupe.values.toList()..sort((a, b) => a.total.compareTo(b.total)));
    if (pending.isEmpty && expectedSale == null) setState(() => manualMode = true);
    if (buy.text.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => buyFocus.requestFocus());
  }

  Future<void> _loadBuyback(BuybackCondition condition) async {
    final q = normalizeV13Search(query.text).query;
    if (q.isEmpty) return;
    final myToken = ++buybackToken;
    setState(() {
      buybackCondition = condition;
      buybackOffers = const [];
      buybackResult = null;
      buybackLoading = true;
    });
    final injected = widget.buybackSearch;
    final result = injected != null
        ? await injected(q, condition)
        : await BuybackClient(
            backendBase: widget.backendBase.trim().isEmpty
                ? SourceRegistry.defaultBackend
                : widget.backendBase,
          ).searchDetailed(q, condition: condition);
    if (!mounted || myToken != buybackToken) return;
    setState(() {
      buybackOffers = result.offers;
      buybackResult = result;
      buybackLoading = false;
    });
  }

  String _buybackConditionLabel(BuybackCondition condition) => switch (condition) {
        BuybackCondition.newSealed => t('Neu & OVP', 'New & sealed'),
        BuybackCondition.likeNew => t('Wie neu', 'Like new'),
        BuybackCondition.veryGood => t('Sehr gut', 'Very good'),
        BuybackCondition.usedGood => t('Gebraucht', 'Used'),
        BuybackCondition.acceptable => t('Akzeptabel', 'Acceptable'),
        BuybackCondition.defective => t('Defekt', 'Defective'),
      };

  String get _buybackEmptyTitle {
    final result = buybackResult;
    if (result?.unavailable == true) {
      return t(
        'Ankaufquelle vorübergehend nicht erreichbar',
        'Buyback source temporarily unavailable',
      );
    }
    if (result?.configured == true) {
      return t(
        'Kein passendes LIVE-Ankaufangebot',
        'No matching LIVE buyback offer',
      );
    }
    return switch (result?.readiness) {
      BuybackReadiness.awaitingValidation => t(
          'LIVE-Ankaufquelle wartet auf technische Freigabe',
          'LIVE buyback source awaits technical approval',
        ),
      BuybackReadiness.approvalsMissing => t(
          'Anbieterfreigabe fehlt oder ist abgelaufen',
          'Provider approval is missing or expired',
        ),
      _ => t(
          'Noch keine LIVE-Ankaufquelle freigeschaltet',
          'No LIVE buyback source enabled yet',
        ),
    };
  }

  String get _buybackEmptyBody {
    final result = buybackResult;
    if (result?.unavailable == true) {
      return t(
        'Die LIVE-Abfrage ist fehlgeschlagen. Deine normale Deal-Prüfung bleibt nutzbar; Flipwert zeigt keinen geschätzten Ersatzpreis.',
        'The LIVE request failed. Your normal deal check remains available; Flipwert does not show an estimated substitute price.',
      );
    }
    if (result?.configured == true) {
      return t(
        'Die angebundene Quelle liefert für diesen Artikel und Zustand aktuell keinen qualitätsgeprüften Preis. Flipwert schätzt hier bewusst keinen Ankaufpreis.',
        'The connected source currently has no quality-checked price for this item and condition. Flipwert deliberately does not estimate a buyback price.',
      );
    }
    return switch (result?.readiness) {
      BuybackReadiness.awaitingValidation => t(
          'Der genehmigte Feed ist vorbereitet, aber die repräsentative Geräte-, Varianten- und Zustandsprüfung ist noch nicht aktuell erfolgreich. Bis zur bewussten Aktivierung zeigt Flipwert keine Preise.',
          'The approved feed is prepared, but its representative product, variant and condition validation is not currently successful. Flipwert shows no prices until deliberate activation.',
        ),
      BuybackReadiness.approvalsMissing => t(
          'Für LIVE-Preise werden aktuelle Feed-, Preis-, Anbieter- und Linkrechte benötigt. Ohne gültige Freigabe bleibt die Quelle gesperrt.',
          'Current feed, price-display, provider and link rights are required for LIVE prices. The source stays disabled without valid approval.',
        ),
      _ => t(
          'Für echte Ankaufpreise fehlt noch ein genehmigter Anbieterfeed mit Preisfreigabe. Flipwert zeigt bis dahin bewusst keinen geschätzten Ankaufpreis.',
          'An approved provider feed with price-display permission is still required for real buyback prices. Flipwert deliberately shows no estimated price until then.',
        ),
    };
  }

  BuybackComparisonSummary? get buybackSummary {
    final condition = buybackCondition;
    final privateValue = expectedSale;
    if (condition == null || privateValue == null || privateValue <= 0 || buyPrice <= 0) {
      return null;
    }
    return buildBuybackComparisonSummary(
      buybackOffers,
      condition: condition,
      purchasePrice: buyPrice + extraCosts,
      privateMarketValue: privateValue,
      safetyReserve: buybackSafetyReserve,
    );
  }

  BuybackOffer? get currentComparableBuybackOffer {
    final condition = buybackCondition;
    if (condition == null) return null;
    return bestComparableBuybackOfferAfterReserve(
      buybackOffers,
      condition: condition,
      safetyReserve: buybackSafetyReserve,
      now: DateTime.now(),
    );
  }

  BuybackRecheckAvailability get buybackRecheckAvailability {
    if (currentComparableBuybackOffer != null) {
      return BuybackRecheckAvailability.offer;
    }
    final result = buybackResult;
    if (result?.unavailable == true) {
      return BuybackRecheckAvailability.sourceUnavailable;
    }
    if (result?.readiness == BuybackReadiness.awaitingValidation ||
        result?.readiness == BuybackReadiness.approvalsMissing ||
        result?.readiness == BuybackReadiness.notConfigured) {
      return BuybackRecheckAvailability.sourceNotReady;
    }
    if (result?.configured == true) {
      return BuybackRecheckAvailability.noMatch;
    }
    return BuybackRecheckAvailability.sourceNotReady;
  }

  DualExitComparison get dualExitComparison {
    final offer = currentComparableBuybackOffer;
    return buildDualExitComparison(
      purchasePrice: buyPrice,
      additionalCosts: extraCosts,
      instantProceeds: offer == null
          ? null
          : buybackEffectiveProceeds(offer, buybackSafetyReserve),
      marketEstimate: resaleEstimate,
    );
  }

  void _retryFailed() {
    if (failed.isEmpty) return;
    final q = normalizeV13Search(query.text).query;
    if (q.isEmpty) return;
    final ids = failed.toSet();
    final retry = widget.sources
        .where((s) => ids.contains(s.id) && s.enabled && s.canFetchInApp)
        .toList();
    if (retry.isEmpty) {
      setState(() => failed.clear());
      return;
    }
    final myToken = token;
    setState(() {
      for (final source in retry) {
        failed.remove(source.id);
        pending.add(source.id);
      }
    });
    for (final source in retry) {
      unawaited(_fetchOne(source, q, myToken));
    }
  }

  List<double> _valuesFor(Set<String> roles) => listings
      .where((e) => e.live && roles.contains(e.role))
      .map((e) => e.total)
      .where((e) => e > 0 && e.isFinite)
      .toList();

  double? _median(List<double> raw) {
    if (raw.isEmpty) return null;
    final values = [...raw]..sort();
    final mid = values.length ~/ 2;
    return values.length.isOdd ? values[mid] : (values[mid - 1] + values[mid]) / 2;
  }

  List<double> _clean(List<double> raw) => v13CleanMarketValues(raw);

  List<SourceListing> get comparableMarketListings =>
      v13ComparableMarketListings(listings, query.text);

  List<SourceListing> get qualityMarketListings =>
      v13QualityMarketListings(listings, query.text);

  double? get activeMedian => _median(resaleValues);
  double? get retailMedian => _median(_clean(_valuesFor({'retail', 'refurb'})));
  double? get buybackMedian => _median(_clean(_valuesFor({'buyback'})));
  String get category => v13Category(query.text);
  V13PersonalStats get personal => V13PersonalStats.forCategory(widget.flips, category);

  List<double> get ebayAskingValues =>
      v13EbayAskingValues(listings, query.text);

  double get learnedEbayDiscount => calibratedEbayDiscount(
        category: category,
        observations: v13ForecastObservations(widget.flips),
        fallback: widget.ebayDiscount,
      );

  ResaleEstimate? get resaleEstimate => estimateResaleValue(
        ResaleEstimateInput(
          article: query.text,
          category: category,
          ownSales: widget.flips
              .where((flip) =>
                  flip.status == 'Sold' &&
                  flip.actualSell > 0 &&
                  flip.soldAt != null)
              .map((flip) => ResaleSaleSample(
                    article: flip.name,
                    category: flip.category,
                    salePrice: flip.actualSell,
                    purchaseDate: flip.createdAt,
                    saleDate: flip.soldAt!,
                  ))
              .toList(),
          activeEbayAskingPrices: ebayAskingValues,
          buybackFloor: buybackMedian,
          ebayAskingDiscount: learnedEbayDiscount,
          asOf: DateTime.now(),
        ),
      );

  double? get baseExpectedSale {
    return v13ResolveExpectedSale(
      manualOverride: manualCommitted,
      marketEstimate: resaleEstimate?.likely,
      snapshotFallback: snapshotExpectedFallback,
    );
  }

  double? get expectedSale => baseExpectedSale;

  double get extraCosts => v13Money(costs.text);
  double get buybackSafetyReserve => v13Money(buybackReserve.text);
  double get buyPrice => v13Money(buy.text);

  double? get maxBuy {
    final sell = expectedSale;
    if (sell == null || sell <= 0) return null;
    final byRoi = (sell - extraCosts) / (1 + widget.targetRoi / 100);
    final byProfit = sell - extraCosts - widget.minProfit;
    return math.max(0, math.min(byRoi, byProfit));
  }

  double get profit {
    final sell = expectedSale ?? 0;
    return sell - buyPrice - extraCosts;
  }

  double get roi => buyPrice <= 0 ? 0 : profit / buyPrice * 100;

  V13Decision get decision {
    final limit = maxBuy;
    if (limit == null || buyPrice <= 0) return V13Decision.waiting;
    if (buyPrice <= limit) return V13Decision.buy;
    if (buyPrice <= limit * 1.12) return V13Decision.negotiate;
    return V13Decision.skip;
  }

  V13MarketConfidence get marketConfidence => v13MarketConfidence(
        listings,
        manualOverride: manualCommitted != null && manualCommitted! > 0,
        query: query.text,
      );
  String get confidence => marketConfidence.label(widget.english);

  List<double> get resaleValues =>
      qualityMarketListings.map((e) => e.total).toList();

  double? get conservativeExit {
    return v13ResolveExpectedSale(
      manualOverride: manualCommitted,
      marketEstimate: resaleEstimate?.low,
      snapshotFallback: snapshotExpectedFallback,
    );
  }

  double? _sourceMedian(String id) => _median(_clean((id == 'ebay_de'
          ? comparableMarketListings.where((e) => e.sourceId == id)
          : listings.where((e) => e.live && e.sourceId == id))
      .map((e) => e.total)
      .where((e) => e > 0 && e.isFinite)
      .toList()));

  List<PriceSource> get visibleSources {
    final input = widget.sources.where((s) => s.enabled).toList();
    final q = query.text.toLowerCase();
    final fashion = RegExp(r'(nike|adidas|jordan|yeezy|sneaker|schuh|jacke|hose|kleid|tasche)').hasMatch(q);
    final electronics = RegExp(r'(iphone|samsung|galaxy|pixel|macbook|laptop|playstation|ps5|xbox|switch|kamera)').hasMatch(q);
    final order = fashion
        ? ['vinted', 'kleinanzeigen', 'ebay_de', 'idealo', 'geizhals', 'amazon_de', 'rebuy', 'backmarket', 'mediamarkt', 'saturn']
        : electronics
            ? ['ebay_de', 'kleinanzeigen', 'rebuy', 'backmarket', 'geizhals', 'idealo', 'amazon_de', 'mediamarkt', 'saturn', 'vinted']
            : ['ebay_de', 'kleinanzeigen', 'vinted', 'idealo', 'geizhals', 'amazon_de', 'rebuy', 'backmarket', 'mediamarkt', 'saturn'];
    final rank = <String, int>{for (var i = 0; i < order.length; i++) order[i]: i};
    input.sort((a, b) => (rank[a.id] ?? 99).compareTo(rank[b.id] ?? 99));
    return input;
  }

  void _commitManual() {
    final value = v13Money(manualSell.text);
    if (value <= 0) return;
    setState(() {
      manualCommitted = value;
      manualMode = false;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _openSource(PriceSource source) async {
    final uri = Uri.tryParse(source.searchUrl(query.text.trim()));
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openEbaySold() async {
    final uri = Uri.parse('https://www.ebay.de/sch/i.html?_nkw=${Uri.encodeQueryComponent(query.text.trim())}&LH_Sold=1&LH_Complete=1');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  V13Flip? _dealSnapshot(String status) {
    final expected = expectedSale;
    final buybackOffer = currentComparableBuybackOffer;
    final manualQuote = buybackOffer == null ? manualBuybackQuote : null;
    if (buyPrice <= 0 ||
        (expected == null && buybackOffer == null && manualQuote == null)) {
      return null;
    }
    final now = DateTime.now();
    final existing = widget.existingSnapshot;
    final rawUrl = _v147SourceUrl(widget.input.raw);
    final createdAt = status == 'Bought' && existing?.isSaved == true
        ? now
        : (existing?.createdAt ?? now);
    return V13Flip(
      id: existing?.id ?? now.microsecondsSinceEpoch.toString(),
      name: query.text.trim(),
      category: category,
      buy: buyPrice,
      expectedAtBuy: expected ?? 0,
      costs: extraCosts,
      buybackSafetyReserve:
          buybackOffer?.requiresInspection == true
              ? buybackSafetyReserve
              : 0,
      sourceCount: resaleValues.length,
      confidence: confidence,
      status: status,
      createdAt: createdAt,
      checkedAt: now,
      sourceUrl: rawUrl.isNotEmpty ? rawUrl : (existing?.sourceUrl ?? ''),
      // Keep missing private-market evidence missing. The buyback fields below
      // carry the independent exit path and must never manufacture a private
      // sale estimate merely to make a deal snapshot persistable.
      maxBuyAtCheck: expected == null ? 0 : (maxBuy ?? 0),
      profitAtCheck: expected == null ? 0 : profit,
      roiAtCheck: expected == null ? 0 : roi,
      confidenceScore: marketConfidence.score,
      buybackPriceAtCheck: buybackOffer?.price ?? manualQuote?.price ?? 0,
      buybackProviderAtCheck: buybackOffer?.providerName ?? manualQuote?.providerName ?? '',
      buybackConditionAtCheck: buybackCondition?.wireValue ?? '',
      buybackCheckedAt: buybackOffer?.checkedAt ?? (manualQuote == null ? null : now),
      buybackQuoteKindAtCheck: buybackOffer != null
          ? 'live_provider'
          : manualQuote != null
              ? 'manual_user'
              : '',
      forecastLikelyAtBuy: resaleEstimate?.likely ?? 0,
      forecastLowAtBuy: resaleEstimate?.low ?? 0,
      forecastHighAtBuy: resaleEstimate?.high ?? 0,
      ebayReferenceAtBuy: _median(ebayAskingValues) ?? 0,
      ebayDiscountAtBuy: resaleEstimate?.appliedEbayDiscount ?? 0,
    );
  }

  void _remember() {
    final item = _dealSnapshot('Saved');
    if (item == null) return;
    final updating = widget.existingSnapshot != null && widget.onUpdateFlip != null;
    if (updating) {
      widget.onUpdateFlip!(item);
    } else {
      widget.onAddFlip(item);
    }
    setState(() => savedWatch = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t(updating ? 'Deal aktualisiert.' : 'Deal gemerkt.', updating ? 'Deal updated.' : 'Deal saved.'))));
  }

  void _bought() {
    final item = _dealSnapshot('Bought');
    if (item == null) return;
    if (widget.existingSnapshot != null && widget.onUpdateFlip != null) {
      widget.onUpdateFlip!(item);
    } else {
      widget.onAddFlip(item);
    }
    setState(() => savedBought = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Als gekauft gespeichert.', 'Saved as bought.'))));
  }

  void _copyOffer() {
    final limit = maxBuy ?? 0;
    final offer = math.max(0.0, math.min(limit * .95, buyPrice * .90)).toDouble();
    final message = t('Hallo, wären ${v13Euro(offer)} bei schneller Abwicklung für dich okay?', 'Hi, would ${v13Euro(offer)} work for a quick deal?');
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Verhandlungstext kopiert.', 'Negotiation message copied.'))));
  }

  Future<void> _rewardDeep() async {
    setState(() => deepLoading = true);
    final ok = await widget.monetization.rewardedUnlock();
    if (!mounted) return;
    setState(() {
      deepLoading = false;
      if (ok) deepUnlocked = true;
    });
    if (!ok) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('Werbung momentan nicht verfügbar.', 'Ad currently unavailable.'))));
  }

  @override
  void dispose() {
    query.dispose();
    buy.dispose();
    costs.dispose();
    buybackReserve.dispose();
    manualSell.dispose();
    buyFocus.dispose();
    manualFocus.dispose();
    super.dispose();
  }
}
