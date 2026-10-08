part of '../v13_app.dart';

class _V14ConfidenceCard extends StatelessWidget {
  final bool english;
  final V13MarketConfidence confidence;
  const _V14ConfidenceCard({required this.english, required this.confidence});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final accent = confidence.manual || !confidence.hasLiveData
        ? const Color(0xFF6D7180)
        : confidence.score >= 70
            ? const Color(0xFF087F5B)
            : confidence.score >= 45
                ? const Color(0xFFC47B00)
                : const Color(0xFFC33A46);
    final badge = confidence.manual
        ? t('MANUELL', 'MANUAL')
        : confidence.hasLiveData
            ? '${confidence.score}/100'
            : t('KEINE LIVE-DATEN', 'NO LIVE DATA');

    return Container(
      key: const ValueKey('v0144-confidence-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: .22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.verified_user_outlined, size: 20, color: accent),
          const SizedBox(width: 7),
          Expanded(child: Text(t('MARKT-CONFIDENCE', 'MARKET CONFIDENCE'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(99)),
            child: Text(badge, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: accent)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(confidence.label(english), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: accent)),
        if (!confidence.manual && confidence.hasLiveData) ...[
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              key: const ValueKey('v0144-confidence-progress'),
              value: confidence.score / 100,
              minHeight: 7,
              backgroundColor: const Color(0xFFEDEEF4),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
          const SizedBox(height: 8),
        Text(confidence.note(english), style: const TextStyle(fontSize: 10.8, height: 1.35, color: Color(0xFF686C79))),
      ]),
    );
  }
}

class _V13MarketStrip extends StatelessWidget {
  final bool english;
  final double? expectedSale;
  final double? activeMedian;
  final int count;
  final String confidence;
  final int pending;
  final V13PersonalStats personal;
  final bool isPro;

  const _V13MarketStrip({required this.english, required this.expectedSale, required this.activeMedian, required this.count, required this.confidence, required this.pending, required this.personal, required this.isPro});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: _v13Ink, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, size: 17, color: Colors.white),
              const SizedBox(width: 6),
              Text(t('FLIP-DATEN', 'FLIP DATA'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
              const Spacer(),
              if (pending > 0) ...[
                const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                const SizedBox(width: 5),
                Text('$pending', style: const TextStyle(color: Color(0xFFC8CADB), fontSize: 10)),
              ] else
                Text(t('Qualität $confidence', 'Quality $confidence'), style: const TextStyle(color: Color(0xFFC8CADB), fontSize: 10.5)),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(child: _V13Metric(label: t('PLANVERKAUF', 'SALE PLAN'), value: expectedSale == null ? '—' : v13Euro(expectedSale!), strong: true)),
              const SizedBox(width: 7),
              Expanded(child: _V13Metric(label: t('AKTIVE COMPS', 'ACTIVE COMPS'), value: '$count')),
              const SizedBox(width: 7),
              Expanded(child: _V13Metric(label: t('MEDIAN ANGEBOT', 'ASK MEDIAN'), value: activeMedian == null ? '—' : v13Euro(activeMedian!))),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            activeMedian == null
                ? t('Noch keine internen Wiederverkaufsdaten. Quellen unten direkt öffnen oder Verkaufspreis selbst setzen.', 'No internal resale data yet. Open a source below or set the sale price yourself.')
                : t('Planwert aus aktuellen Angeboten – keine automatisch behaupteten Sold-Daten.', 'Plan value from active listings – not claimed as sold data.'),
            style: const TextStyle(color: Color(0xFFBFC1D1), fontSize: 10.5),
          ),
          if (isPro && personal.sample >= 3) ...[
            const SizedBox(height: 4),
            Text(t('Persönlich angepasst mit ${personal.sample} eigenen Verkäufen.', 'Personalized using ${personal.sample} of your own sales.'), style: const TextStyle(color: Color(0xFF9FDAC9), fontSize: 10.5, fontWeight: FontWeight.w800)),
          ],
        ],
      ),
    );
  }
}

