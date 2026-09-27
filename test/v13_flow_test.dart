import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipwert/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('V0.13 universal search recognizes URLs, EAN, ASIN and common typos', () {
    final kleinanzeigen = normalizeV13Search(
      'https://www.kleinanzeigen.de/s-anzeige/apple-iphone-15-pro-256gb/1234567890-173-1234',
    );
    expect(kleinanzeigen.kind, V13InputKind.url);
    expect(kleinanzeigen.query.toLowerCase(), contains('iphone 15 pro 256gb'));

    final amazon = normalizeV13Search('https://www.amazon.de/dp/B0ABCDEFGH/');
    expect(amazon.kind, V13InputKind.asin);
    expect(amazon.query, 'B0ABCDEFGH');

    final ean = normalizeV13Search('4006381333931');
    expect(ean.kind, V13InputKind.ean);
    expect(ean.query, '4006381333931');

    final typo = normalizeV13Search('Playstaion 5 Slim');
    expect(typo.kind, V13InputKind.text);
    expect(typo.query.toLowerCase(), 'playstation 5 slim');
  });

  test('V0.13 shared listing detects item price but ignores shipping price', () {
    final shared = normalizeV13Search(
      'Apple iPhone 15 Pro 256 GB 650 € VB https://www.kleinanzeigen.de/s-anzeige/apple-iphone-15-pro-256gb/1234567890-173-1234',
    );
    expect(shared.detectedPrice, 650);
    expect(shared.query, isNot(contains('650')));

    final shippingOnly = normalizeV13Search(
      'Apple iPhone 15 Pro\nVersand 4,99 €\nhttps://www.kleinanzeigen.de/s-anzeige/apple-iphone-15-pro/1234567890-173-1234',
    );
    expect(shippingOnly.detectedPrice, isNull);
  });

  test('V0.13 personal stats learn sell speed and actual-vs-expected ratio', () {
    final base = DateTime(2026, 1, 1);
    final flips = <V13Flip>[
      V13Flip(id: '1', name: 'iPhone A', category: 'Smartphone', buy: 300, expectedAtBuy: 500, costs: 20, sourceCount: 8, confidence: 'Hoch', status: 'Sold', createdAt: base, soldAt: base.add(const Duration(days: 10)), actualSell: 480, soldPlatform: 'eBay'),
      V13Flip(id: '2', name: 'iPhone B', category: 'Smartphone', buy: 350, expectedAtBuy: 550, costs: 20, sourceCount: 9, confidence: 'Hoch', status: 'Sold', createdAt: base, soldAt: base.add(const Duration(days: 14)), actualSell: 528, soldPlatform: 'Kleinanzeigen'),
      V13Flip(id: '3', name: 'iPhone C', category: 'Smartphone', buy: 400, expectedAtBuy: 600, costs: 25, sourceCount: 10, confidence: 'Hoch', status: 'Sold', createdAt: base, soldAt: base.add(const Duration(days: 12)), actualSell: 576, soldPlatform: 'eBay'),
    ];

    final stats = V13PersonalStats.forCategory(flips, 'Smartphone');
    expect(stats.sample, 3);
    expect(stats.avgDays, closeTo(12, 0.001));
    expect(stats.saleFactor, closeTo(0.96, 0.001));
    expect(stats.speedLabel(false), 'Schnell');
  });

  test('V0.13 flip model keeps real sale data and calculates days to sell', () {
    final created = DateTime(2026, 2, 1);
    final flip = V13Flip(
      id: 'sale-1',
      name: 'PlayStation 5',
      category: 'Konsole',
      buy: 300,
      expectedAtBuy: 430,
      costs: 20,
      buybackSafetyReserve: 25,
      sourceCount: 7,
      confidence: 'Mittel',
      status: 'Sold',
      createdAt: created,
      soldAt: created.add(const Duration(days: 9)),
      actualSell: 420,
      soldPlatform: 'eBay',
    );
    final restored = V13Flip.fromJson(flip.toJson());
    expect(restored.daysToSell, 9);
    expect(restored.realizedProfit, 100);
    expect(restored.realizedRoi, closeTo(33.333, 0.01));
    expect(restored.soldPlatform, 'eBay');
    expect(restored.buybackSafetyReserve, 25);
  });

  testWidgets('V0.13 home is search-first and barcode remains secondary', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: V13Home(
            english: false,
            plan: UserPlan.free,
            history: const ['iPhone 15 Pro'],
            openFlips: 0,
            savedFlips: 0,
            staleSaved: 0,
            monetization: monetization,
            onSearch: (_) {},
            onScan: () {},
            onSettings: () {},
            onOpenFlips: () {},
            onOpenSaved: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Artikel rein.\nEntscheidung raus.'), findsOneWidget);
    expect(find.byKey(const ValueKey('v13-universal-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('v13-check-button')), findsOneWidget);
    expect(find.text('Barcode'), findsOneWidget);
    expect(find.text('JETZT SCANNEN'), findsNothing);

    monetization.dispose();
  });

  testWidgets('V0.13 shared item price is prefilled as buy price', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    await tester.pumpWidget(
      MaterialApp(
        home: V13CheckPage(
          english: false,
          input: normalizeV13Search('Test Produkt 149,99 € https://example.com/test-product'),
          targetRoi: 35,
          minProfit: 20,
          plan: UserPlan.free,
          taxMode: V13TaxMode.privateSeller,
          sources: const [],
          flips: const [],
          monetization: monetization,
          onHistory: (_) {},
          onAddFlip: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byKey(const ValueKey('v13-buy-input')));
    expect(field.controller?.text, '149,99');
    expect(find.textContaining('Angebotspreis automatisch erkannt'), findsOneWidget);
    monetization.dispose();
  });

  testWidgets('V0.13 manual sale price waits for confirmation before deciding', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    await tester.pumpWidget(
      MaterialApp(
        home: V13CheckPage(
          english: false,
          input: normalizeV13Search('Test Produkt'),
          targetRoi: 35,
          minProfit: 20,
          plan: UserPlan.free,
          taxMode: V13TaxMode.privateSeller,
          sources: const [],
          flips: const [],
          monetization: monetization,
          onHistory: (_) {},
          onAddFlip: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buyField = find.byKey(const ValueKey('v13-buy-input'));
    final saleField = find.byKey(const ValueKey('v13-manual-sale-input'));
    expect(buyField, findsOneWidget);
    expect(saleField, findsOneWidget);

    await tester.enterText(buyField, '100');
    await tester.enterText(saleField, '2');
    await tester.pump();
    expect(find.text('KAUFEN'), findsNothing);
    expect(saleField, findsOneWidget);

    await tester.enterText(saleField, '200');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('KAUFEN'), findsOneWidget);
    expect(find.textContaining('MAX 148'), findsOneWidget);
    expect(find.textContaining('Puffer bis zu deinem MAX'), findsOneWidget);

    monetization.dispose();
  });
}
