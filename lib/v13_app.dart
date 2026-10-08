import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'buyback.dart';
import 'buyback_client.dart';
import 'buyback_summary.dart';
import 'buyback_summary_card.dart';
import 'buyback_offers_card.dart';
import 'buyback_provider_links_card.dart';
import 'buyback_recheck_card.dart';
import 'deal_alert_store.dart';
import 'deal_alert_toggle.dart';
import 'dual_exit.dart';
import 'dual_exit_card.dart';
import 'deal_alert_result_card.dart';
import 'forecast_accuracy_card.dart';
import 'forecast_control.dart';
import 'manual_buyback_quote_card.dart';




import 'recheck_delta.dart';
import 'recheck_delta_card.dart';
import 'source_registry.dart';
import 'source_status.dart';
import 'scanner_page.dart';
import 'sales_csv.dart';
import 'resale_estimate.dart';


part 'pages/v13_sources_page.dart';
part 'models/v13_models.dart';
part 'pages/v13_shell.dart';
part 'pages/v13_home_page.dart';
part 'pages/v13_check_page.dart';
part 'pages/v13_check_logic.dart';


List<double> v13CleanMarketValues(List<double> raw) {
  final values = raw.where((e) => e.isFinite && e > 0).toList()..sort();
  if (values.length < 3) return values;

  double median(List<double> input) {
    final mid = input.length ~/ 2;
    return input.length.isOdd
        ? input[mid]
        : (input[mid - 1] + input[mid]) / 2;
  }

  double quantile(List<double> input, double q) {
    if (input.length == 1) return input.first;
    final position = (input.length - 1) * q;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return input[lower];
    final fraction = position - lower;
    return input[lower] + (input[upper] - input[lower]) * fraction;
  }

  final med = median(values);
  final ratioFiltered = values
      .where((v) => v >= med * .45 && v <= med * 1.85)
      .toList();
  final working = ratioFiltered.length >= 2 ? ratioFiltered : values;
  if (working.length < 5) return working;

  final q1 = quantile(working, .25);
  final q3 = quantile(working, .75);
  final iqr = q3 - q1;
  if (iqr <= 0) return working;

  final lowerFence = math.max(med * .45, q1 - iqr * 1.5);
  final upperFence = math.min(med * 1.85, q3 + iqr * 1.5);
  final filtered = working
      .where((v) => v >= lowerFence && v <= upperFence)
      .toList();
  return filtered.length >= 3 ? filtered : working;
}

List<double> v13EbayAskingValues(
  Iterable<SourceListing> listings,
  String query,
) =>
    v13CleanMarketValues(
      v13ComparableMarketListings(listings, query)
          .where((item) => item.sourceId == 'ebay_de')
          .map((item) => item.total)
          .toList(),
    );

List<SourceListing> v13ComparableMarketListings(
  Iterable<SourceListing> listings,
  String query,
) {
  final normalizedQuery = query.trim();
  return listings
      .where(
        (item) =>
            item.live &&
            (item.role == 'resale' || item.role == 'local') &&
            item.total.isFinite &&
            item.total > 0 &&
            (item.sourceId != 'ebay_de' ||
                normalizedQuery.isEmpty ||
                resaleListingMatchesQuery(normalizedQuery, item.title)),
      )
      .toList();
}

List<SourceListing> v13CleanMarketListings(
  Iterable<SourceListing> listings,
) {
  final candidates = listings
      .where((item) => item.total.isFinite && item.total > 0)
      .toList();
  final retainedCounts = <double, int>{};
  for (final value in v13CleanMarketValues(
    candidates.map((item) => item.total).toList(),
  )) {
    retainedCounts[value] = (retainedCounts[value] ?? 0) + 1;
  }

  final retained = <SourceListing>[];
  for (final item in candidates) {
    final count = retainedCounts[item.total] ?? 0;
    if (count <= 0) continue;
    retained.add(item);
    retainedCounts[item.total] = count - 1;
  }
  return retained;
}

List<SourceListing> v13QualityMarketListings(
  Iterable<SourceListing> listings,
  String query,
) =>
    v13CleanMarketListings(v13ComparableMarketListings(listings, query));

class V13MarketConfidence {
  final int score;
  final int liveCount;
  final int sourceCount;
  final int removedOutliers;
  final bool manual;

  const V13MarketConfidence({
    required this.score,
    required this.liveCount,
    required this.sourceCount,
    required this.removedOutliers,
    this.manual = false,
  });

  bool get hasLiveData => liveCount > 0;

  String label(bool english) {
    if (manual) return english ? 'Manual' : 'Manuell';
    if (!hasLiveData) return english ? 'No live data' : 'Keine Live-Daten';
    if (score >= 85) return english ? 'Very high' : 'Sehr hoch';
    if (score >= 70) return english ? 'High' : 'Hoch';
    if (score >= 45) return english ? 'Medium' : 'Mittel';
    return english ? 'Low' : 'Niedrig';
  }

