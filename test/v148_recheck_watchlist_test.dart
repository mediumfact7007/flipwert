import 'package:flipwert/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

V13Flip _saved(String id, DateTime checkedAt, {double buy = 220}) => V13Flip(
      id: id,
      name: 'Nintendo Switch OLED',
      category: 'Konsole',
      buy: buy,
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
  test('saved watchlist prioritizes the oldest checks first', () {
    final now = DateTime(2026, 9, 13, 21);
    final old = _saved('old', now.subtract(const Duration(days: 3)));
    final fresh = _saved('fresh', now.subtract(const Duration(hours: 2)));
    final bought = old.copyWith(status: 'Bought');

    final result = v148PrioritizeSaved([fresh, bought, old]);
    expect(result.map((e) => e.id).toList(), ['old', 'fresh']);
    expect(bought.isOpen, isTrue);
    expect(old.copyWith(status: 'Archived').isArchived, isTrue);
    expect(old.copyWith(status: 'Archived').isOpen, isFalse);
  });

  testWidgets('PRO fallback pricing is coherent when Play products are unavailable', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    await tester.pumpWidget(MaterialApp(
      home: V13Paywall(english: false, monetization: monetization),
    ));
    await tester.pump();

    expect(find.text('39,99 € / Jahr · ≈ 3,33 € / Monat'), findsOneWidget);
    expect(find.text('4,99 € / Monat'), findsOneWidget);
    expect(find.text('33 % SPAREN'), findsOneWidget);

    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    monetization.dispose();
  });

  testWidgets('recheck uses entered asking price and updates the same snapshot', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    final oldCheck = DateTime.now().subtract(const Duration(days: 2));
    final existing = _saved('saved-1', oldCheck);
    V13Flip? updated;
    var adds = 0;
    final input = normalizeV13Search(
      'Nintendo Switch OLED https://www.kleinanzeigen.de/s-anzeige/nintendo-switch-oled/1234567890-279-1234',
    );

    await tester.pumpWidget(MaterialApp(
      home: V13CheckPage(
        english: false,
        input: input,
        targetRoi: 35,
        minProfit: 20,
        plan: UserPlan.free,
        taxMode: V13TaxMode.privateSeller,
        sources: const [],
        flips: [existing],
        monetization: monetization,
        onHistory: (_) {},
        onAddFlip: (_) => adds++,
        existingSnapshot: existing,
        onUpdateFlip: (value) => updated = value,
      ),
    ));
    await tester.pumpAndSettle();

    final buyField = tester.widget<TextField>(find.byKey(const ValueKey('v13-buy-input')));
    expect(buyField.controller?.text, '220');
    await tester.enterText(find.byKey(const ValueKey('v13-buy-input')), '205');
    await tester.pump();

    final saleFinder = find.byKey(const ValueKey('v13-manual-sale-input'));
    final saleField = tester.widget<TextField>(saleFinder);
    expect(saleField.controller?.text, '350');
    await tester.enterText(saleFinder, '350');
    saleField.onSubmitted?.call('350');
    await tester.pump();

    final remember = find.byKey(const ValueKey('v147-remember-deal'));
    await tester.scrollUntilVisible(
      remember,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(remember, findsOneWidget);
    expect(find.text('CHECK ÜBERNEHMEN'), findsOneWidget);
    expect(find.text('MERKEN'), findsNothing);
    final rememberButton = tester.widget<OutlinedButton>(remember);
    expect(rememberButton.onPressed, isNotNull);
    rememberButton.onPressed!();
    await tester.pump();

    expect(adds, 0);
    expect(updated, isNotNull);
    expect(updated!.id, existing.id);
    expect(updated!.buy, 205);
    expect(updated!.expectedAtBuy, 350);
    expect(updated!.checkedAt.isAfter(oldCheck), isTrue);
    expect(find.byKey(const ValueKey('v159-recheck-baseline-accepted')), findsOneWidget);
    expect(
      find.text('Prüfstand übernommen. Künftige Deal-Alarme vergleichen mit diesen Werten.'),
      findsOneWidget,
    );
    expect(find.text('Deal aktualisiert.'), findsOneWidget);
    monetization.dispose();
  });

  testWidgets('saved deal can be archived from its management menu', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    final saved = _saved('saved-menu', DateTime.now().subtract(const Duration(days: 2)));
    V13Flip? updated;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: V13FlipsPage(
          english: false,
          plan: UserPlan.free,
          flips: [saved],
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
    await tester.tap(find.text('Merkliste'));
    await tester.pumpAndSettle();

    final menu = find.byKey(const ValueKey('v148-menu-saved-menu'));
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archivieren'));
    await tester.pumpAndSettle();

    expect(updated?.status, 'Archived');
    monetization.dispose();
  });
}
