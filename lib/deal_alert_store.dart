import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'deal_alert.dart';

/// Small local persistence layer for deal-alert opt-ins.
///
/// Keeping this provider-independent lets Flipwert ship useful alert settings
/// before any push service is introduced. Corrupt entries are ignored rather
/// than breaking the watchlist or deal-check flow.
class DealAlertStore {
  static const _storageKey = 'deal_alert_preferences_v1';

  // Saved-deal cards each own a store instance. Serialize read-modify-write
  // mutations across all instances so quickly switching cards cannot let two
  // overlapping saves overwrite each other's preferences.
  static Future<void> _mutationQueue = Future<void>.value();

  Future<List<DealAlertPreference>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final byFlip = <String, DealAlertPreference>{};
      for (final item in decoded) {
        if (item is! Map) continue;
        final preference = DealAlertPreference.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (preference == null) continue;
        final existing = byFlip[preference.flipId];
        if (existing == null || preference.updatedAt.isAfter(existing.updatedAt)) {
          byFlip[preference.flipId] = preference;
        }
      }
      final result = byFlip.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return result;
    } catch (_) {
      return const [];
    }
  }

  Future<DealAlertPreference?> forFlip(String flipId) async {
    final id = flipId.trim();
    if (id.isEmpty) return null;
    final all = await load();
    for (final preference in all) {
      if (preference.flipId == id) return preference;
    }
    return null;
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

  Future<bool> save(DealAlertPreference preference) {
    final id = preference.flipId.trim();
    if (id.isEmpty) return Future<bool>.value(false);
    final canonical = id == preference.flipId
        ? preference
        : DealAlertPreference(
            flipId: id,
            enabled: preference.enabled,
            minProfitIncrease: preference.minProfitIncrease,
            minBuybackProfitIncrease: preference.minBuybackProfitIncrease,
            minRoiIncrease: preference.minRoiIncrease,
            updatedAt: preference.updatedAt,
          );
    return _mutate(() async {
      final all = await load();
      DealAlertPreference? existing;
      for (final item in all) {
        if (item.flipId == id) {
          existing = item;
          break;
        }
      }
      // A delayed UI callback must never roll back a preference that was saved
      // more recently from another card/recheck. Treat equal timestamps as the
      // same logical revision too: timer resolution or restored state can make
      // two callbacks share a timestamp, and arrival order must not decide the
      // user's final alert setting.
      if (existing != null && !canonical.updatedAt.isAfter(existing.updatedAt)) {
        return true;
      }
      final next = <DealAlertPreference>[
        canonical,
        ...all.where((item) => item.flipId != id),
      ];
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
      final next = all.where((item) => item.flipId != id).toList();
      if (next.length == all.length) return true;
      final prefs = await SharedPreferences.getInstance();
      if (next.isEmpty) return prefs.remove(_storageKey);
      return prefs.setString(
        _storageKey,
        jsonEncode(next.map((item) => item.toJson()).toList()),
      );
    });
  }

  /// Removes preferences that no longer belong to a saved or archived deal.
  ///
  /// This repairs orphaned entries left by older app versions while keeping
  /// archived watchlist items ready for a later restore.
  Future<bool> retainOnly(Iterable<String> flipIds) {
    final retainedIds = flipIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    return _mutate(() async {
      final all = await load();
      final next = all
          .where((item) => retainedIds.contains(item.flipId))
          .toList();
      if (next.length == all.length) return true;
      final prefs = await SharedPreferences.getInstance();
      if (next.isEmpty) return prefs.remove(_storageKey);
      return prefs.setString(
        _storageKey,
        jsonEncode(next.map((item) => item.toJson()).toList()),
      );
    });
  }
}
