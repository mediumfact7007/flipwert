part of '../v13_app.dart';

class V13CheckPage extends StatefulWidget {
  final bool english;
  final V13SearchInput input;
  final String backendBase;
  final Future<BuybackSearchResult> Function(
    String query,
    BuybackCondition condition,
  )? buybackSearch;
  final double targetRoi;
  final double minProfit;
  final double ebayDiscount;
  final UserPlan plan;
  final V13TaxMode taxMode;
  final List<PriceSource> sources;
  final List<V13Flip> flips;
  final V13Monetization monetization;
  final ValueChanged<String> onHistory;
  final ValueChanged<V13Flip> onAddFlip;
  final V13Flip? existingSnapshot;
  final ValueChanged<V13Flip>? onUpdateFlip;

  const V13CheckPage({
    super.key,
    required this.english,
    required this.input,
    this.backendBase = '',
    this.buybackSearch,
    required this.targetRoi,
    required this.minProfit,
    this.ebayDiscount = .10,
    required this.plan,
    required this.taxMode,
    required this.sources,
    required this.flips,
    required this.monetization,
    required this.onHistory,
    required this.onAddFlip,
    this.existingSnapshot,
    this.onUpdateFlip,
  });

  @override
  State<V13CheckPage> createState() => _V13CheckPageState();
}

class _V13CheckPageState extends State<V13CheckPage> {
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

