import 'package:flutter/material.dart';

import 'deal_alert.dart';
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
  final int revision;
  final DateTime? now;

  const DealAlertOverview({
    super.key,
    required this.english,
    required this.items,
    required this.onRecheck,
    this.store,
    this.revision = 0,
    this.now,
  });

  @override
  State<DealAlertOverview> createState() => _DealAlertOverviewState();
}

class _DealAlertOverviewState extends State<DealAlertOverview> {
  late final DealAlertStore _store = widget.store ?? DealAlertStore();
  late Future<List<DealAlertPreference>> _preferences = _store.load();

  String t(String de, String en) => widget.english ? en : de;

  @override
  void didUpdateWidget(covariant DealAlertOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.items != widget.items) {
      _preferences = _store.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DealAlertPreference>>(
      future: _preferences,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final byId = {
          for (final preference in snapshot.data!)
            if (preference.enabled) preference.flipId: preference,
        };
        final active = widget.items
            .where((item) => byId.containsKey(item.flipId))
            .toList()
          ..sort((a, b) => a.checkedAt.compareTo(b.checkedAt));
        if (active.isEmpty) return const SizedBox.shrink();

        final now = widget.now ?? DateTime.now();
        final due = active
            .where((item) => now.difference(item.checkedAt).inHours >= 24)
            .toList();
        final preview = active.take(3).toList();
        final title = t(
          '${active.length} aktive${active.length == 1 ? 'r' : ''} Deal-Alarm${active.length == 1 ? '' : 'e'}',
          '${active.length} active deal alert${active.length == 1 ? '' : 's'}',
        );
        final status = due.isEmpty
            ? t('Alle Checks jünger als 24 Std.', 'All checks are less than 24h old.')
            : t(
                '${due.length} ${due.length == 1 ? 'Prüfung ist' : 'Prüfungen sind'} fällig.',
                '${due.length} ${due.length == 1 ? 'check is' : 'checks are'} due.',
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
                        '$status ${t('Nur lokal; Auswertung beim Recheck.', 'Local only; evaluated on recheck.')}',
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
                child: Row(children: [
                  Expanded(
                    child: Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10.8, fontWeight: FontWeight.w700)),
                  ),
                  Text(_thresholdLabel(byId[item.flipId]!),
                      style: const TextStyle(
                          fontSize: 9.8, color: Color(0xFF087F5B))),
                ]),
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
}
