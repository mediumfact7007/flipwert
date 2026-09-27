import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'buyback_summary.dart';

/// Compact, user-facing decision card for the two realistic exit paths.
///
/// The card deliberately consumes an already trusted summary instead of raw
/// provider payloads, keeping market-quality filtering outside the widget.
class BuybackComparisonCard extends StatelessWidget {
  const BuybackComparisonCard({super.key, required this.summary, this.locale = 'de', this.now});

  final BuybackComparisonSummary summary;
  final String locale;
  final DateTime? now;

  bool get _de => locale.toLowerCase().startsWith('de');
  String _money(double value) => '${value.toStringAsFixed(0)} €';
  String _roi(double value) => '${value.toStringAsFixed(0)} %';

  String _checkedAt(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final age = (now ?? DateTime.now()).toUtc().difference(value.toUtc());
    final ageText = age.isNegative || age.inMinutes < 1
        ? (_de ? 'gerade eben' : 'just now')
        : age.inMinutes < 60
            ? (_de ? 'vor ${age.inMinutes} Min.' : '${age.inMinutes} min ago')
            : (_de ? 'vor ${age.inHours} Std.' : '${age.inHours} h ago');
    return _de ? 'Preis geprüft: $day.$month. · $hour:$minute Uhr · $ageText' : 'Price checked: $month/$day · $hour:$minute local time · $ageText';
  }

  String _validUntil(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return _de ? 'Angebot gültig bis: $day.$month. · $hour:$minute Uhr' : 'Offer valid until: $month/$day · $hour:$minute local time';
  }

  String get _matchQuality {
    final percent = (summary.offer.matchConfidence * 100).round().clamp(0, 100);
    return _de ? 'Produkt-Treffer: $percent %' : 'Product match: $percent%';
  }