class _V13Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _V13Metric({required this.label, required this.value, this.strong = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(color: const Color(0x14FFFFFF), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFAEB0C5), fontSize: 8, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: strong ? 15 : 13, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _V145RetrySources extends StatelessWidget {
  final bool english;
  final int failed;
  final VoidCallback onRetry;
  const _V145RetrySources({required this.english, required this.failed, required this.onRetry});

  @override
  Widget build(BuildContext context) => Row(children: [
        const Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFFC47B00)),
        const SizedBox(width: 6),
        Expanded(child: Text(
          english ? '$failed source(s) could not be reached.' : '$failed Quelle(n) nicht erreichbar.',
          style: const TextStyle(fontSize: 10.8, color: Color(0xFF6C7080)),
        )),
        TextButton.icon(
          key: const ValueKey('v145-retry-sources'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text(english ? 'Retry' : 'Erneut'),
        ),
      ]);
}

class _V13SourceScroller extends StatelessWidget {
  final bool english;
  final List<PriceSource> sources;
  final double? Function(String) priceFor;
  final ValueChanged<PriceSource> onOpen;
  final VoidCallback onEbaySold;

  const _V13SourceScroller({required this.english, required this.sources, required this.priceFor, required this.onOpen, required this.onEbaySold});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _V13SourceChip(name: 'eBay ${t('verkauft', 'sold')}', purpose: t('VERKAUFT', 'SOLD'), icon: Icons.history_rounded, color: const Color(0xFF3665F3), onTap: onEbaySold),
      ...sources.map((s) => _V13SourceChip(name: s.name, purpose: _purpose(s), icon: _sourceIcon(s.id), color: _sourceColor(s), price: priceFor(s.id), onTap: () => onOpen(s))),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('Direkt vergleichen', 'Compare now'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
        const SizedBox(height: 7),
        SizedBox(height: 62, child: ListView.separated(scrollDirection: Axis.horizontal, itemBuilder: (_, i) => items[i], separatorBuilder: (_, __) => const SizedBox(width: 7), itemCount: items.length)),
      ],
    );
  }

  String _purpose(PriceSource s) {
    if (s.id == 'idealo' || s.id == 'geizhals') return t('PREIS', 'PRICE');
    switch (s.role) {
      case 'resale': return t('ANGEBOTE', 'LISTINGS');
      case 'local': return t('LOKAL', 'LOCAL');
      case 'retail': return t('NEU', 'RETAIL');
      case 'buyback': return t('ANKAUF', 'BUYBACK');
      case 'refurb': return 'REFURB';
      default: return t('CHECK', 'CHECK');
    }
  }
}

class _V13SourceChip extends StatelessWidget {
  final String name;
  final String purpose;
  final IconData icon;
  final Color color;
  final double? price;
  final VoidCallback onTap;
  const _V13SourceChip({required this.name, required this.purpose, required this.icon, required this.color, required this.onTap, this.price});

  @override
  Widget build(BuildContext context) => Material(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            constraints: const BoxConstraints(minWidth: 116),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withValues(alpha: .18))),
            child: Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                ConstrainedBox(constraints: const BoxConstraints(maxWidth: 110), child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5))),
                Text(price == null ? purpose : '≈ ${v13Euro(price!)}', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: color)),
              ]),
            ]),
          ),
        ),
      );
}

class _V154LiveListingPreview extends StatelessWidget {
  final bool english;
  final bool showEmpty;
  final List<SourceListing> listings;

  const _V154LiveListingPreview({required this.english, required this.showEmpty, required this.listings});

  String t(String de, String en) => english ? en : de;