  String note(bool english) {
    if (manual) {
      return english
          ? 'Sale price set manually; automatic market confidence does not rate that value.'
          : 'Verkaufspreis manuell gesetzt; die Markt-Confidence bewertet diesen Wert nicht.';
    }
    if (!hasLiveData) {
      return english
          ? 'Sandbox and reference values are deliberately excluded.'
          : 'Sandbox- und Referenzwerte werden absichtlich nicht mitgerechnet.';
    }
    final removed = removedOutliers > 0
        ? (english ? '$removedOutliers outlier(s) removed.' : '$removedOutliers Ausreißer entfernt.')
        : (english ? 'No severe outliers removed.' : 'Keine starken Ausreißer entfernt.');
    return english
        ? '$liveCount LIVE comps from $sourceCount source(s). $removed'
        : '$liveCount LIVE-Vergleiche aus $sourceCount Quelle(n). $removed';
  }
}

V13MarketConfidence v13MarketConfidence(
  List<SourceListing> listings, {
  bool manualOverride = false,
  String? query,
}) {
  final live = v13ComparableMarketListings(listings, query ?? '');
  final raw = live.map((e) => e.total).toList();
  final cleanedListings = v13QualityMarketListings(listings, query ?? '');
  final cleaned = cleanedListings.map((e) => e.total).toList();
  final used = cleanedListings.length;
  final sources = cleanedListings.map((e) => e.sourceId).toSet().length;
  final removed = raw.length > used ? raw.length - used : 0;
  if (raw.isEmpty) {
    return V13MarketConfidence(score: 0, liveCount: 0, sourceCount: 0, removedOutliers: 0, manual: manualOverride);
  }

  final sorted = [...cleaned]..sort();
  final mid = sorted.length ~/ 2;
  final median = sorted.isEmpty
      ? 0.0
      : sorted.length.isOdd
          ? sorted[mid]
          : (sorted[mid - 1] + sorted[mid]) / 2;
  final spread = sorted.length < 2 || median <= 0 ? 1.0 : (sorted.last - sorted.first) / median;
  final sample = used >= 12 ? 45 : used >= 8 ? 38 : used >= 5 ? 30 : used >= 3 ? 20 : 8;
  final consistency = spread <= .18 ? 30 : spread <= .30 ? 26 : spread <= .45 ? 20 : spread <= .65 ? 12 : 4;
  final diversity = sources >= 3 ? 15 : sources == 2 ? 11 : 7;
  final retention = raw.isEmpty ? 0.0 : used / raw.length;
  final hygiene = retention >= .85 ? 10 : retention >= .65 ? 7 : 3;
  var score = (sample + consistency + diversity + hygiene).clamp(0, 100).toInt();
  if (used < 3 && score > 34) score = 34;
  if (used < 5 && score > 69) score = 69;
  if (sources == 1 && score > 84) score = 84;
  return V13MarketConfidence(score: score, liveCount: used, sourceCount: sources, removedOutliers: removed, manual: manualOverride);
}

enum V13Decision { waiting, buy, negotiate, skip }


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

class V13FlipsPage extends StatefulWidget {
  final bool english;
  final UserPlan plan;
  final double ebayDiscount;
  final List<V13Flip> flips;
  final V13Monetization monetization;
  final ValueChanged<V13Flip> onUpdate;
  final ValueChanged<List<V13Flip>> onImportSales;
  final ValueChanged<String> onDelete;
  final ValueChanged<V13Flip> onRecheck;
  final VoidCallback onPro;
  final String initialFilter;

  const V13FlipsPage({super.key, required this.english, required this.plan, this.ebayDiscount = .10, required this.flips, required this.monetization, required this.onUpdate, required this.onImportSales, required this.onDelete, required this.onRecheck, required this.onPro, this.initialFilter = 'open'});
  @override
  State<V13FlipsPage> createState() => _V13FlipsPageState();
}

