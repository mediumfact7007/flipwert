import 'package:flutter/material.dart';

import 'deal_alert.dart';
import 'deal_alert_store.dart';

/// Compact opt-in control for saved-deal alerts.
///
/// The control is intentionally local-only for now: it persists the user's
/// preference without requesting notification permissions or depending on a
/// push provider. That keeps the watchlist useful today and leaves delivery
/// infrastructure isolated for a later step.
class DealAlertToggle extends StatefulWidget {
  final String flipId;
  final bool english;
  final DealAlertStore? store;

  const DealAlertToggle({
    super.key,
    required this.flipId,
    required this.english,
    this.store,
  });

  @override
  State<DealAlertToggle> createState() => _DealAlertToggleState();
}

class _DealAlertToggleState extends State<DealAlertToggle> {
  late final DealAlertStore _store = widget.store ?? DealAlertStore();
  DealAlertPreference? _preference;
  bool _loading = true;
  bool _saving = false;

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DealAlertToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipId != widget.flipId) {
      // Never show the previous deal's alert state while the new preference is
      // loading. Saved-deal cards can be reused by Flutter during reordering.
      setState(() {
        _preference = null;
        _loading = true;
        _saving = false;
      });
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final requestedFlipId = widget.flipId;
    final preference = await _store.forFlip(requestedFlipId);
    // A slower read for the previous card must never overwrite the currently
    // visible saved deal after Flutter reuses this State during reordering.
    if (!mounted || requestedFlipId != widget.flipId) return;
    setState(() {
      _preference = preference;
      _loading = false;
    });
  }

  Future<void> _persist(DealAlertPreference next) async {
    if (_saving) return;
    final requestedFlipId = widget.flipId;
    setState(() => _saving = true);
    final saved = await _store.save(next);
    // Saving can finish after Flutter has reused this State for another saved
    // deal. Never apply the old deal's result or error to the new card.
    if (!mounted || requestedFlipId != widget.flipId) return;
    setState(() {
      if (saved) _preference = next;
      _saving = false;
    });
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('Deal-Alarm konnte nicht gespeichert werden.', 'Deal alert could not be saved.'))),
      );
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    final requestedFlipId = widget.flipId;
    final next = (_preference ?? DealAlertPreference.defaults(requestedFlipId))
        .copyWith(enabled: enabled, updatedAt: DateTime.now());
    await _persist(next);
  }

  Future<void> _setSensitivity(double threshold) async {
    final current = _preference;
    if (current == null || !current.enabled) return;
    await _persist(current.copyWith(
      minProfitIncrease: threshold,
      minBuybackProfitIncrease: threshold,
      minRoiIncrease: threshold,
      updatedAt: DateTime.now(),
    ));
  }

  String _sensitivityLabel(DealAlertPreference preference) {
    final threshold = preference.minProfitIncrease;
    if ((threshold - 2).abs() < 0.01 && (preference.minBuybackProfitIncrease - 2).abs() < 0.01 && (preference.minRoiIncrease - 2).abs() < 0.01) {
      return t('Sensibel', 'Sensitive');
    }
    if ((threshold - 10).abs() < 0.01 && (preference.minBuybackProfitIncrease - 10).abs() < 0.01 && (preference.minRoiIncrease - 10).abs() < 0.01) {
      return t('Stark', 'Strong');
    }
    if ((threshold - 5).abs() < 0.01 && (preference.minBuybackProfitIncrease - 5).abs() < 0.01 && (preference.minRoiIncrease - 5).abs() < 0.01) {
      return t('Standard', 'Standard');
    }
    return t('Eigene Schwelle', 'Custom threshold');
  }

  @override
  Widget build(BuildContext context) {
    final preference = _preference;
    final enabled = preference?.enabled ?? false;
    final busy = _loading || _saving;
    return Container(
      key: ValueKey('deal-alert-${widget.flipId}'),
      padding: const EdgeInsets.fromLTRB(11, 7, 7, 7),
      decoration: BoxDecoration(
        color: enabled ? const Color(0xFFF2F7F4) : const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: enabled ? const Color(0x22087F5B) : const Color(0xFFE9EAF0)),
      ),
      child: Row(children: [
        Icon(
          enabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
          size: 19,
          color: enabled ? const Color(0xFF087F5B) : const Color(0xFF777B88),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Deal-Alarm', 'Deal alert'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5)),
          Text(
            enabled && preference != null
                ? t(
                    '${_sensitivityLabel(preference)}: Privat +${preference.minProfitIncrease.toStringAsFixed(0)} €, LIVE-Ankauf +${preference.minBuybackProfitIncrease.toStringAsFixed(0)} €, ROI +${preference.minRoiIncrease.toStringAsFixed(0)} %-Pkt.',
                    '${_sensitivityLabel(preference)}: private +€${preference.minProfitIncrease.toStringAsFixed(0)}, LIVE buyback +€${preference.minBuybackProfitIncrease.toStringAsFixed(0)}, ROI +${preference.minRoiIncrease.toStringAsFixed(0)}pp.',
                  )
                : t('Beim Recheck deutlich bessere Deals markieren.', 'Flag meaningfully better deals on recheck.'),
            style: const TextStyle(fontSize: 9.8, color: Color(0xFF707481)),
          ),
          if (enabled)
            Text(
              t('Aktuell lokal in Flipwert – keine Push-Nachricht.', 'Currently local in Flipwert — no push notification.'),
              style: const TextStyle(fontSize: 9.2, color: Color(0xFF8B8E9A)),
            ),
        ])),
        if (enabled)
          PopupMenuButton<double>(
            tooltip: t('Empfindlichkeit', 'Sensitivity'),
            enabled: !busy,
            icon: const Icon(Icons.tune_rounded, size: 19),
            onSelected: _setSensitivity,
            itemBuilder: (context) => [
              PopupMenuItem(value: 2, child: Text(t('Sensibel · +2 € / +2 %-Pkt.', 'Sensitive · +€2 / +2pp'))),
              PopupMenuItem(value: 5, child: Text(t('Standard · +5 € / +5 %-Pkt.', 'Standard · +€5 / +5pp'))),
              PopupMenuItem(value: 10, child: Text(t('Stark · +10 € / +10 %-Pkt.', 'Strong · +€10 / +10pp'))),
            ],
          ),
        Switch.adaptive(
          key: ValueKey('deal-alert-switch-${widget.flipId}'),
          value: enabled,
          onChanged: busy ? null : _setEnabled,
        ),
      ]),
    );
  }
}
