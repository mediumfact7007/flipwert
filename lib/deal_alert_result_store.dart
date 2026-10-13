import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'deal_alert.dart';

/// Durable local outcome of the latest manual recheck for one deal alert.
///
/// This is deliberately not a notification queue: no background work or
/// provider request is started here. It only keeps the result that the user
/// already produced in the explicit recheck flow.
class DealAlertResult {
  final String flipId;
  final DateTime checkedAt;
  final bool triggered;
  final double profitIncrease;
  final double roiIncrease;
  final double buybackProfitIncrease;
  final bool profitThresholdReached;
  final bool roiThresholdReached;
  final bool buybackProfitThresholdReached;
  final bool becameProfitable;
  final bool buybackBecameProfitable;

  const DealAlertResult({
    required this.flipId,
    required this.checkedAt,
    required this.triggered,
    required this.profitIncrease,
    required this.roiIncrease,
    required this.buybackProfitIncrease,
    required this.profitThresholdReached,
    required this.roiThresholdReached,
    required this.buybackProfitThresholdReached,
    required this.becameProfitable,
    required this.buybackBecameProfitable,
  });

  factory DealAlertResult.fromEvaluation({
    required String flipId,
    required DateTime checkedAt,
    required DealAlertEvaluation evaluation,
  }) =>
      DealAlertResult(
        flipId: flipId.trim(),
        checkedAt: checkedAt,
        triggered: evaluation.triggered,
        profitIncrease: evaluation.profitIncrease,
        roiIncrease: evaluation.roiIncrease,
        buybackProfitIncrease: evaluation.buybackProfitIncrease,
        profitThresholdReached: evaluation.profitThresholdReached,
        roiThresholdReached: evaluation.roiThresholdReached,
        buybackProfitThresholdReached:
            evaluation.buybackProfitThresholdReached,
        becameProfitable: evaluation.becameProfitable,
        buybackBecameProfitable: evaluation.buybackBecameProfitable,
      );

  Map<String, Object> toJson() => {
        'flip_id': flipId,
        'checked_at': checkedAt.toUtc().toIso8601String(),
        'triggered': triggered,
        'profit_increase': profitIncrease,
        'roi_increase': roiIncrease,
        'buyback_profit_increase': buybackProfitIncrease,
        'profit_threshold_reached': profitThresholdReached,
        'roi_threshold_reached': roiThresholdReached,
        'buyback_profit_threshold_reached': buybackProfitThresholdReached,
        'became_profitable': becameProfitable,
        'buyback_became_profitable': buybackBecameProfitable,
      };

  static DealAlertResult? fromJson(Map<String, dynamic> json) {
    final flipId = json['flip_id'];
    final checkedAt = DateTime.tryParse(json['checked_at']?.toString() ?? '');
    final triggered = json['triggered'];
    final profitIncrease = json['profit_increase'];
    final roiIncrease = json['roi_increase'];
    final buybackProfitIncrease = json['buyback_profit_increase'];
    final flags = [
      json['profit_threshold_reached'],
      json['roi_threshold_reached'],
      json['buyback_profit_threshold_reached'],
      json['became_profitable'],
      json['buyback_became_profitable'],
    ];
    if (flipId is! String ||
        flipId.trim().isEmpty ||
        checkedAt == null ||
        triggered is! bool ||
        profitIncrease is! num ||
        roiIncrease is! num ||
        buybackProfitIncrease is! num ||
        flags.any((flag) => flag is! bool)) {
      return null;
    }
    final profit = profitIncrease.toDouble();
    final roi = roiIncrease.toDouble();
    final buyback = buybackProfitIncrease.toDouble();
    if (!profit.isFinite || !roi.isFinite || !buyback.isFinite) return null;
    return DealAlertResult(
      flipId: flipId.trim(),
      checkedAt: checkedAt.toLocal(),
      triggered: triggered,
      profitIncrease: profit,
      roiIncrease: roi,
      buybackProfitIncrease: buyback,
      profitThresholdReached: flags[0] as bool,
      roiThresholdReached: flags[1] as bool,
      buybackProfitThresholdReached: flags[2] as bool,
      becameProfitable: flags[3] as bool,
      buybackBecameProfitable: flags[4] as bool,
    );
  }
}

class DealAlertResultStore {
  static const _storageKey = 'deal_alert_results_v1';
  static Future<void> _mutationQueue = Future<void>.value();

  Future<List<DealAlertResult>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final byFlip = <String, DealAlertResult>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final result = DealAlertResult.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (result == null) continue;
        final existing = byFlip[result.flipId];
        if (existing == null || result.checkedAt.isAfter(existing.checkedAt)) {
          byFlip[result.flipId] = result;
        }
      }
      final results = byFlip.values.toList()
        ..sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
      return results;
    } catch (_) {
      return const [];
    }
  }

  Future<bool> _mutate(Future<bool> Function() operation) async {
    var result = false;
    _mutationQueue = _mutationQueue.then((_) async {
      try {
        result = await operation();
      } catch (_) {
        result = false;
      }
    });
    await _mutationQueue;
    return result;
  }

  Future<bool> save(DealAlertResult result) {
    final id = result.flipId.trim();
    if (id.isEmpty) return Future<bool>.value(false);
    return _mutate(() async {
      final all = await load();
      DealAlertResult? existing;
      for (final item in all) {
        if (item.flipId == id) {
          existing = item;
          break;
        }
      }
      if (existing != null && !result.checkedAt.isAfter(existing.checkedAt)) {
        return true;
      }
      final next = [result, ...all.where((item) => item.flipId != id)];
      final prefs = await SharedPreferences.getInstance();
      return prefs.setString(
        _storageKey,
        jsonEncode(next.map((item) => item.toJson()).toList()),
      );
    });
  }

  Future<bool> remove(String flipId) {
    final id = flipId.trim();
    if (id.isEmpty) return Future<bool>.value(true);
    return _mutate(() async {
      final all = await load();
      return _write(
        all.where((item) => item.flipId != id).toList(),
        all.length,
      );
    });
  }

  Future<bool> retainOnly(Iterable<String> flipIds) {
    final retained = flipIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return _mutate(() async {
      final all = await load();
      return _write(
        all.where((item) => retained.contains(item.flipId)).toList(),
        all.length,
      );
    });
  }

  Future<bool> _write(List<DealAlertResult> next, int previousLength) async {
    if (next.length == previousLength) return true;
    final prefs = await SharedPreferences.getInstance();
    if (next.isEmpty) return prefs.remove(_storageKey);
    return prefs.setString(
      _storageKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }
}