class _V13FlipsPageState extends State<V13FlipsPage> {
  late String filter;
  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter;
  }

  Future<void> _importSalesCsv() async {
    final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:const ['csv'],withData:true); if(picked==null||picked.files.isEmpty||!mounted)return;
    final bytes=picked.files.single.bytes; if(bytes==null||bytes.length>5*1024*1024){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('CSV konnte nicht gelesen werden oder ist größer als 5 MB.','CSV could not be read or exceeds 5 MB.'))));return;}
    String content;try{content=utf8.decode(bytes);}catch(_){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('CSV muss UTF-8 kodiert sein.','CSV must use UTF-8 encoding.'))));return;}
    final parsed = parseSalesCsv(content);
    var importedCount = 0;
    var duplicateCount = 0;
    if (parsed.rows.isNotEmpty) {
      final knownIds = widget.flips.map((flip) => flip.id).toSet();
      final imported = <V13Flip>[];
      for (final row in parsed.rows) {
        final id = salesCsvRowIdentity(row);
        if (!knownIds.add(id)) {
          duplicateCount++;
          continue;
        }
        imported.add(V13Flip(
          id: id,
          name: row.article,
          category: row.category,
          buy: row.purchasePrice,
          expectedAtBuy: 0,
          costs: row.costs,
          sourceCount: 0,
          confidence: 'Eigener Verkauf',
          status: 'Sold',
          createdAt: row.purchaseDate,
          checkedAt: row.purchaseDate,
          soldAt: row.saleDate,
          actualSell: row.salePrice,
          soldPlatform: row.platform,
        ));
      }
      importedCount = imported.length;
      if (imported.isNotEmpty) widget.onImportSales(imported);
    }
    if (!mounted) return;
    final message = parsed.rows.isEmpty
        ? (parsed.errors.isEmpty ? t('Keine Verkäufe gefunden.', 'No sales found.') : parsed.errors.first)
        : importedCount == 0 && duplicateCount > 0
            ? t('Keine neuen Verkäufe · $duplicateCount bereits vorhanden.', 'No new sales · $duplicateCount already imported.')
            : '$importedCount '+t('Verkäufe importiert','sales imported')+
                (duplicateCount > 0 ? ' · $duplicateCount '+t('Duplikate übersprungen.','duplicates skipped.') : '')+
                (parsed.errors.isEmpty ? '.' : ' · ${parsed.errors.length} '+t('Zeilen fehlerhaft.','invalid rows.'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
  }

  @override
  void didUpdateWidget(covariant V13FlipsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      filter = widget.initialFilter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sold = widget.flips.where((e) => e.status == 'Sold').toList();
    final saved = v148PrioritizeSaved(widget.flips);
    final archived = widget.flips.where((e) => e.isArchived).toList()
      ..sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
    final open = widget.flips.where((e) => e.isOpen).toList();
    final shown = filter == 'saved'
        ? saved
        : filter == 'archived'
            ? archived
            : filter == 'sold'
                ? sold
                : filter == 'all'
                    ? widget.flips
                    : open;
    final profit = sold.fold<double>(0, (a, b) => a + b.realizedProfit);
    final capital = open.fold<double>(0, (a, b) => a + b.buy + b.costs);
    final days = sold.map((e) => e.daysToSell).whereType<int>().toList();
    final avgDays = days.isEmpty ? null : days.reduce((a, b) => a + b) / days.length;
    final forecastRows = v13ForecastObservations(sold);
    final forecastAccuracy = forecastAccuracyByCategory(
      forecastRows,
      fallbackEbayDiscount: widget.ebayDiscount,
    );
    final latestForecast = forecastRows.isEmpty ? null : forecastRows.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        const Text('Meine Flips', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(t('Gekauft → verkauft → daraus lernt Flipwert.', 'Bought → sold → Flipwert learns from it.'), style: const TextStyle(fontSize: 12.5, color: Color(0xFF777B88))),
        const SizedBox(height: 12),
        OutlinedButton.icon(key: const ValueKey('sales-csv-import'), onPressed: _importSalesCsv, icon: const Icon(Icons.upload_file_rounded), label: Text(t('VERKÄUFE AUS CSV IMPORTIEREN', 'IMPORT SALES CSV'))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: _v13Ink, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Expanded(child: _V13DarkStat(label: t('Gewinn', 'Profit'), value: v13Euro(profit))),
            Expanded(child: _V13DarkStat(label: t('Gebunden', 'Invested'), value: v13Euro(capital))),
            Expanded(child: _V13DarkStat(label: t('Ø Verkauf', 'Avg sell'), value: avgDays == null ? '—' : '${avgDays.toStringAsFixed(0)} T')),
          ]),
        ),
        if (sold.length >= 2) ...[
          const SizedBox(height: 10),
          _V13PersonalInsight(english: widget.english, sold: sold, pro: widget.plan != UserPlan.free, onPro: widget.onPro),
        ],
        if (forecastAccuracy.isNotEmpty) ...[
          const SizedBox(height: 10),
          ForecastAccuracyCard(
            categories: forecastAccuracy,
            latest: latestForecast,
            english: widget.english,
          ),
        ],
        const SizedBox(height: 13),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<String>(segments: [ButtonSegment(value: 'saved', icon: const Icon(Icons.bookmark_outline_rounded, size: 16), label: Text(t('Merkliste', 'Saved'))), ButtonSegment(value: 'open', label: Text(t('Offen', 'Open'))), ButtonSegment(value: 'sold', label: Text(t('Verkauft', 'Sold'))), ButtonSegment(value: 'archived', icon: const Icon(Icons.archive_outlined, size: 16), label: Text(t('Archiv', 'Archive'))), ButtonSegment(value: 'all', label: Text(t('Alle', 'All')))], selected: {filter}, onSelectionChanged: (v) => setState(() => filter = v.first))),
        const SizedBox(height: 12),
        if (filter == 'saved' && saved.isNotEmpty) ...[
          _V149WatchlistAttention(
            english: widget.english,
            saved: saved,
            onRecheck: widget.onRecheck,
          ),
          const SizedBox(height: 10),
        ],
        if (shown.isEmpty)
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: Column(children: [const Icon(Icons.inventory_2_outlined, size: 38, color: _v13Primary), const SizedBox(height: 9), Text(t('Noch nichts hier', 'Nothing here yet'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 3), Text(t('Beim Deal einmal auf „Gekauft“ tippen – der Rest wird übernommen.', 'Tap “Bought” once on a deal – the rest is filled automatically.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: Color(0xFF777B88))) ]))
        else
          for (var i = 0; i < shown.length; i++) ...[
            _V13FlipCard(english: widget.english, flip: shown[i], onUpdate: widget.onUpdate, onDelete: widget.onDelete, onRecheck: widget.onRecheck),
            if (widget.plan == UserPlan.free && i == 2) ...[const SizedBox(height: 8), V13BannerAd(monetization: widget.monetization)],
            const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class _V149WatchlistAttention extends StatelessWidget {
  final bool english;
  final List<V13Flip> saved;
  final ValueChanged<V13Flip> onRecheck;
  const _V149WatchlistAttention({required this.english, required this.saved, required this.onRecheck});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final stale = saved.where((e) => now.difference(e.checkedAt).inHours >= 24).toList()
      ..sort((a, b) => a.checkedAt.compareTo(b.checkedAt));
    final oldest = stale.isEmpty ? saved.first : stale.first;
    final freshCount = saved.length - stale.length;
    final title = stale.isEmpty
        ? t('Merkliste aktuell', 'Watchlist up to date')
        : t('${stale.length} Deal${stale.length == 1 ? '' : 's'} neu prüfen', '${stale.length} deal${stale.length == 1 ? '' : 's'} to recheck');
    final subtitle = stale.isEmpty
        ? t('Alle gespeicherten Deals wurden in den letzten 24 Std. geprüft.', 'All saved deals were checked within the last 24h.')
        : t('$freshCount von ${saved.length} aktuell · ältester Check ${v147AgeLabel(oldest.checkedAt, false)}.', '$freshCount of ${saved.length} current · oldest check ${v147AgeLabel(oldest.checkedAt, true)}.');
    return Container(
      key: const ValueKey('v149-watchlist-attention'),
      padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
      decoration: BoxDecoration(
        color: stale.isEmpty ? const Color(0xFFF2F7F4) : const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: stale.isEmpty ? const Color(0x22087F5B) : const Color(0x33C47B00)),
      ),
      child: Row(children: [
        Icon(stale.isEmpty ? Icons.check_circle_outline_rounded : Icons.notifications_active_outlined, color: stale.isEmpty ? const Color(0xFF087F5B) : const Color(0xFFC47B00), size: 21),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF707481))),
        ])),
        if (stale.isNotEmpty)
          TextButton(
            key: const ValueKey('v149-recheck-oldest'),
            onPressed: () => onRecheck(oldest),
            child: Text(t(stale.length > 1 ? 'NÄCHSTEN PRÜFEN' : 'PRÜFEN', stale.length > 1 ? 'CHECK NEXT' : 'CHECK')),
          ),
      ]),
    );
  }
}

