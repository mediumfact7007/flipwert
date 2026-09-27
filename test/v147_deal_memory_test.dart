import 'package:flipwert/main.dart';
import 'package:flipwert/buyback.dart';
import 'package:flipwert/buyback_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deal snapshot keeps new fields and remains backward compatible', () {
    final checked = DateTime(2026, 9, 13, 18, 0);
    final flip = V13Flip(
      id: 'watch-1',
      name: 'Nintendo Switch OLED',
      category: 'Konsole',
      buy: 220,
      expectedAtBuy: 350,
      costs: 10,
      sourceCount: 8,
      confidence: 'Hoch',
      status: 'Saved',
      createdAt: checked,
      checkedAt: checked,
      sourceUrl: 'https://www.kleinanzeigen.de/s-anzeige/nintendo-switch-oled/1234567890-279-1234',
      maxBuyAtCheck: 251.85,
      profitAtCheck: 120,
      roiAtCheck: 54.5,
      confidenceScore: 78,
      buybackPriceAtCheck: 285,
      buybackProviderAtCheck: 'ZOXS',
      buybackConditionAtCheck: 'used_good',
      buybackCheckedAt: checked,
      buybackQuoteKindAtCheck: 'live_provider',
    );

    final restored = V13Flip.fromJson(flip.toJson());
    expect(restored.isSaved, isTrue);
    expect(restored.isOpen, isFalse);
    expect(restored.sourceUrl, contains('kleinanzeigen.de'));
    expect(restored.maxBuyAtCheck, closeTo(251.85, .001));
    expect(restored.profitAtCheck, 120);
    expect(restored.roiAtCheck, 54.5);
    expect(restored.confidenceScore, 78);
    expect(restored.checkedAt, checked);
    expect(restored.buybackPriceAtCheck, 285);
    expect(restored.buybackProviderAtCheck, 'ZOXS');
    expect(restored.buybackConditionAtCheck, 'used_good');
    expect(restored.buybackCheckedAt, checked.toUtc());
    expect(restored.buybackQuoteKindAtCheck, 'live_provider');

    final legacy = V13Flip.fromJson({
      'id': 'old',
      'name': 'Legacy Flip',
      'buy': 100,
      'expectedAtBuy': 160,
      'costs': 0,
      'sourceCount': 0,
      'confidence': 'Unbekannt',
      'status': 'Bought',
      'createdAt': checked.toIso8601String(),
    });
    expect(legacy.checkedAt, checked);
    expect(legacy.sourceUrl, isEmpty);
    expect(legacy.maxBuyAtCheck, 0);
    expect(legacy.buybackPriceAtCheck, 0);
    expect(legacy.buybackProviderAtCheck, isEmpty);
    expect(legacy.buybackQuoteKindAtCheck, isEmpty);
    expect(legacy.isOpen, isTrue);
  });

  test('snapshot age is human readable', () {
    final now = DateTime(2026, 9, 13, 20, 0);
    expect(v147AgeLabel(now.subtract(const Duration(minutes: 12)), false, now: now), 'vor 12 Min');
    expect(v147AgeLabel(now.subtract(const Duration(hours: 5)), false, now: now), 'vor 5 Std');
    expect(v147AgeLabel(now.subtract(const Duration(days: 3)), false, now: now), 'vor 3 T');
  });

  testWidgets('check page can remember a complete deal snapshot before buying', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    V13Flip? saved;
    final input = normalizeV13Search(
      'Nintendo Switch OLED\n220 €\nhttps://www.kleinanzeigen.de/s-anzeige/nintendo-switch-oled/1234567890-279-1234',
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
        flips: const [],
        monetization: monetization,
        onHistory: (_) {},
        onAddFlip: (value) => saved = value,
      ),
    ));
    await tester.pumpAndSettle();

    final saleField = find.byKey(const ValueKey('v13-manual-sale-input'));
    await tester.enterText(saleField, '350');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final remember = find.byKey(const ValueKey('v147-remember-deal'));
    await tester.scrollUntilVisible(
      remember,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(remember, findsOneWidget);
    await tester.pump();
    await tester.tap(remember);
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.status, 'Saved');
    expect(saved!.buy, 220);
    expect(saved!.expectedAtBuy, 350);
    expect(saved!.maxBuyAtCheck, greaterThan(250));
    expect(saved!.profitAtCheck, 130);
    expect(saved!.roiAtCheck, greaterThan(59));
    expect(saved!.sourceUrl, contains('kleinanzeigen.de/s-anzeige/'));
    expect(find.text('Deal gemerkt.'), findsOneWidget);

    monetization.dispose();
  });

  testWidgets('saved deal is separate from open capital and can become bought', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    V13Flip? updated;
    final oldCheck = DateTime.now().subtract(const Duration(days: 2));
    final saved = V13Flip(
      id: 'saved-1',
      name: 'Nintendo Switch OLED',
      category: 'Konsole',
      buy: 220,
      expectedAtBuy: 350,
      costs: 0,
      sourceCount: 5,
      confidence: 'Mittel',
      status: 'Saved',
      createdAt: oldCheck,
      checkedAt: oldCheck,
      maxBuyAtCheck: 259,
      profitAtCheck: 130,
      roiAtCheck: 59.1,
      confidenceScore: 55,
    );

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

    expect(find.text('Noch nichts hier'), findsOneWidget);
    await tester.tap(find.text('Merkliste'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('v147-snapshot-age')), findsOneWidget);
    expect(find.textContaining('Preise können veraltet sein'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('v147-mark-bought')));
    await tester.pump();

    expect(updated, isNotNull);
    expect(updated!.status, 'Bought');
    expect(updated!.isOpen, isTrue);
    expect(updated!.checkedAt, oldCheck);
    expect(updated!.createdAt.isAfter(oldCheck), isTrue);

    monetization.dispose();
  });

  testWidgets('saved buyback condition is refreshed and compared automatically', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    BuybackCondition? requestedCondition;
    String? requestedQuery;
    final checked = DateTime.now().subtract(const Duration(hours: 2));
    final saved = V13Flip(
      id: 'saved-buyback-1',
      name: 'Apple iPhone 15 Pro 256 GB',
      category: 'Smartphone',
      buy: 250,
      expectedAtBuy: 390,
      costs: 0,
      sourceCount: 0,
      confidence: 'Mittel',
      status: 'Saved',
      createdAt: checked,
      checkedAt: checked,
      buybackPriceAtCheck: 300,
      buybackProviderAtCheck: 'reBuy',
      buybackConditionAtCheck: 'used_good',
      buybackCheckedAt: checked,
      buybackQuoteKindAtCheck: 'live_provider',
    );

    await tester.pumpWidget(MaterialApp(
      home: V13CheckPage(
        english: false,
        input: normalizeV13Search(saved.name),
        targetRoi: 35,
        minProfit: 20,
        plan: UserPlan.pro,
        taxMode: V13TaxMode.privateSeller,
        sources: const [],
        flips: [saved],
        monetization: monetization,
        existingSnapshot: saved,
        onHistory: (_) {},
        onAddFlip: (_) {},
        buybackSearch: (query, condition) async {
          requestedQuery = query;
          requestedCondition = condition;
          return BuybackSearchResult(
            configured: true,
            live: true,
            unavailable: false,
            offers: [
              BuybackOffer(
                providerId: 'zoxs',
                providerName: 'ZOXS',
                productId: 'iphone-15-pro-256',
                matchedTitle: 'Apple iPhone 15 Pro 256 GB',
                condition: condition,
                price: 330,
                currency: 'EUR',
                offerUrl: Uri.parse('https://www.zoxs.de/offer/123'),
                checkedAt: DateTime.now().toUtc(),
                requiresInspection: true,
                matchConfidence: .98,
              ),
            ],
          );
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(requestedQuery, 'Apple iPhone 15 Pro 256 GB');
    expect(requestedCondition, BuybackCondition.usedGood);
    final recheckCard = find.byKey(const ValueKey('buyback-recheck-card'));
    await tester.scrollUntilVisible(
      recheckCard,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(recheckCard, findsOneWidget);
    expect(find.textContaining('Vorher: reBuy · 300,00 €'), findsOneWidget);
    expect(find.textContaining('Jetzt: ZOXS · 330,00 €'), findsOneWidget);

    monetization.dispose();
  });
}