  @override
  Widget build(BuildContext context) {
    final d = decision;
    if (d != V13Decision.waiting && d != lastHaptic) {
      lastHaptic = d;
      WidgetsBinding.instance.addPostFrameCallback((_) => HapticFeedback.selectionClick());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Flip prüfen', 'Check flip'), style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _search, icon: const Icon(Icons.refresh_rounded), tooltip: t('Neu laden', 'Refresh'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
        children: [
          TextField(
            controller: query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(labelText: t('Artikel', 'Item'), prefixIcon: const Icon(Icons.search_rounded), suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_forward_rounded))),
          ),
          const SizedBox(height: 10),
          _V13MarketStrip(
            english: widget.english,
            expectedSale: expectedSale,
            activeMedian: activeMedian,
            count: resaleValues.length,
            confidence: confidence,
            pending: pending.length,
            personal: personal,
            isPro: widget.plan != UserPlan.free,
          ),
          const SizedBox(height: 10),
          _V13SourceScroller(
            english: widget.english,
            sources: visibleSources,
            priceFor: _sourceMedian,
            onOpen: _openSource,
            onEbaySold: _openEbaySold,
          ),
          _V154LiveListingPreview(
            english: widget.english,
            showEmpty: query.text.trim().isNotEmpty && pending.isEmpty,
            listings: qualityMarketListings
                .where((e) => e.url.trim().isNotEmpty)
                .take(6)
                .toList(),
          ),
          if (failed.isNotEmpty) ...[
            const SizedBox(height: 7),
            _V145RetrySources(english: widget.english, failed: failed.length, onRetry: _retryFailed),
          ],
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('v13-buy-input'),
            controller: buy,
            focusNode: buyFocus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: t('Was sollst du zahlen?', 'What would you pay?'), hintText: '0,00', suffixText: '€', prefixIcon: const Icon(Icons.shopping_cart_checkout_rounded)),
          ),
          if (SourceRegistry.sharedListingUrl(widget.input.raw) case final sharedLink?) ...[
            const SizedBox(height: 4),
            Row(key: const ValueKey('kleinanzeigen-manual-price'), children: [
              Expanded(child: Text(t('Preis im Inserat prüfen und oben selbst eintragen.', 'Check the listing price and enter it above.'), style: const TextStyle(fontSize: 11, color: Color(0xFF707483)))),
              TextButton(onPressed: () => launchUrl(sharedLink, mode: LaunchMode.externalApplication), child: Text(t('Inserat öffnen', 'Open listing'))),
            ]),
          ] else if (widget.input.detectedPrice != null) ...[
            const SizedBox(height: 4),
            Text(t('Angebotspreis automatisch erkannt – kurz prüfen und bei Bedarf ändern.', 'Listing price detected automatically – quickly verify and edit if needed.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF707483))),
          ],
          if (expectedSale == null || manualMode || widget.existingSnapshot != null) ...[
            const SizedBox(height: 9),
            TextField(
              key: const ValueKey('v13-manual-sale-input'),
              controller: manualSell,
              focusNode: manualFocus,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commitManual(),
              decoration: InputDecoration(
                labelText: t('Erwarteter Verkaufspreis', 'Expected sale price'),
                hintText: t('vollständig eingeben', 'enter full amount'),
                suffixText: '€',
                suffixIcon: IconButton(onPressed: _commitManual, icon: const Icon(Icons.check_rounded)),
              ),
            ),
          ] else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: () => setState(() => manualMode = true), icon: const Icon(Icons.edit_outlined, size: 17), label: Text(t('Verkaufspreis ändern', 'Change sale price'))),
            ),
          ],
          const SizedBox(height: 8),
          _V13DecisionCard(
            english: widget.english,
            updatingExisting: widget.existingSnapshot != null,
            decision: d,
            maxBuy: maxBuy,
            expectedSale: expectedSale,
            profit: profit,
            roi: roi,
            buyPrice: buyPrice,
            speed: personal.speedLabel(widget.english),
            confidence: confidence,
            minProfit: widget.minProfit,
            targetRoi: widget.targetRoi,
            onRemember: d == V13Decision.waiting || savedWatch || savedBought ? null : _remember,
            onBought: d == V13Decision.waiting || savedBought ? null : _bought,
            onNegotiate: d == V13Decision.negotiate ? _copyOffer : null,
          ),
          if (query.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<BuybackCondition>(
              key: const ValueKey('v151-buyback-condition'),
              initialValue: buybackCondition,
              decoration: InputDecoration(
                labelText: t('Zustand für Sofortankauf', 'Condition for instant buyback'),
                prefixIcon: const Icon(Icons.recycling_rounded),
                helperText: t('Nur wählen, wenn du echte Ankaufangebote vergleichen willst.', 'Choose only when you want to compare real buyback offers.'),
              ),
              items: BuybackCondition.values
                  .map((condition) => DropdownMenuItem(
                        value: condition,
                        child: Text(_buybackConditionLabel(condition)),
                      ))
                  .toList(),
              onChanged: (condition) {
                if (condition != null) unawaited(_loadBuyback(condition));
              },
            ),
            if (buybackLoading) ...[
              const SizedBox(height: 8),
              Row(children: [
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text(t('Ankaufangebote werden geprüft …', 'Checking buyback offers …'), style: const TextStyle(fontSize: 11, color: Color(0xFF707483))),
              ]),
            ] else if (buybackCondition != null && buybackOffers.isEmpty) ...[
              const SizedBox(height: 7),
              Container(
                key: const ValueKey('v156-buyback-empty'),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF0D79A)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline_rounded, size: 17, color: Color(0xFF9A6700)),
                  const SizedBox(width: 7),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _buybackEmptyTitle,
                      style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _buybackEmptyBody,
                      style: const TextStyle(fontSize: 9.8, color: Color(0xFF6F6250)),
                    ),
                    if (buybackResult?.unavailable == true) ...[
                      const SizedBox(height: 5),
                      TextButton.icon(
                        key: const ValueKey('v157-buyback-retry'),
                        onPressed: () => unawaited(_loadBuyback(buybackCondition!)),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(t('Erneut prüfen', 'Retry')),
                      ),
                    ],
                  ])),
                ]),
              ),
              const SizedBox(height: 7),
              BuybackProviderLinksCard(
                query: query.text,
                english: widget.english,
              ),
              const SizedBox(height: 7),
              ManualBuybackQuoteCard(
                key: ValueKey('manual-buyback-${token}_${query.text}'),
                purchasePrice: buyPrice + extraCosts,
                privateMarketValue: expectedSale,
                conditionLabel: _buybackConditionLabel(buybackCondition!),
                initialQuote: manualBuybackQuote,
                english: widget.english,
                onChanged: (quote) => setState(() => manualBuybackQuote = quote),
              ),
            ],
            if (buyPrice > 0 &&
                (currentComparableBuybackOffer != null ||
                    resaleEstimate != null)) ...[
              const SizedBox(height: 8),
              DualExitCard(
                comparison: dualExitComparison,
                instantProvider: currentComparableBuybackOffer?.providerName,
                instantRequiresInspection:
                    currentComparableBuybackOffer?.requiresInspection ?? false,
                english: widget.english,
              ),
            ],
            if (buybackOffers.isNotEmpty && !buybackLoading) ...[
              const SizedBox(height: 8),
              BuybackOffersCard(
                offers: buybackOffers,
                purchasePrice: buyPrice > 0 ? buyPrice + extraCosts : 0,
                safetyReserve: buybackSafetyReserve,
                english: widget.english,
              ),
            ],
            if (expectedSale == null &&
                buyPrice > 0 &&
                (currentComparableBuybackOffer != null ||
                    manualBuybackQuote != null)) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('buyback-only-remember-deal'),
                  onPressed: savedWatch ? null : _remember,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: Text(
                    widget.existingSnapshot != null
                        ? t('CHECK ÜBERNEHMEN', 'ACCEPT CHECK')
                        : currentComparableBuybackOffer != null
                            ? t('LIVE-Ankauf als Deal merken', 'Save LIVE buyback deal')
                            : t('Manuellen Ankauf als Deal merken', 'Save manual buyback deal'),
                  ),
                ),
              ),
              Text(
                t(
                  'Der Ankauf wird mit seiner Herkunft gespeichert; ein fehlender Privatmarktwert wird nicht geschätzt.',
                  'The buyback keeps its provenance; a missing private-market value is not estimated.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (buybackSummary != null) ...[
              const SizedBox(height: 8),
              BuybackComparisonCard(summary: buybackSummary!, locale: widget.english ? 'en' : 'de'),
            ],
            if (widget.existingSnapshot?.isSaved == true &&
                widget.existingSnapshot!.buybackPriceAtCheck > 0 &&
                widget.existingSnapshot!.buybackQuoteKindAtCheck == 'live_provider' &&
                !buybackLoading &&
                buybackResult != null) ...[
              const SizedBox(height: 8),
              BuybackRecheckCard(
                previousProvider: widget.existingSnapshot!.buybackProviderAtCheck,
                previousPrice: widget.existingSnapshot!.buybackPriceAtCheck,
                currentOffer: currentComparableBuybackOffer,
                availability: buybackRecheckAvailability,
                previousProfit:
                    widget.existingSnapshot!.buybackPriceAtCheck -
                        widget.existingSnapshot!.buy -
                        widget.existingSnapshot!.costs -
                        widget.existingSnapshot!.buybackSafetyReserve,
                currentPurchasePrice:
                    buyPrice +
                        extraCosts +
                        (currentComparableBuybackOffer?.requiresInspection == true
                            ? buybackSafetyReserve
                            : 0),
                english: widget.english,
              ),
            ],
          ],
          if (widget.existingSnapshot?.isSaved == true && expectedSale != null && (widget.existingSnapshot!.maxBuyAtCheck > 0 || widget.existingSnapshot!.profitAtCheck != 0 || widget.existingSnapshot!.roiAtCheck != 0)) ...[
            const SizedBox(height: 8),
            RecheckDeltaCard(
              english: widget.english,
              delta: RecheckDelta.compare(
                previousAsking: widget.existingSnapshot!.buy,
                currentAsking: buyPrice,
                previousMaxBuy: widget.existingSnapshot!.maxBuyAtCheck,
                currentMaxBuy: maxBuy ?? 0,
                previousProfit: widget.existingSnapshot!.profitAtCheck,
                currentProfit: profit,
                previousRoi: widget.existingSnapshot!.roiAtCheck,
                currentRoi: roi,
              ),
            ),
          ],
          if (!savedWatch &&
              widget.existingSnapshot?.isSaved == true &&
              ((expectedSale != null &&
                  (widget.existingSnapshot!.maxBuyAtCheck > 0 ||
                      widget.existingSnapshot!.profitAtCheck != 0 ||
                      widget.existingSnapshot!.roiAtCheck != 0)) ||
                (widget.existingSnapshot!.buybackQuoteKindAtCheck == 'live_provider' &&
                    widget.existingSnapshot!.buybackPriceAtCheck > 0 &&
                    currentComparableBuybackOffer != null))) ...[
            const SizedBox(height: 8),
            DealAlertResultCard(
              flipId: widget.existingSnapshot!.id,
              english: widget.english,
              previousProfit: widget.existingSnapshot!.profitAtCheck,
              currentProfit: profit,
              previousRoi: widget.existingSnapshot!.roiAtCheck,
              currentRoi: roi,
              hasPrivateComparison: expectedSale != null &&
                  (widget.existingSnapshot!.maxBuyAtCheck > 0 ||
                      widget.existingSnapshot!.profitAtCheck != 0 ||
                      widget.existingSnapshot!.roiAtCheck != 0),
              previousBuybackProfit:
                  widget.existingSnapshot!.buybackQuoteKindAtCheck == 'live_provider'
                      ? widget.existingSnapshot!.buybackPriceAtCheck -
                          widget.existingSnapshot!.buy -
                          widget.existingSnapshot!.costs -
                          widget.existingSnapshot!.buybackSafetyReserve
                      : null,
              currentBuybackProfit:
                  widget.existingSnapshot!.buybackQuoteKindAtCheck == 'live_provider' &&
                          currentComparableBuybackOffer != null
                      ? currentComparableBuybackOffer!.price - buyPrice - extraCosts
                          - (currentComparableBuybackOffer!.requiresInspection
                              ? buybackSafetyReserve
                              : 0)
                      : null,
              verifiedBuybackComparison:
                  widget.existingSnapshot!.buybackQuoteKindAtCheck == 'live_provider' &&
                      widget.existingSnapshot!.buybackPriceAtCheck > 0 &&
                      currentComparableBuybackOffer != null,
            ),
          ],
          if (savedWatch && widget.existingSnapshot?.isSaved == true) ...[
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('v159-recheck-baseline-accepted'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x33087F5B)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF087F5B), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t(
                      'Prüfstand übernommen. Künftige Deal-Alarme vergleichen mit diesen Werten.',
                      'Check accepted. Future deal alerts compare against these values.',
                    ),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF175B47)),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 8),
          _V14ConfidenceCard(english: widget.english, confidence: marketConfidence),
          if (expectedSale != null) ...[
            const SizedBox(height: 10),
            _V13DeepCheck(
              english: widget.english,
              unlocked: widget.plan != UserPlan.free || deepUnlocked,
              loading: deepLoading,
              conservativeExit: conservativeExit,
              buyback: buybackMedian,
              activeMedian: activeMedian,
              retail: retailMedian,
              personal: personal,
              category: category,
              taxMode: widget.taxMode,
              onReward: _rewardDeep,
              onPro: () => Navigator.push(context, MaterialPageRoute(builder: (_) => V13Paywall(english: widget.english, monetization: widget.monetization))),
            ),
          ],
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(t('Kosten & Berechnung', 'Costs & calculation'), style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(t('Nur wenn du genauer rechnen willst', 'Only when you want more detail'), style: const TextStyle(fontSize: 11.5)),
            children: [
              const SizedBox(height: 12, key: ValueKey('v0141-cost-label-top-space')),
              TextField(
                key: const ValueKey('v0141-extra-costs-input'),
                controller: costs,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t('Zusatzkosten gesamt', 'Extra costs total'),
                  suffixText: '€',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('buyback-safety-reserve-input'),
                controller: buybackReserve,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: t(
                    'Ankauf-Sicherheitsabschlag (optional)',
                    'Buyback safety reserve (optional)',
                  ),
                  helperText: t(
                    'Wird nur von vorläufigen Angeboten vor Anbieterprüfung abgezogen.',
                    'Only deducted from provisional quotes before provider inspection.',
                  ),
                  suffixText: '€',
                ),
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: Text(t('Ziel: ${widget.targetRoi.toStringAsFixed(0)} % ROI + mindestens ${v13Euro(widget.minProfit)} Gewinn.', 'Target: ${widget.targetRoi.toStringAsFixed(0)}% ROI + at least ${v13Euro(widget.minProfit)} profit.'), style: const TextStyle(fontSize: 11.5, color: Color(0xFF707483)))),
              const SizedBox(height: 14),
            ],
          ),
          if (widget.plan == UserPlan.free) ...[
            const SizedBox(height: 18),
            V13BannerAd(monetization: widget.monetization),
          ],
        ],
      ),
    );
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