class _V13DarkStat extends StatelessWidget {
  final String label;
  final String value;
  const _V13DarkStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 7), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Color(0xFFB8BACC), fontSize: 9.5))]));
}

class _V13PersonalInsight extends StatelessWidget {
  final bool english;
  final List<V13Flip> sold;
  final bool pro;
  final VoidCallback onPro;
  const _V13PersonalInsight({required this.english, required this.sold, required this.pro, required this.onPro});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, List<V13Flip>>{};
    for (final f in sold) { byCategory.putIfAbsent(f.category, () => []).add(f); }
    final best = byCategory.entries.toList()..sort((a, b) => b.value.fold<double>(0, (x, y) => x + y.realizedRoi).compareTo(a.value.fold<double>(0, (x, y) => x + y.realizedRoi)));
    final bestName = best.isEmpty ? '—' : best.first.key;
    return Material(
      color: const Color(0xFFEDEDFC),
      borderRadius: BorderRadius.circular(19),
      child: ListTile(
        leading: const Icon(Icons.psychology_alt_rounded, color: _v13Primary),
        title: Text(t('Dein Flip-Muster', 'Your flip pattern'), style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(pro ? t('Stärkste Kategorie bisher: $bestName · ${sold.length} echte Verkäufe fließen ein.', 'Strongest category so far: $bestName · ${sold.length} real sales are used.') : t('${sold.length} Verkäufe gesammelt · PRO nutzt sie für persönliche Empfehlungen.', '${sold.length} sales collected · PRO uses them for personal recommendations.'), style: const TextStyle(fontSize: 11.5)),
        trailing: pro ? const Icon(Icons.check_circle_rounded, color: Color(0xFF087F5B)) : TextButton(onPressed: onPro, child: const Text('PRO')),
      ),
    );
  }
}

