import 'dart:convert';

import 'package:flipwert/deal_alert.dart';
import 'package:flipwert/deal_alert_store.dart';
import 'package:flipwert/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

V13Flip _saved(String id, {String status = 'Saved'}) {
  final checkedAt = DateTime(2026, 10, 2, 8);
  return V13Flip(
    id: id,
    name: 'Apple iPhone 15 Pro 256 GB',
    category: 'Elektronik',
    buy: 250,
    expectedAtBuy: 400,
    costs: 10,
    sourceCount: 3,
    confidence: 'Mittel',
    status: status,
    createdAt: checkedAt,
    checkedAt: checkedAt,
    maxBuyAtCheck: 280,
    profitAtCheck: 140,
    roiAtCheck: 56,
  );
}

void main() {
  testWidgets('startup removes alerts without a saved or archived deal',
      (tester) async {
    final saved = _saved('saved-1');
    final archived = _saved('archived-1', status: 'Archived');
    SharedPreferences.setMockInitialValues({
      'flips_v13': [
        jsonEncode(saved.toJson()),
        jsonEncode(archived.toJson()),
      ],
    });
    final store = DealAlertStore();
    await store.save(DealAlertPreference.defaults('saved-1'));
    await store.save(DealAlertPreference.defaults('archived-1'));
    await store.save(DealAlertPreference.defaults('orphan-1'));

    await tester.pumpWidget(const FlipwertV13App());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(
      (await store.load()).map((item) => item.flipId).toSet(),
      {'saved-1', 'archived-1'},
    );
  });
}
