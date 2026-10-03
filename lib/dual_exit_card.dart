import 'package:flutter/material.dart';

import 'dual_exit.dart';
import 'resale_estimate.dart';

class DualExitCard extends StatelessWidget {
  final DualExitComparison comparison;
  final String? instantProvider;
  final bool instantRequiresInspection;
  final bool english;

  const DualExitCard({
    super.key,
    required this.comparison,
    required this.instantProvider,
    required this.instantRequiresInspection,
    this.english = false,
  });

  String _money(double value) {
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(2).split('.');
    final digits = fixed.first;
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write('.');
      grouped.write(digits[i]);
    }
    return '${negative ? '-' : ''}$grouped,${fixed.last} €';
  }

  String _confidence(ResaleEstimateConfidence value) => switch (value) {
        ResaleEstimateConfidence.high => english ? 'High' : 'Hoch',
        ResaleEstimateConfidence.medium => english ? 'Medium' : 'Mittel',
        ResaleEstimateConfidence.low => english ? 'Low' : 'Niedrig',
      };

  String _evidence(ResaleEstimate estimate) {
    final parts = <String>[];
    if (estimate.ownSalesUsed > 0) {
      final exact = estimate.ownSalesScope == ResaleOwnSalesScope.exactModel;
      if (english) {
        final label = exact ? 'model sale' : 'category sale';
        parts.add(
            '${estimate.ownSalesUsed} own $label${estimate.ownSalesUsed == 1 ? '' : 's'}');
      } else {
        final singular = exact ? 'Modellverkauf' : 'Kategorieverkauf';
        final plural = exact ? 'Modellverkäufe' : 'Kategorieverkäufe';
        parts.add(estimate.ownSalesUsed == 1
            ? '1 eigener $singular'
            : '${estimate.ownSalesUsed} eigene $plural');
      }
    }
    if (estimate.activeEbayListingsUsed > 0) {
      final count = estimate.activeEbayListingsUsed;
      parts.add(english
          ? '$count active eBay listing${count == 1 ? '' : 's'}'
          : '$count aktive eBay-${count == 1 ? 'Anzeige' : 'Angebote'}');
      final percent = estimate.appliedEbayDiscount * 100;
      final formatted = percent == percent.roundToDouble()
          ? percent.toStringAsFixed(0)
          : percent.toStringAsFixed(1).replaceAll('.', ',');
      parts.add(english ? '$formatted% discount' : '$formatted % Abschlag');
    }
    if (parts.isEmpty) {
      return english ? 'Buyback floor only' : 'Nur Ankauf-Untergrenze';
    }
    return parts.join(' · ');
  }

  Widget _exitPanel({
    required BuildContext context,
    required Key key,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Container(
      key: key,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          ...children,
        ],
      ),
    );
  }

  Widget _value(BuildContext context, String label, String value,
      {Key? key, bool strong = false}) {
    final style = strong
        ? Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w900)
        : Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        Text(value, key: key, style: style),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estimate = comparison.marketEstimate;
    final marketProfit = comparison.marketProfit;
    return Card(
      key: const ValueKey('dual-exit-card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            english ? 'Two exits for this deal' : 'Zwei Ausstiege für diesen Deal',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            english
                ? 'Profit after purchase and all entered fees, shipping and travel costs.'
                : 'Gewinn nach Einkauf und allen eingetragenen Gebühren-, Versand- und Fahrtkosten.',
            key: const ValueKey('dual-exit-cost-basis'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: _exitPanel(
                context: context,
                key: const ValueKey('instant-exit-panel'),
                title: english ? 'Instant exit' : 'Sofort-Ausstieg',
                children: comparison.instantProceeds == null
                    ? [Text(english ? 'No current offer' : 'Kein aktuelles Angebot')]
                    : [
                        _value(
                          context,
                          english ? 'Payout' : 'Auszahlung',
                          _money(comparison.instantProceeds!),
                          key: const ValueKey('instant-exit-proceeds'),
                          strong: true,
                        ),
                        _value(
                          context,
                          english ? 'Profit' : 'Gewinn',
                          _money(comparison.instantProfit!),
                          key: const ValueKey('instant-exit-profit'),
                          strong: true,
                        ),
                        Text(
                          instantRequiresInspection
                              ? (english
                                  ? 'Provisional · provider inspection pending'
                                  : 'Vorläufig · Anbieterprüfung ausstehend')
                              : (english ? 'Firm cash quote' : 'Festes Geldangebot'),
                          key: const ValueKey('instant-exit-certainty'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if ((instantProvider ?? '').isNotEmpty)
                          Text(instantProvider!,
                              style: Theme.of(context).textTheme.labelSmall),
                      ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _exitPanel(
                context: context,
                key: const ValueKey('market-exit-panel'),
                title: english ? 'Market exit' : 'Markt-Ausstieg',
                children: estimate == null || marketProfit == null
                    ? [Text(english ? 'Not enough data' : 'Noch nicht genug Daten')]
                    : [
                        _value(
                          context,
                          english ? 'Likely sale' : 'Wahrscheinlich',
                          _money(estimate.likely),
                          key: const ValueKey('market-exit-likely'),
                          strong: true,
                        ),
                        _value(
                          context,
                          english ? 'Sale range' : 'Verkaufsspanne',
                          '${_money(estimate.low)} – ${_money(estimate.high)}',
                          key: const ValueKey('market-exit-range'),
                        ),
                        _value(
                          context,
                          english ? 'Profit range' : 'Gewinnspanne',
                          '${_money(marketProfit.low)} – ${_money(marketProfit.high)}',
                          key: const ValueKey('market-exit-profit-range'),
                        ),
                        Text(
                          '${english ? 'Reliability' : 'Verlässlichkeit'}: ${_confidence(estimate.confidence)}',
                          key: const ValueKey('market-exit-confidence'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '${english ? 'Basis' : 'Datengrundlage'}: ${_evidence(estimate)}',
                          key: const ValueKey('market-exit-evidence'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (estimate.estimatedDaysToSell != null)
                          Text(
                            english
                                ? 'Estimated: ${estimate.estimatedDaysToSell} days'
                                : 'Geschätzt: ${estimate.estimatedDaysToSell} Tage',
                            key: const ValueKey('market-exit-duration'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
              ),
            ),
          ]),
          const SizedBox(height: 7),
          Text(
            '${english ? 'Total investment' : 'Gesamteinsatz'}: ${_money(comparison.totalInvestment)}',
            key: const ValueKey('dual-exit-total-investment'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ]),
      ),
    );
  }
}