class _V13FlipCard extends StatelessWidget {
  final bool english;
  final V13Flip flip;
  final ValueChanged<V13Flip> onUpdate;
  final ValueChanged<String> onDelete;
  final ValueChanged<V13Flip> onRecheck;
  const _V13FlipCard({required this.english, required this.flip, required this.onUpdate, required this.onDelete, required this.onRecheck});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final sold = flip.status == 'Sold';
    final saved = flip.isSaved;
    final archived = flip.isArchived;
    final age = DateTime.now().difference(flip.checkedAt);
    final stale = saved && age.inHours >= 24;
    final stateLabel = sold
        ? t('verkauft', 'sold')
        : archived
            ? t('archiviert', 'archived')
            : saved
                ? t('gemerkt', 'saved')
                : flip.status == 'Listed'
                    ? t('inseriert', 'listed')
                    : t('gekauft', 'bought');
    final iconColor = sold
        ? const Color(0xFF087F5B)
        : archived
            ? const Color(0xFF7A7E8B)
            : saved
                ? const Color(0xFFC47B00)
                : _v13Primary;
    return Container(
      key: ValueKey('v147-flip-${flip.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: stale ? const Color(0x33C47B00) : const Color(0xFFE9EAF0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: iconColor.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: Icon(sold ? Icons.check_rounded : archived ? Icons.archive_outlined : saved ? Icons.bookmark_rounded : Icons.inventory_2_outlined, color: iconColor)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(flip.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${flip.category} · $stateLabel', style: const TextStyle(fontSize: 10.5, color: Color(0xFF7A7E8B)))])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(sold ? v13Euro(flip.realizedProfit) : v13Euro(flip.buy), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: sold && flip.realizedProfit >= 0 ? const Color(0xFF087F5B) : _v13Ink)), Text(sold ? '${flip.daysToSell ?? 0} ${t('Tage', 'days')}' : saved || archived ? t('Angebot', 'asking') : t('Einkauf', 'buy'), style: const TextStyle(fontSize: 9.5, color: Color(0xFF8B8E9A)))]),
          if (saved || archived) ...[
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              key: ValueKey('v148-menu-${flip.id}'),
              tooltip: t('Deal verwalten', 'Manage deal'),
              onSelected: (value) => _handleMenu(context, value),
              itemBuilder: (_) => [
                if (flip.sourceUrl.isNotEmpty) PopupMenuItem(value: 'listing', child: Text(t('Inserat öffnen', 'Open listing'))),
                if (saved) PopupMenuItem(value: 'archive', child: Text(t('Archivieren', 'Archive'))),
                if (archived) PopupMenuItem(value: 'restore', child: Text(t('Zur Merkliste', 'Restore to saved'))),
                PopupMenuItem(value: 'delete', child: Text(t('Löschen', 'Delete'))),
              ],
            ),
          ],
        ]),
        if (saved || archived || (!sold && flip.maxBuyAtCheck > 0)) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (flip.maxBuyAtCheck > 0) _V13Pill(text: 'MAX ${v13Euro(flip.maxBuyAtCheck)}', foreground: _v13Primary, background: const Color(0xFFEDEDFC)),
            if (flip.profitAtCheck != 0) _V13Pill(text: '${flip.profitAtCheck >= 0 ? '+' : ''}${v13Euro(flip.profitAtCheck)}', foreground: flip.profitAtCheck >= 0 ? const Color(0xFF087F5B) : const Color(0xFFC33A46), background: const Color(0xFFF4F5F8)),
            if (flip.roiAtCheck != 0) _V13Pill(text: 'ROI ${flip.roiAtCheck.toStringAsFixed(0)} %', foreground: _v13Ink, background: const Color(0xFFF4F5F8)),
            if (flip.confidenceScore > 0) _V13Pill(text: '${flip.confidenceScore}/100', foreground: _v13Ink, background: const Color(0xFFF4F5F8)),
          ]),
          const SizedBox(height: 6),
          Row(key: const ValueKey('v147-snapshot-age'), children: [
            Icon(stale ? Icons.schedule_rounded : Icons.history_rounded, size: 14, color: stale ? const Color(0xFFC47B00) : const Color(0xFF7A7E8B)),
            const SizedBox(width: 5),
            Expanded(child: Text(
              stale
                  ? t('Check ${v147AgeLabel(flip.checkedAt, false)} · Preise können veraltet sein.', 'Checked ${v147AgeLabel(flip.checkedAt, true)} · prices may be stale.')
                  : t('Check ${v147AgeLabel(flip.checkedAt, false)}.', 'Checked ${v147AgeLabel(flip.checkedAt, true)}.'),
              style: TextStyle(fontSize: 10.2, color: stale ? const Color(0xFFC47B00) : const Color(0xFF7A7E8B), fontWeight: stale ? FontWeight.w800 : FontWeight.w500),
            )),
          ]),
        ],
        if (saved) ...[
          const SizedBox(height: 8),
          DealAlertToggle(flipId: flip.id, english: english),
        ],
        if (!sold && !archived) ...[
          const SizedBox(height: 10),
          if (saved)
            Row(children: [
              Expanded(child: OutlinedButton.icon(key: const ValueKey('v148-recheck-deal'), onPressed: () => onRecheck(flip), icon: const Icon(Icons.refresh_rounded, size: 17), label: Text(t('NEU PRÜFEN', 'RECHECK')))),
              const SizedBox(width: 7),
              Expanded(child: FilledButton.icon(key: const ValueKey('v147-mark-bought'), onPressed: () => onUpdate(flip.copyWith(status: 'Bought', createdAt: DateTime.now())), icon: const Icon(Icons.inventory_2_rounded, size: 17), label: Text(t('GEKAUFT', 'BOUGHT')))),
            ])
          else
            Row(children: [
              if (flip.status == 'Bought') Expanded(child: OutlinedButton(onPressed: () => onUpdate(flip.copyWith(status: 'Listed', listedAt: DateTime.now())), child: Text(t('Inseriert', 'Listed')))),
              if (flip.status == 'Bought') const SizedBox(width: 7),
              Expanded(child: FilledButton(onPressed: () => _soldDialog(context), child: Text(t('Verkauft', 'Sold')))),
            ]),
        ],
      ]),
    );
  }

  Future<void> _handleMenu(BuildContext context, String value) async {
    switch (value) {
      case 'listing':
        await _openListing();
        return;
      case 'archive':
        onUpdate(flip.copyWith(status: 'Archived'));
        return;
      case 'restore':
        onUpdate(flip.copyWith(status: 'Saved'));
        return;
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(t('Deal löschen?', 'Delete deal?')),
            content: Text(t('Der gespeicherte Snapshot wird dauerhaft von diesem Gerät entfernt.', 'The saved snapshot will be permanently removed from this device.')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(t('Abbrechen', 'Cancel'))),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(t('Löschen', 'Delete'))),
            ],
          ),
        );
        if (ok == true) onDelete(flip.id);
        return;
    }
  }

  Future<void> _openListing() async {
    final uri = Uri.tryParse(flip.sourceUrl);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _soldDialog(BuildContext context) async {
    final price = TextEditingController();
    var platform = 'eBay';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: Text(t('Verkauf abschließen', 'Finish sale')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: price, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: t('Verkaufspreis', 'Sale price'), suffixText: '€')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: platform, decoration: InputDecoration(labelText: t('Verkauft über', 'Sold on')), items: ['eBay', 'Kleinanzeigen', 'Vinted', 'Amazon', 'rebuy', t('Sonstiges', 'Other')].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setDialog(() => platform = v ?? platform)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t('Abbrechen', 'Cancel'))), FilledButton(onPressed: () { final value = v13Money(price.text); if (value > 0) Navigator.pop(dialogContext, {'price': value, 'platform': platform}); }, child: Text(t('Speichern', 'Save')))],
      )),
    );
    price.dispose();
    if (result != null) {
      onUpdate(flip.copyWith(status: 'Sold', soldAt: DateTime.now(), actualSell: result['price'] as double, soldPlatform: result['platform'] as String));
    }
  }
}

