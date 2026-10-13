import 'package:flutter/material.dart';

import 'deal_alert.dart';
import 'deal_alert_result_store.dart';
import 'deal_alert_store.dart';

class DealAlertOverviewItem {
  final String flipId;
  final String name;
  final DateTime checkedAt;

  const DealAlertOverviewItem({
    required this.flipId,
    required this.name,
    required this.checkedAt,
  });
}

/// Honest overview of local deal alerts in the saved-deal workflow.
///
/// It does not schedule work or imply push delivery. Instead it makes the
/// existing local preferences visible and prioritizes the next manual recheck.
class DealAlertOverview extends StatefulWidget {
  final bool english;
  final List<DealAlertOverviewItem> items;
  final ValueChanged<String> onRecheck;
  final DealAlertStore? store;
  final DealAlertResultStore? resultStore;
  final int revision;
  final DateTime? now;

  const DealAlertOverview({
    super.key,
    required this.english,
    required this.items,
    required this.onRecheck,
    this.store,
    this.resultStore,
    this.revision = 0,
    this.now,
  });

  @override
  State<DealAlertOverview> createState() => _DealAlertOverviewState();
}

class _DealAlertOverviewState extends State<DealAlertOverview> {
  late final DealAlertStore _store = widget.store ?? DealAlertStore();
  late final DealAlertResultStore _resultStore =
      widget.resultStore ?? DealAlertResultStore();
  late Future<_DealAlertOverviewData> _data = _load();

  String t(String de, String en) => widget.english ? en : de;

  Future<_DealAlertOverviewData> _load() async => _DealAlertOverviewData(
        preferences: await _store.load(),
        results: await _resultStore.load(),
      );