  Future<void> _open(SourceListing listing) async {
    final uri = Uri.tryParse(listing.url.trim());
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (listings.isEmpty) {
      if (!showEmpty) return const SizedBox.shrink();
      return Container(
        key: const ValueKey('v155-live-market-empty'),
        margin: const EdgeInsets.only(top: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0D79A)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF9A6700)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Noch keine verifizierten LIVE-Angebote', 'No verified LIVE listings yet'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              t('Für diese Suche liefert aktuell keine angebundene LIVE-Quelle echte Angebote. Sandbox- oder Referenzwerte werden bewusst nicht als LIVE angezeigt.', 'No connected LIVE source currently returns real listings for this search. Sandbox or reference values are deliberately not shown as LIVE.'),
              style: const TextStyle(fontSize: 9.8, color: Color(0xFF6F6250)),
            ),
          ])),
        ]),
      );
    }
    return Container(
      key: const ValueKey('v154-live-market-listings'),
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E6EE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.public_rounded, size: 17, color: Color(0xFF087F5B)),
          const SizedBox(width: 6),
          Expanded(child: Text(t('Aktuelle Angebote', 'Current listings'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5))),
          const _V13Pill(text: 'LIVE', foreground: Color(0xFF087F5B), background: Color(0xFFE8F7F1)),
        ]),
        const SizedBox(height: 3),
        Text(
          t('Nur echte LIVE-Treffer aus angebundenen Marktplätzen – Sandbox/Referenzwerte erscheinen hier nicht.', 'Only real LIVE results from connected marketplaces – sandbox/reference values are not shown here.'),
          style: const TextStyle(fontSize: 9.8, color: Color(0xFF777B88)),
        ),
        const SizedBox(height: 7),
        for (var i = 0; i < listings.length; i++) ...[
          InkWell(
            onTap: () => _open(listings[i]),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(listings[i].title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    '${listings[i].sourceName}${listings[i].condition.trim().isEmpty ? '' : ' · ${listings[i].condition.trim()}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF777B88)),
                  ),
                ])),
                const SizedBox(width: 8),
                Text(v13Euro(listings[i].total), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(width: 4),
                const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF777B88)),
              ]),
            ),
          ),
          if (i != listings.length - 1) const Divider(height: 1),
        ],
      ]),
    );
  }
}

class _V13DecisionCard extends StatelessWidget {
  final bool english;
  final bool updatingExisting;
  final V13Decision decision;
  final double? maxBuy;
  final double? expectedSale;
  final double profit;
  final double roi;
  final double buyPrice;
  final String speed;
  final String confidence;
  final double minProfit;
  final double targetRoi;
  final VoidCallback? onRemember;
  final VoidCallback? onBought;
  final VoidCallback? onNegotiate;