class V13SettingsPage extends StatefulWidget {
  final bool english;
  final String backend;
  final double targetRoi;
  final double minProfit;
  final double ebayDiscount;
  final UserPlan plan;
  final V13TaxMode taxMode;
  final List<PriceSource> sources;
  final V13Monetization monetization;
  final ValueChanged<bool> onLanguage;
  final ValueChanged<double> onRoi;
  final ValueChanged<double> onMinProfit;
  final ValueChanged<double> onEbayDiscount;
  final ValueChanged<V13TaxMode> onTaxMode;
  final ValueChanged<String> onBackend;
  final ValueChanged<List<PriceSource>> onSources;
  final ValueChanged<UserPlan> onPlanPreview;

  const V13SettingsPage({super.key, required this.english, required this.backend, required this.targetRoi, required this.minProfit, this.ebayDiscount = .10, required this.plan, required this.taxMode, required this.sources, required this.monetization, required this.onLanguage, required this.onRoi, required this.onMinProfit, required this.onEbayDiscount, required this.onTaxMode, required this.onBackend, required this.onSources, required this.onPlanPreview});
  @override
  State<V13SettingsPage> createState() => _V13SettingsPageState();
}

class _V13SettingsPageState extends State<V13SettingsPage> {
  late double roi;
  late double minProfit;
  late double ebayDiscount;
  late bool english;
  String t(String de, String en) => english ? en : de;

