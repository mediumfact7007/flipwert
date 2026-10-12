import 'package:flipwert/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('finishing a sale records actual total costs for realized profit',
      (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    V13Flip? updated;
    final bought = V13Flip(
      id: 'sale-costs-1',
      name: 'Nintendo Switch OLED',
      category: 'Konsole',
      buy: 220,
      expectedAtBuy: 350,
      costs: 10,
      sourceCount: 3,
      confidence: 'Mittel',
      status: 'Bought',
      createdAt: DateTime(2026, 10, 12),
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: V13FlipsPage(
          english: false,
          plan: UserPlan.free,
          flips: [bought],
          monetization: monetization,
          onUpdate: (value) => updated = value,
          onImportSales: (_) {},
          onDelete: (_) {},
          onRecheck: (_) {},
          onPro: () {},
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Verkauft'));
    await tester.pumpAndSettle();

    final costsField = find.byKey(
      const ValueKey('v160-actual-total-costs'),
    );
    expect(costsField, findsOneWidget);
    expect(tester.widget<TextFormField>(costsField).initialValue, '10');

    await tester.enterText(
      find.byKey(const ValueKey('v160-actual-sale-price')),
      '340',
    );
    await tester.enterText(costsField, '25,50');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(updated, isNotNull);
    expect(updated!.status, 'Sold');
    expect(updated!.actualSell, 340);
    expect(updated!.costs, 25.5);
    expect(updated!.realizedProfit, 94.5);
    expect(updated!.realizedRoi, closeTo(38.49, .01));

    monetization.dispose();
  });

  test('copyWith keeps costs unless an actual sale total replaces them', () {
    final flip = V13Flip(
      id: 'copy-costs',
      name: 'Test',
      category: 'Sonstiges',
      buy: 100,
      expectedAtBuy: 180,
      costs: 12,
      sourceCount: 0,
      confidence: 'Unbekannt',
      status: 'Bought',
      createdAt: DateTime(2026, 10, 12),
    );

    expect(flip.copyWith(status: 'Listed').costs, 12);
    expect(flip.copyWith(costs: 27.5).costs, 27.5);
  });

  testWidgets('sold card explains and corrects realized sale data',
      (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    V13Flip? updated;
    final soldAt = DateTime(2026, 10, 10);
    final sold = V13Flip(
      id: 'sold-correction-1',
      name: 'Apple iPhone 15 Pro 256 GB',
      category: 'Smartphone',
      buy: 600,
      expectedAtBuy: 800,
      costs: 20,
      sourceCount: 4,
      confidence: 'Hoch',
      status: 'Sold',
      createdAt: DateTime(2026, 10, 1),
      soldAt: soldAt,
      actualSell: 780,
      soldPlatform: 'eBay',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: V13FlipsPage(
          english: false,
          plan: UserPlan.free,
          flips: [sold],
          monetization: monetization,
          onUpdate: (value) => updated = value,
          onImportSales: (_) {},
          onDelete: (_) {},
          onRecheck: (_) {},
          onPro: () {},
          initialFilter: 'sold',
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('Verkauf 780 €'), findsOneWidget);
    expect(find.text('Investiert 620 €'), findsOneWidget);
    expect(find.text('ROI 26 %'), findsOneWidget);
    expect(find.text('eBay'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('v148-menu-sold-correction-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verkaufsdaten bearbeiten'));
    await tester.pumpAndSettle();

    final priceField = find.byKey(
      const ValueKey('v160-actual-sale-price'),
    );
    final costsField = find.byKey(
      const ValueKey('v160-actual-total-costs'),
    );
    expect(tester.widget<TextFormField>(priceField).initialValue, '780');
    expect(tester.widget<TextFormField>(costsField).initialValue, '20');

    await tester.enterText(priceField, '810');
    await tester.enterText(costsField, '35');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    expect(updated, isNotNull);
    expect(updated!.actualSell, 810);
    expect(updated!.costs, 35);
    expect(updated!.realizedProfit, 175);
    expect(updated!.soldAt, soldAt);

    monetization.dispose();
  });
}