  const _V13DecisionCard({required this.english, this.updatingExisting = false, required this.decision, required this.maxBuy, required this.expectedSale, required this.profit, required this.roi, required this.buyPrice, required this.speed, required this.confidence, required this.minProfit, required this.targetRoi, this.onRemember, this.onBought, this.onNegotiate});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    Color color;
    String title;
    IconData icon;
    switch (decision) {
      case V13Decision.buy:
        color = const Color(0xFF087F5B); title = t('KAUFEN', 'BUY'); icon = Icons.check_circle_rounded;
      case V13Decision.negotiate:
        color = const Color(0xFFC47B00); title = t('VERHANDELN', 'NEGOTIATE'); icon = Icons.handshake_rounded;
      case V13Decision.skip:
        color = const Color(0xFFC33A46); title = t('LASSEN', 'SKIP'); icon = Icons.cancel_rounded;
      case V13Decision.waiting:
        color = const Color(0xFF555A69); title = expectedSale == null ? t('VERKAUFSPREIS FEHLT', 'SALE PRICE NEEDED') : t('EINKAUFSPREIS EINGEBEN', 'ENTER BUY PRICE'); icon = Icons.arrow_upward_rounded;
    }
    return Container(
      key: const ValueKey('v13-decision-card'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(22), border: Border.all(color: color.withValues(alpha: .20))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, color: color, size: 25), const SizedBox(width: 8), Expanded(child: Text(title, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900))), if (maxBuy != null) Text('${t('MAX', 'MAX')} ${v13Euro(maxBuy!)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))]),
        if (decision != V13Decision.waiting && expectedSale != null) ...[
          const SizedBox(height: 11),
          Row(children: [
            Expanded(child: _V13LightMetric(label: t('GEWINN', 'PROFIT'), value: v13Euro(profit))),
            const SizedBox(width: 6),
            Expanded(child: _V13LightMetric(label: 'ROI', value: '${roi.toStringAsFixed(0)} %')),
            const SizedBox(width: 6),
            Expanded(child: _V13LightMetric(label: t('TEMPO', 'SPEED'), value: speed)),
          ]),
          const SizedBox(height: 7),
          if (maxBuy != null && buyPrice > 0)
            Text(
              buyPrice <= maxBuy!
                  ? t('${v13Euro(maxBuy! - buyPrice)} Puffer bis zu deinem MAX.', '${v13Euro(maxBuy! - buyPrice)} buffer below your MAX.')
                  : t('${v13Euro(buyPrice - maxBuy!)} über deinem MAX.', '${v13Euro(buyPrice - maxBuy!)} above your MAX.'),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: color),
            ),
          const SizedBox(height: 3),
          Text(t('Ziel: ≥ ${targetRoi.toStringAsFixed(0)} % ROI und ≥ ${v13Euro(minProfit)} Gewinn · Datenqualität $confidence.', 'Target: ≥ ${targetRoi.toStringAsFixed(0)}% ROI and ≥ ${v13Euro(minProfit)} profit · data quality $confidence.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF686C79))),
          const SizedBox(height: 10),
          Row(children: [
            if (onRemember != null) Expanded(child: OutlinedButton.icon(key: const ValueKey('v147-remember-deal'), onPressed: onRemember, icon: Icon(updatingExisting ? Icons.update_rounded : Icons.bookmark_add_outlined, size: 18), label: Text(updatingExisting ? t('CHECK ÜBERNEHMEN', 'ACCEPT CHECK') : t('MERKEN', 'SAVE')))),
            if (onRemember != null && onBought != null) const SizedBox(width: 7),
            if (onBought != null) Expanded(child: FilledButton.icon(onPressed: onBought, icon: const Icon(Icons.inventory_2_rounded), label: Text(t('GEKAUFT', 'BOUGHT')))),
          ]),
          if (onNegotiate != null) ...[
            const SizedBox(height: 7),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onNegotiate, icon: const Icon(Icons.copy_rounded, size: 18), label: Text(t('PREISVORSCHLAG KOPIEREN', 'COPY OFFER')))),
          ],
        ] else ...[
          const SizedBox(height: 5),
          Text(expectedSale == null ? t('Quelle antippen oder erwarteten Verkaufspreis eingeben.', 'Tap a source or enter an expected sale price.') : t('Oben deinen Einkaufspreis eingeben.', 'Enter your buy price above.'), style: const TextStyle(fontSize: 12.5, color: Color(0xFF666A77))),
        ],
      ]),
    );
  }
}

class _V13LightMetric extends StatelessWidget {
  final String label;
  final String value;
  const _V13LightMetric({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .75), borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 8.5, color: Color(0xFF787C89), fontWeight: FontWeight.w800)), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))]),
      );
}

class _V13DeepCheck extends StatelessWidget {
  final bool english;
  final bool unlocked;
  final bool loading;
  final double? conservativeExit;
  final double? buyback;
  final double? activeMedian;
  final double? retail;
  final V13PersonalStats personal;
  final String category;
  final V13TaxMode taxMode;
  final VoidCallback onReward;
  final VoidCallback onPro;