  @override
  void initState() {
    super.initState();
    roi = widget.targetRoi;
    minProfit = widget.minProfit;
    ebayDiscount = widget.ebayDiscount;
    english = widget.english;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('Einstellungen', 'Settings'), style: const TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 5, 18, 28), children: [
          _V13Section(title: t('Wann ist ein Flip gut?', 'When is a flip good?'), subtitle: t('Einmal einstellen – danach rechnet Flipwert automatisch.', 'Set once – Flipwert calculates automatically after that.')),
          const SizedBox(height: 9),
          Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Column(children: [
            Row(children: [Text(t('Mindest-ROI', 'Minimum ROI'), style: const TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text('${roi.toStringAsFixed(0)} %', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: _v13Primary))]),
            Slider(value: roi, min: 10, max: 100, divisions: 18, onChanged: (v) => setState(() => roi = v), onChangeEnd: widget.onRoi),
            const Divider(),
            Row(children: [Text(t('Mindestgewinn', 'Minimum profit'), style: const TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text(v13Euro(minProfit), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: _v13Primary))]),
            Slider(value: minProfit, min: 0, max: 100, divisions: 20, onChanged: (v) => setState(() => minProfit = v), onChangeEnd: widget.onMinProfit),
            const Divider(),
            Row(children: [Text(t('eBay-Angebotsabschlag', 'eBay asking discount'), style: const TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text('${(ebayDiscount * 100).toStringAsFixed(0)} %', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: _v13Primary))]),
            Slider(key: const ValueKey('ebay-discount-slider'), value: ebayDiscount, min: 0, max: .40, divisions: 40, onChanged: (v) => setState(() => ebayDiscount = v), onChangeEnd: widget.onEbayDiscount),
            Text(t('Ausgangswert für aktive eBay-Angebote. Echte Verkäufe justieren ihn je Kategorie automatisch nach.', 'Base value for active eBay listings. Actual sales automatically refine it per category.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF7B7F8C))),
          ])),
          const SizedBox(height: 18),
          _V13Section(title: 'Flipwert PRO'),
          const SizedBox(height: 8),
          _V13ProCard(english: english, active: widget.plan != UserPlan.free, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => V13Paywall(english: english, monetization: widget.monetization)))),
          const SizedBox(height: 18),
          _V13Section(title: t('Preisquellen', 'Price sources')),
          const SizedBox(height: 8),
          Material(color: Colors.white, borderRadius: BorderRadius.circular(19), child: ListTile(leading: const Icon(Icons.storefront_outlined, color: _v13Primary), title: Text(t('${widget.sources.where((e) => e.enabled).length} Quellen aktiv', '${widget.sources.where((e) => e.enabled).length} sources enabled'), style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(t('Ein-/ausschalten', 'Enable/disable')), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => V13SourcesPage(english: english, sources: widget.sources, onChanged: widget.onSources))))),
          const SizedBox(height: 18),
          _V13Section(title: t('Kaufmännisch', 'Business')),
          const SizedBox(height: 8),
          DropdownButtonFormField<V13TaxMode>(initialValue: widget.taxMode, decoration: InputDecoration(labelText: t('Steuerprofil', 'Tax profile')), items: V13TaxMode.values.map((e) => DropdownMenuItem(value: e, child: Text(v13TaxLabel(e, english)))).toList(), onChanged: (v) { if (v != null) widget.onTaxMode(v); }),
          const SizedBox(height: 5),
          Text(t('Das Profil dient der Einordnung. Flipwert zieht aktuell keine Steuer automatisch vom Gewinn ab.', 'The profile is contextual. Flipwert does not currently deduct taxes automatically.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF7B7F8C))),
          const SizedBox(height: 18),
          _V13Section(title: t('Sprache & Datenschutz', 'Language & privacy')),
          const SizedBox(height: 8),
          SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('Deutsch')), ButtonSegment(value: true, label: Text('English'))], selected: {english}, onSelectionChanged: (v) { setState(() => english = v.first); widget.onLanguage(v.first); }),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: widget.monetization.showPrivacyOptions, icon: const Icon(Icons.privacy_tip_outlined), label: Text(t('Werbe-Datenschutz verwalten', 'Manage ad privacy'))),
          const SizedBox(height: 15),
          ExpansionTile(tilePadding: EdgeInsets.zero, leading: const Icon(Icons.build_outlined), title: Text(t('Für Profis & Entwickler', 'For pros & developers'), style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(t('Im Alltag nicht nötig', 'Not needed day to day'), style: const TextStyle(fontSize: 11.5)), children: [
            TextFormField(initialValue: widget.backend, decoration: InputDecoration(labelText: t('Eigener Flipwert-Server', 'Custom Flipwert server'), hintText: SourceRegistry.defaultBackend), onFieldSubmitted: widget.onBackend),
            const SizedBox(height: 9),
            Text(t('SAFE RECOVERY 2: Test-AdMob wird nur nach einer Werbe-/Datenschutz-Aktion geladen. Banner bleiben in dieser Version deaktiviert.', 'SAFE RECOVERY 2: Test AdMob loads only after an ad/privacy action. Banner ads remain disabled in this build.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF737786))),
            const SizedBox(height: 9),
            SegmentedButton<UserPlan>(segments: const [ButtonSegment(value: UserPlan.free, label: Text('FREE')), ButtonSegment(value: UserPlan.pro, label: Text('PRO TEST'))], selected: {widget.plan == UserPlan.free ? UserPlan.free : UserPlan.pro}, onSelectionChanged: (v) => widget.onPlanPreview(v.first)),
          ]),
        ]),
      );
}

class _V13Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _V13Section({required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900)), if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF777B88)))]]);
}

class _V13ProCard extends StatelessWidget {
  final bool english;
  final bool active;
  final VoidCallback onTap;
  const _V13ProCard({required this.english, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(21),
        child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(21), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_v13Ink, Color(0xFF5657DB)]), borderRadius: BorderRadius.circular(21)), child: Row(children: [const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 29), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(active ? (english ? 'PRO active' : 'PRO aktiv') : 'Flipwert PRO', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)), Text(english ? 'No ads · Deep Check · personal learning' : 'Werbefrei · Deep Check · persönliches Lernen', style: const TextStyle(color: Color(0xFFD4D5EA), fontSize: 10.8))])), const Icon(Icons.chevron_right_rounded, color: Colors.white)]))),
      );
}

class V13Paywall extends StatefulWidget {
  final bool english;
  final V13Monetization monetization;
  const V13Paywall({super.key, required this.english, required this.monetization});
  @override
  State<V13Paywall> createState() => _V13PaywallState();
}