  @override
  void didUpdateWidget(covariant DealAlertOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.items != widget.items) {
      _data = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DealAlertOverviewData>(
      future: _data,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final byId = {
          for (final preference in snapshot.data!.preferences)
            if (preference.enabled) preference.flipId: preference,
        };
        final resultsById = <String, DealAlertResult>{};
        for (final result in snapshot.data!.results) {
          final preference = byId[result.flipId];
          // Changing or re-enabling an alert creates a new evaluation baseline.
          // Never present a result calculated with an older threshold.
          if (preference != null &&
              !result.checkedAt.isBefore(preference.updatedAt)) {
            resultsById[result.flipId] = result;
          }
        }
        final active = widget.items
            .where((item) => byId.containsKey(item.flipId))
            .toList()
          ..sort((a, b) {
            final aTriggered = resultsById[a.flipId]?.triggered == true;
            final bTriggered = resultsById[b.flipId]?.triggered == true;
            if (aTriggered != bTriggered) return aTriggered ? -1 : 1;
            if (aTriggered) {
              return resultsById[b.flipId]!.checkedAt.compareTo(
                    resultsById[a.flipId]!.checkedAt,
                  );
            }
            return a.checkedAt.compareTo(b.checkedAt);
          });
        if (active.isEmpty) return const SizedBox.shrink();

        final now = widget.now ?? DateTime.now();
        final due = active
            .where((item) => now.difference(item.checkedAt).inHours >= 24)
            .toList();
        final triggered = active
            .where((item) => resultsById[item.flipId]?.triggered == true)
            .length;
        final preview = active.take(3).toList();
        final title = t(
          '${active.length} aktive${active.length == 1 ? 'r' : ''} Deal-Alarm${active.length == 1 ? '' : 'e'}',
          '${active.length} active deal alert${active.length == 1 ? '' : 's'}',
        );
        final dueStatus = due.isEmpty
            ? t('Alle Checks jünger als 24 Std.', 'All checks are less than 24h old.')
            : t(
                '${due.length} ${due.length == 1 ? 'Prüfung ist' : 'Prüfungen sind'} fällig.',
                '${due.length} ${due.length == 1 ? 'check is' : 'checks are'} due.',
              );
        final resultStatus = triggered == 0
            ? ''
            : t(
                ' $triggered zuletzt ausgelöst.',
                ' $triggered last triggered.',
              );
        return Container(
          key: const ValueKey('deal-alert-overview'),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F7F4),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0x22087F5B)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.notifications_active_rounded,
                  color: Color(0xFF087F5B), size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 12.5)),
                      Text(
                        '$dueStatus$resultStatus ${t('Nur lokal; Auswertung beim Recheck.', 'Local only; evaluated on recheck.')}',
                        style: const TextStyle(
                            fontSize: 10.5, color: Color(0xFF707481)),
                      ),
                    ]),
              ),
              if (due.isNotEmpty)
                TextButton(
                  key: const ValueKey('deal-alert-recheck-next'),
                  onPressed: () => widget.onRecheck(due.first.flipId),
                  child: Text(t('JETZT PRÜFEN', 'CHECK NOW')),
                ),
            ]),
            const SizedBox(height: 8),
            for (final item in preview)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _alertRow(
                  item,
                  byId[item.flipId]!,
                  resultsById[item.flipId],
                ),
              ),
            if (active.length > preview.length)
              Text(
                t('+ ${active.length - preview.length} weitere',
                    '+ ${active.length - preview.length} more'),
                style: const TextStyle(
                    fontSize: 9.8, color: Color(0xFF707481)),
              ),
          ]),
        );
      },
    );
  }

  String _thresholdLabel(DealAlertPreference preference) => widget.english
      ? '+€${preference.minProfitIncrease.toStringAsFixed(0)} / +${preference.minRoiIncrease.toStringAsFixed(0)}pp'
      : '+${preference.minProfitIncrease.toStringAsFixed(0)} € / +${preference.minRoiIncrease.toStringAsFixed(0)} %-Pkt.';

  String _resultReason(DealAlertResult result) {
    final reasons = <String>[];
    if (result.becameProfitable) {
      reasons.add(t('Privat jetzt profitabel', 'Private exit now profitable'));
    }
    if (result.profitThresholdReached) {
      reasons.add(
        '${t('Privatgewinn', 'Private profit')} +${result.profitIncrease.toStringAsFixed(0)} €',
      );
    }
    if (result.roiThresholdReached) {
      reasons.add('ROI +${result.roiIncrease.toStringAsFixed(0)} %-Pkt.');
    }
    if (result.buybackBecameProfitable) {
      reasons.add(
        t('LIVE-Ankauf jetzt profitabel', 'LIVE buyback now profitable'),
      );
    }
    if (result.buybackProfitThresholdReached) {
      reasons.add(
        '${t('LIVE-Ankaufgewinn', 'LIVE buyback profit')} +${result.buybackProfitIncrease.toStringAsFixed(0)} €',
      );
    }
    return reasons.join(' · ');
  }

  String _resultTime(DateTime value) {
    String two(int part) => part.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}. ${two(value.hour)}:${two(value.minute)}';
  }

  Widget _alertRow(
    DealAlertOverviewItem item,
    DealAlertPreference preference,
    DealAlertResult? result,
  ) {
    final resultLabel = result == null
        ? null
        : result.triggered
            ? t('AUSGELÖST', 'TRIGGERED')
            : t('GEPRÜFT', 'CHECKED');
    final resultColor = result?.triggered == true
        ? const Color(0xFF087F5B)
        : const Color(0xFF707481);
    final reason = result?.triggered == true ? _resultReason(result!) : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: result?.triggered == true
            ? const Color(0xFFE7F4EE)
            : Colors.white.withValues(alpha: .62),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10.8, fontWeight: FontWeight.w700)),
          ),
          if (resultLabel != null) ...[
            Container(
              key: ValueKey('deal-alert-result-${item.flipId}'),
              margin: const EdgeInsets.only(right: 7),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(resultLabel,
                  style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: resultColor)),
            ),
          ],
          Text(_thresholdLabel(preference),
              style:
                  const TextStyle(fontSize: 9.8, color: Color(0xFF087F5B))),
        ]),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Text(
                '$reason · ${_resultTime(result!.checkedAt)}',
                key: ValueKey('deal-alert-reason-${item.flipId}'),
                style: const TextStyle(
                  fontSize: 9.7,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF175B47),
                ),
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              key: ValueKey('deal-alert-recheck-triggered-${item.flipId}'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => widget.onRecheck(item.flipId),
              child: Text(t('NEU PRÜFEN', 'RECHECK')),
            ),
          ]),
        ],
      ]),
    );
  }
}

class _DealAlertOverviewData {
  final List<DealAlertPreference> preferences;
  final List<DealAlertResult> results;

  const _DealAlertOverviewData({
    required this.preferences,
    required this.results,
  });
}
