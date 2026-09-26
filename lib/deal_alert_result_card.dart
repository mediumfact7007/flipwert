import 'package:flutter/material.dart';

import 'deal_alert.dart';
import 'deal_alert_store.dart';

/// Shows a saved deal's local alert result directly in the recheck flow.
/// Disabled/missing preferences stay silent so the normal check UI is unchanged.
class DealAlertResultCard extends StatefulWidget {
  final String flipId;
  final bool english;
  final double previousProfit;
  final double currentProfit;
  final double previousRoi;
  final double currentRoi;
  final bool hasPrivateComparison;
  final double? previousBuybackProfit;
  final double? currentBuybackProfit;
  final bool verifiedBuybackComparison;
  final DealAlertStore? store;

  const DealAlertResultCard({
    super.key,
    required this.flipId,
    required this.english,
    required this.previousProfit,
    required this.currentProfit,
    required this.previousRoi,
    required this.currentRoi,
    this.hasPrivateComparison = true,
    this.previousBuybackProfit,
    this.currentBuybackProfit,
    this.verifiedBuybackComparison = false,
    this.store,
  });

  @override
  State<DealAlertResultCard> createState() => _DealAlertResultCardState();
}

class _DealAlertResultCardState extends State<DealAlertResultCard> {
  late final DealAlertStore _store = widget.store ?? DealAlertStore();
  DealAlertPreference? _preference;

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DealAlertResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipId != widget.flipId) {
      setState(() => _preference = null);
      _load();
    }
  }

  Future<void> _load() async {
    final requestedFlipId = widget.flipId;
    final preference = await _store.forFlip(requestedFlipId);
    if (!mounted || requestedFlipId != widget.flipId) return;
    setState(() => _preference = preference);
  }

  String _profitState(double value) {
    final amount = value.abs().toStringAsFixed(0);
    if (value < 0) return t('$amount € Verlust', '$amount € loss');
    return t('$amount € Gewinn', '$amount € profit');
  }

  @override
  Widget build(BuildContext context) {
    final preference = _preference;
    if (preference == null || !preference.enabled) return const SizedBox.shrink();
    final evaluation = evaluateDealAlert(
      preference: preference,
      previousProfit: widget.hasPrivateComparison ? widget.previousProfit : double.nan,
      currentProfit: widget.hasPrivateComparison ? widget.currentProfit : double.nan,
      previousRoi: widget.hasPrivateComparison ? widget.previousRoi : double.nan,
      currentRoi: widget.hasPrivateComparison ? widget.currentRoi : double.nan,
      previousBuybackProfit: widget.previousBuybackProfit,
      currentBuybackProfit: widget.currentBuybackProfit,
      verifiedBuybackComparison: widget.verifiedBuybackComparison,
    );
    if (!evaluation.triggered) return const SizedBox.shrink();

    final reasons = <String>[];
    if (evaluation.becameProfitable) {
      reasons.add(t('Jetzt profitabel', 'Now profitable'));
    }
    if (evaluation.profitThresholdReached) {
      reasons.add('${t('Gewinn', 'Profit')} +${evaluation.profitIncrease.toStringAsFixed(0)} €');
    }
    if (evaluation.roiThresholdReached) {
      reasons.add('ROI +${evaluation.roiIncrease.toStringAsFixed(0)} %-Pkt');
    }
    if (evaluation.buybackBecameProfitable) {
      reasons.add(t('LIVE-Ankauf jetzt profitabel', 'LIVE buyback now profitable'));
    }
    if (evaluation.buybackProfitThresholdReached) {
      reasons.add('${t('LIVE-Ankaufgewinn', 'LIVE buyback profit')} +${evaluation.buybackProfitIncrease.toStringAsFixed(0)} €');
    }
    final comparisonLines = <String>[];
    if (widget.hasPrivateComparison) {
      comparisonLines.add(
        '${t('Privat vorher', 'Private before')}: ${_profitState(widget.previousProfit)} · ROI ${widget.previousRoi.toStringAsFixed(0)} %\n'
        '${t('Privat jetzt', 'Private now')}: ${_profitState(widget.currentProfit)} · ROI ${widget.currentRoi.toStringAsFixed(0)} %',
      );
    }
    if (widget.verifiedBuybackComparison && widget.previousBuybackProfit != null && widget.currentBuybackProfit != null) {
      comparisonLines.add(
        '${t('LIVE-Ankauf vorher', 'LIVE buyback before')}: ${_profitState(widget.previousBuybackProfit!)}\n'
        '${t('LIVE-Ankauf jetzt', 'LIVE buyback now')}: ${_profitState(widget.currentBuybackProfit!)}',
      );
    }
    final comparison = comparisonLines.join('\n');
    final threshold =
        '${t('Dein Alarm', 'Your alert')}: +${preference.minProfitIncrease.toStringAsFixed(0)} € ${t('Privatgewinn', 'private profit')}, '
        '+${preference.minBuybackProfitIncrease.toStringAsFixed(0)} € ${t('LIVE-Ankaufgewinn', 'LIVE buyback profit')} ${t('oder', 'or')} '
        '+${preference.minRoiIncrease.toStringAsFixed(0)} %-Pkt. ROI';

    return Container(
      key: const ValueKey('v153-deal-alert-result'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x33087F5B)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.notifications_active_rounded, color: Color(0xFF087F5B), size: 21),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('DEAL-ALARM AUSGELÖST', 'DEAL ALERT TRIGGERED'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF087F5B))),
          const SizedBox(height: 4),
          Text(reasons.join(' · '), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(comparison, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.35, color: Color(0xFF34413C))),
          const SizedBox(height: 4),
          Text(threshold, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF52605A))),
          const SizedBox(height: 3),
          Text(t('Dein gespeichertes Alarmkriterium wurde erreicht.', 'Your saved alert criterion was reached.'), style: const TextStyle(fontSize: 10.5, color: Color(0xFF626B67))),
          const SizedBox(height: 2),
          Text(t('Lokaler Recheck-Hinweis – aktuell keine Push-Nachricht.', 'Local recheck notice — currently no push notification.'), style: const TextStyle(fontSize: 9.8, color: Color(0xFF7B837F))),
        ])),
      ]),
    );
  }
}