class _V13PaywallState extends State<V13Paywall> {
  String t(String de, String en) => widget.english ? en : de;
  @override
  void initState() { super.initState(); widget.monetization.addListener(_refresh); unawaited(widget.monetization.init()); }
  void _refresh() { if (mounted) setState(() {}); }
  @override
  Widget build(BuildContext context) {
    final month = widget.monetization.product(V13Monetization.monthlyId);
    final year = widget.monetization.product(V13Monetization.yearlyId);
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 30), children: [
        const Icon(Icons.workspace_premium_rounded, size: 48, color: _v13Primary),
        const SizedBox(height: 10),
        Text('Flipwert PRO', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
        const SizedBox(height: 6),
        Text(t('Mehr Sicherheit, weniger Handarbeit – ohne Werbung.', 'More confidence, less manual work – without ads.'), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF707483))),
        const SizedBox(height: 20),
        for (final item in [t('Deep Check mit konservativem Exit & Risiko', 'Deep Check with conservative exit & risk'), t('Persönliche Empfehlungen aus deinen echten Verkäufen', 'Personal recommendations from your real sales'), t('Kapitaltempo & bessere Verkaufsanalyse', 'Capital speed & better sale analysis'), t('Keine Werbebanner', 'No ad banners')]) Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(children: [const Icon(Icons.check_circle_rounded, color: Color(0xFF087F5B), size: 20), const SizedBox(width: 8), Expanded(child: Text(item, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)))])),
        const SizedBox(height: 15),
        _V13PlanChoice(title: t('Jährlich', 'Yearly'), price: year?.price ?? '39,99 € / Jahr · ≈ 3,33 € / Monat', badge: t('33 % SPAREN', 'SAVE 33%'), enabled: year != null, onTap: year == null ? null : () => widget.monetization.buy(year)),
        const SizedBox(height: 8),
        _V13PlanChoice(title: t('Monatlich', 'Monthly'), price: month?.price ?? '4,99 € / Monat', enabled: month != null, onTap: month == null ? null : () => widget.monetization.buy(month)),
        const SizedBox(height: 10),
        if (!widget.monetization.billingAvailable || (month == null && year == null))
          Text(t('Play Billing wird erst auf dieser Seite geladen. Produkte erscheinen nur, wenn sie im passenden Google-Play-Testtrack eingerichtet sind.', 'Play Billing loads only on this page. Products appear only when configured in the matching Google Play test track.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, color: Color(0xFF7A7E8B))),
        TextButton(onPressed: widget.monetization.restore, child: Text(t('Käufe wiederherstellen', 'Restore purchases'))),
        const SizedBox(height: 6),
        Text(t('Vor produktivem Start werden Käufe serverseitig verifiziert.', 'Purchases will be server-verified before production launch.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, color: Color(0xFF8A8E9B))),
      ]),
    );
  }
  @override
  void dispose() { widget.monetization.removeListener(_refresh); super.dispose(); }
}

class _V13PlanChoice extends StatelessWidget {
  final String title;
  final String price;
  final String? badge;
  final bool enabled;
  final VoidCallback? onTap;
  const _V13PlanChoice({required this.title, required this.price, required this.enabled, this.badge, this.onTap});
  @override
  Widget build(BuildContext context) => Material(color: enabled ? Colors.white : const Color(0xFFF0F1F4), borderRadius: BorderRadius.circular(18), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: enabled ? const Color(0xFFDADCE8) : const Color(0xFFE2E3E8)), borderRadius: BorderRadius.circular(18)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), if (badge != null) ...[const SizedBox(width: 6), _V13Pill(text: badge!, foreground: const Color(0xFF087F5B), background: const Color(0xFFE1F5EE))]]), const SizedBox(height: 2), Text(price, style: const TextStyle(color: Color(0xFF656978), fontSize: 12))])), Icon(enabled ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded)]))));
}

class V13BannerAd extends StatelessWidget {
  final V13Monetization monetization;
  const V13BannerAd({super.key, required this.monetization});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _V13Pill extends StatelessWidget {
  final String text;
  final Color foreground;
  final Color background;
  const _V13Pill({required this.text, required this.foreground, required this.background});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)), child: Text(text, style: TextStyle(color: foreground, fontSize: 8.5, fontWeight: FontWeight.w900)));
}

Color _sourceColor(PriceSource source) {
  final hex = int.tryParse('FF${source.colorHex}', radix: 16);
  return Color(hex ?? 0xFF5146E5);
}

IconData _sourceIcon(String id) {
  switch (id) {
    case 'ebay_de': return Icons.sell_outlined;
    case 'kleinanzeigen': return Icons.location_on_outlined;
    case 'vinted': return Icons.checkroom_outlined;
    case 'amazon_de': return Icons.shopping_bag_outlined;
    case 'mediamarkt': return Icons.devices_other_outlined;
    case 'saturn': return Icons.laptop_chromebook_outlined;
    case 'idealo': return Icons.compare_arrows_rounded;
    case 'geizhals': return Icons.price_check_rounded;
    case 'rebuy': return Icons.recycling_rounded;
    case 'backmarket': return Icons.autorenew_rounded;
    default: return Icons.open_in_new_rounded;
  }
}
Future<bool> _syncDealAlertLifecycle(
  V13Flip previous,
  V13Flip current,
) {
  final removeAlert = previous.isSaved &&
      !current.isSaved &&
      !current.isArchived;
  if (!removeAlert) return Future<bool>.value(true);
  return DealAlertStore().remove(current.id);
}