  bool get _hasSafeOfferUrl => summary.offer.isEligibleForComparison;
  Future<void> _openOffer() async {
    if (!_hasSafeOfferUrl) return;
    await launchUrl(summary.offer.offerUrl, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final marginDifference = summary.instantMargin - summary.privateMargin;
    final instantBetter = marginDifference > 0;
    final equalProfit = marginDifference.abs() < 0.01;
    final noProfitableExit = summary.instantMargin <= 0 && summary.privateMargin <= 0;
    final theme = Theme.of(context);
    final provisionalSuffix = summary.offer.requiresInspection ? (_de ? ' (vor Prüfung)' : ' (before inspection)') : '';
    final recommendation = noProfitableExit
        ? (_de ? 'Kein positiver Exit – Gesamteinsatz zu hoch' : 'No profitable exit – total investment is too high')
        : equalProfit
            ? (_de ? 'Gleicher Gewinn – Sofortankauf spart Zeit' : 'Same profit – instant buyback saves time')
            : instantBetter
                ? (_de ? 'Sofortankauf: ${_money(marginDifference)} mehr Gewinn$provisionalSuffix' : 'Instant buyback: ${_money(marginDifference)} more profit$provisionalSuffix')
                : (_de ? 'Privatverkauf: ${_money(-marginDifference)} mehr Gewinn' : 'Private sale: ${_money(-marginDifference)} more profit');
    final instantValue = summary.offer.requiresInspection ? '${_money(summary.offer.price)}*' : _money(summary.offer.price);
    final profitLabel = _de ? 'Mehr Gewinn' : 'Higher profit';

    return Card(
      key: const ValueKey('buyback-comparison-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_de ? 'Privat oder sofort verkaufen?' : 'Sell privately or instantly?', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(_de ? 'Flipwert zeigt dir Erlös, Gewinn und den Preis für mehr Bequemlichkeit.' : 'Flipwert shows proceeds, profit and the price of extra convenience.', style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(_de ? 'Basis: Gesamteinsatz ${_money(summary.purchasePrice)}' : 'Basis: total investment ${_money(summary.purchasePrice)}', key: const ValueKey('buyback-purchase-basis'), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
          Text(
            _de
                ? 'Gesamteinsatz = Einkaufspreis + eingetragene Zusatzkosten.'
                : 'Total investment = purchase price + entered additional costs.',
            key: const ValueKey('buyback-cost-basis-note'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('buyback-recommendation'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: noProfitableExit ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(noProfitableExit ? Icons.warning_amber_rounded : Icons.auto_awesome_rounded, size: 16, color: noProfitableExit ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 6),
              Flexible(child: Text(recommendation, style: theme.textTheme.labelMedium?.copyWith(color: noProfitableExit ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w800))),
            ]),
          ),
          const SizedBox(height: 14),
          _ExitRow(title: _de ? 'Privat verkaufen' : 'Sell privately', value: _money(summary.privateMarketValue), detail: '${_de ? 'Gewinn' : 'Profit'} ${_money(summary.privateMargin)} · ROI ${_roi(summary.privateRoi)}', emphasized: !noProfitableExit && !instantBetter && !equalProfit, emphasisLabel: profitLabel),
          const Divider(height: 22),
          _ExitRow(title: _de ? 'Sofortankauf' : 'Instant buyback', value: instantValue, detail: '${summary.offer.providerName} · ${_de ? 'Geldauszahlung' : 'Money payout'} · ${_de ? 'Gewinn' : 'Profit'} ${_money(summary.instantMargin)} · ROI ${_roi(summary.instantRoi)}', emphasized: !noProfitableExit && instantBetter, emphasisLabel: profitLabel),
          if (summary.offer.hasMandatoryDeductions) ...[
            const SizedBox(height: 6),
            Text(
              _de
                  ? 'Nettoauszahlung: ${_money(summary.offer.price)} nach ${_money(summary.offer.mandatoryDeductionsEur)} gemeldeten Pflichtabzügen vom Anbieterpreis ${_money(summary.offer.displayedListedPrice)}.'
                  : 'Net payout: ${_money(summary.offer.price)} after ${_money(summary.offer.mandatoryDeductionsEur)} reported mandatory deductions from the listed ${_money(summary.offer.displayedListedPrice)}.',
              key: const ValueKey('buyback-mandatory-deductions-note'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (summary.offer.expiresAt != null) ...[
            const SizedBox(height: 6),
            Text(
              _validUntil(summary.offer.expiresAt!),
              key: const ValueKey('buyback-expiry-note'),
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (summary.appliedSafetyReserve > 0) ...[
            const SizedBox(height: 6),
            Text(
              _de
                  ? 'Konservativ gerechnet: ${_money(summary.effectiveInstantProceeds)} Ankaufserlös nach ${_money(summary.appliedSafetyReserve)} Sicherheitsabschlag.'
                  : 'Conservative calculation: ${_money(summary.effectiveInstantProceeds)} buyback proceeds after a ${_money(summary.appliedSafetyReserve)} safety reserve.',
              key: const ValueKey('buyback-safety-reserve-note'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (summary.convenienceGap > 0) ...[
            const SizedBox(height: 12),
            Text(_de ? 'Zeit-vs.-Geld: Sofortankauf kostet dich hier ca. ${_money(summary.convenienceGap)} möglichen Erlös.' : 'Time vs money: instant buyback costs about ${_money(summary.convenienceGap)} in potential proceeds here.', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 6),
          Text(_checkedAt(summary.offer.checkedAt), key: const ValueKey('buyback-checked-at'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(_matchQuality, key: const ValueKey('buyback-match-quality'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_de ? 'Privatwert = aktueller Flipwert-Marktwert. Ankauf = frisches, qualitätsgefiltertes Anbieterangebot.' : 'Private value = current Flipwert market value. Buyback = fresh, quality-filtered provider offer.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (summary.offer.requiresInspection) ...[
            const SizedBox(height: 6),
            Text(_de ? '* Vorläufiger Ankaufspreis: Der Anbieter kann ihn nach Prüfung ändern.' : '* Provisional buyback price: the provider may change it after inspection.', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: OutlinedButton.icon(key: const ValueKey('buyback-open-offer'), onPressed: _hasSafeOfferUrl ? _openOffer : null, icon: const Icon(Icons.open_in_new_rounded, size: 17), label: Text(_hasSafeOfferUrl ? (_de ? 'Angebot bei ${summary.offer.providerName} öffnen' : 'Open offer at ${summary.offer.providerName}') : (_de ? 'Angebotslink nicht verfügbar' : 'Offer link unavailable')))),
        ]),
      ),
    );
  }
}

class _ExitRow extends StatelessWidget {
  const _ExitRow({required this.title, required this.value, required this.detail, required this.emphasized, required this.emphasisLabel});
  final String title;
  final String value;
  final String detail;
  final bool emphasized;
  final String emphasisLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(child: Text(title, style: theme.textTheme.titleSmall)),
          if (emphasized) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle_rounded, size: 17, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Flexible(child: Text(emphasisLabel, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800))),
          ],
        ]),
        const SizedBox(height: 3),
        Text(detail, style: theme.textTheme.bodySmall),
      ])),
      const SizedBox(width: 12),
      Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
    ]);
  }
}