  const _V13DeepCheck({required this.english, required this.unlocked, required this.loading, required this.conservativeExit, required this.buyback, required this.activeMedian, required this.retail, required this.personal, required this.category, required this.taxMode, required this.onReward, required this.onPro});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    if (!unlocked) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2B2A54), Color(0xFF5556D7)]), borderRadius: BorderRadius.circular(21)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.auto_awesome_rounded, color: Colors.white), const SizedBox(width: 8), Text('DEEP CHECK', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), const Spacer(), const _V13Pill(text: 'PRO', foreground: _v13Primary, background: Colors.white)]),
          const SizedBox(height: 5),
          Text(t('Konservativer Exit · Kapitaltempo · persönliches Muster · Risiko', 'Conservative exit · capital speed · personal pattern · risk'), style: const TextStyle(color: Color(0xFFD4D5EE), fontSize: 11.5)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x66FFFFFF))), onPressed: loading ? null : onReward, icon: loading ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ondemand_video_rounded, size: 18), label: Text(t('WERBUNG SPÄTER', 'ADS LATER')))),
            const SizedBox(width: 7),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _v13Primary), onPressed: onPro, child: const Text('PRO'))),
          ]),
        ]),
      );
    }

    final tips = _riskTips(category, english);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(21), border: Border.all(color: const Color(0xFFE4E6EE))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.auto_awesome_rounded, color: _v13Primary, size: 20), const SizedBox(width: 7), const Text('DEEP CHECK', style: TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text(personal.sample >= 2 ? '${personal.sample} ${t('eigene Sales', 'own sales')}' : t('Marktbasis', 'Market basis'), style: const TextStyle(fontSize: 9.5, color: Color(0xFF777B88)))]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _V13MiniInfo(label: t('KONSERVATIV', 'CONSERVATIVE'), value: conservativeExit == null ? '—' : v13Euro(conservativeExit!))),
          const SizedBox(width: 6),
          Expanded(child: _V13MiniInfo(label: t('SOFORT-EXIT', 'FAST EXIT'), value: buyback == null ? '—' : v13Euro(buyback!))),
          const SizedBox(width: 6),
          Expanded(child: _V13MiniInfo(label: t('KAPITALTEMPO', 'CAPITAL SPEED'), value: personal.speedLabel(english))),
        ]),
        if (retail != null || activeMedian != null) ...[
          const SizedBox(height: 8),
          Text(t('Gebrauchtmarkt steht bewusst vor Neupreis. ${retail == null ? '' : 'Neupreis-Referenz ${v13Euro(retail!)}.'}', 'Resale market is intentionally prioritized over retail. ${retail == null ? '' : 'Retail reference ${v13Euro(retail!)}.'}'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF6F7380))),
        ],
        const SizedBox(height: 9),
        Wrap(spacing: 6, runSpacing: 6, children: tips.map((e) => _V13Pill(text: e, foreground: const Color(0xFF515562), background: const Color(0xFFF0F1F6))).toList()),
        const SizedBox(height: 8),
        Text(t('Steuerprofil: ${v13TaxLabel(taxMode, false)} · Steuern werden nicht automatisch vom Gewinn abgezogen.', 'Tax profile: ${v13TaxLabel(taxMode, true)} · taxes are not automatically deducted from profit.'), style: const TextStyle(fontSize: 9.8, color: Color(0xFF858997))),
      ]),
    );
  }
}

class _V13MiniInfo extends StatelessWidget {
  final String label;
  final String value;
  const _V13MiniInfo({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(13)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7.8, color: Color(0xFF858997), fontWeight: FontWeight.w900)), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900))]));
}

List<String> _riskTips(String category, bool english) {
  final map = <String, List<String>>{
    'Smartphone': english ? ['Account lock', 'IMEI', 'Battery'] : ['Accountsperre', 'IMEI', 'Akku'],
    'Laptop': english ? ['Battery', 'Display', 'Charger'] : ['Akku', 'Display', 'Netzteil'],
    'Konsole': english ? ['Ban/account', 'Drive', 'Controller'] : ['Ban/Account', 'Laufwerk', 'Controller'],
    'Sneaker': english ? ['Authenticity', 'Size', 'Condition'] : ['Echtheit', 'Größe', 'Zustand'],
    'Kamera': english ? ['Shutter', 'Sensor', 'Lens'] : ['Auslösungen', 'Sensor', 'Objektiv'],
    'Werkzeug': english ? ['Battery', 'Serial', 'Wear'] : ['Akku', 'Seriennr.', 'Verschleiß'],
  };
  return map[category] ?? (english ? ['Variant', 'Condition', 'Completeness'] : ['Variante', 'Zustand', 'Vollständigkeit']);
}

