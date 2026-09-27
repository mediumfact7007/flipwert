import 'package:flipwert/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

V13Flip _saved(String id, DateTime checkedAt) => V13Flip(
      id: id,
      name: 'Nintendo Switch OLED',
      category: 'Konsole',
      buy: 220,
      expectedAtBuy: 350,
      costs: 0,
      sourceCount: 5,
      confidence: 'Mittel',
      status: 'Saved',
      createdAt: checkedAt,
      checkedAt: checkedAt,
      sourceUrl: 'https://www.kleinanzeigen.de/s-anzeige/nintendo-switch-oled/1234567890-279-1234',
      maxBuyAtCheck: 259,
      profitAtCheck: 130,
      roiAtCheck: 59.1,
      confidenceScore: 55,
    );

void main() {
  testWidgets('saved tab highlights stale deals and rechecks the oldest first', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    final now = DateTime.now();
    final oldest = _saved('oldest', now.subtract(const Duration(days: 3)));
    final stale = _saved('stale', now.subtract(const Duration(hours: 30)));
    final fresh = _saved('fresh', now.subtract(const Duration(hours: 2)));
    V13Flip? requested;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: V13FlipsPage(
          english: false,
          plan: UserPlan.free,
          flips: [fresh, stale, oldest],
          monetization: monetization,
          onUpdate: (_) {},
          onImportSales: (_) {},
          onDelete: (_) {},
          onRecheck: (value) => requested = value,
          onPro: () {},
        ),
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Merkliste'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('v149-watchlist-attention')), findsOneWidget);
    expect(find.text('2 Deals neu prüfen'), findsOneWidget);
    final action = find.byKey(const ValueKey('v149-recheck-oldest'));
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pump();
    expect(requested?.id, 'oldest');

    monetization.dispose();
  });
}
