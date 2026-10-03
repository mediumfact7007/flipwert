import 'package:flipwert/buyback.dart';
import 'package:flipwert/buyback_client.dart';
import 'package:flipwert/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'LIVE buyback-only deal keeps provider provenance without inventing private value',
    (tester) async {
      final monetization = V13Monetization(onProUnlocked: () {});
      V13Flip? saved;

      await tester.pumpWidget(MaterialApp(
        home: V13CheckPage(
          english: false,
          input: normalizeV13Search('Apple iPhone 15 Pro 256 GB'),
          targetRoi: 35,
          minProfit: 20,
          plan: UserPlan.free,
          taxMode: V13TaxMode.privateSeller,
          sources: const [],
          flips: const [],
          monetization: monetization,
          onHistory: (_) {},
          onAddFlip: (value) => saved = value,
          buybackSearch: (query, condition) async => BuybackSearchResult(
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
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('v13-buy-input')),
        '250',
      );
      await tester.pump();

      final condition = find.byKey(const ValueKey('v151-buyback-condition'));
      await tester.scrollUntilVisible(
        condition,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(condition);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sehr gut').last);
      await tester.pumpAndSettle();

      final remember =
          find.byKey(const ValueKey('buyback-only-remember-deal'));
      await tester.scrollUntilVisible(
        remember,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(remember, findsOneWidget);
      expect(
        find.textContaining('fehlender Privatmarktwert wird nicht geschätzt'),
        findsOneWidget,
      );

      await tester.tap(remember);
      await tester.pump();

      expect(saved, isNotNull);
      expect(saved!.expectedAtBuy, 0);
      expect(saved!.maxBuyAtCheck, 0);
      expect(saved!.profitAtCheck, 0);
      expect(saved!.roiAtCheck, 0);
      expect(saved!.buybackPriceAtCheck, 330);
      expect(saved!.buybackProviderAtCheck, 'ZOXS');
      expect(saved!.buybackConditionAtCheck, 'very_good');
      expect(saved!.buybackQuoteKindAtCheck, 'live_provider');
      expect(saved!.buybackCheckedAt, isNotNull);
      expect(saved!.buybackSafetyReserve, 0);

      monetization.dispose();
    },
  );

  testWidgets(
    'LIVE buyback-only saved deal shows a visible recheck without private market value',
    (tester) async {
      final now = DateTime.now();
      final saved = V13Flip(
        id: 'buyback-only-1',
        name: 'Apple iPhone 15 Pro 256 GB',
        category: 'Elektronik',
        buy: 250,
        expectedAtBuy: 0,
        costs: 10,
        buybackSafetyReserve: 20,
        sourceCount: 0,
        confidence: '',
        status: 'Saved',
        createdAt: now.subtract(const Duration(days: 1)),
        checkedAt: now.subtract(const Duration(days: 1)),
        maxBuyAtCheck: 0,
        profitAtCheck: 0,
        roiAtCheck: 0,
        buybackPriceAtCheck: 300,
        buybackProviderAtCheck: 'reBuy',
        buybackConditionAtCheck: 'very_good',
        buybackCheckedAt: now.subtract(const Duration(days: 1)),
        buybackQuoteKindAtCheck: 'live_provider',
      );
      final monetization = V13Monetization(onProUnlocked: () {});

      await tester.pumpWidget(MaterialApp(
        home: V13CheckPage(
          english: false,
          input: normalizeV13Search(saved.name),
          targetRoi: 35,
          minProfit: 20,
          plan: UserPlan.free,
          taxMode: V13TaxMode.privateSeller,
          sources: const [],
          flips: [saved],
          existingSnapshot: saved,
          monetization: monetization,
          onHistory: (_) {},
          onAddFlip: (_) {},
          buybackSearch: (query, condition) async => BuybackSearchResult(
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
                price: 340,
                currency: 'EUR',
                offerUrl: Uri.parse('https://www.zoxs.de/offer/123'),
                checkedAt: DateTime.now().toUtc(),
                requiresInspection: true,
                matchConfidence: .98,
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final recheck = find.byKey(const ValueKey('buyback-recheck-card'));
      await tester.scrollUntilVisible(
        recheck,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(recheck, findsOneWidget);
      expect(find.textContaining('Vorher: reBuy · 300,00 €'), findsOneWidget);
      expect(find.textContaining('Jetzt: ZOXS · 340,00 €'), findsOneWidget);
      expect(find.textContaining('Gewinn jetzt: 60,00 €'), findsOneWidget);
      expect(find.text('+40,00 €'), findsOneWidget);
      expect(find.text('CHECK ÜBERNEHMEN'), findsOneWidget);

      monetization.dispose();
    },
  );

  testWidgets(
    'saved LIVE buyback shows that a matching offer disappeared',
    (tester) async {
      final now = DateTime.now();
      final saved = V13Flip(
        id: 'buyback-gone-1',
        name: 'Apple iPhone 15 Pro 256 GB',
        category: 'Elektronik',
        buy: 250,
        expectedAtBuy: 0,
        costs: 10,
        buybackSafetyReserve: 20,
        sourceCount: 0,
        confidence: '',
        status: 'Saved',
        createdAt: now.subtract(const Duration(days: 1)),
        checkedAt: now.subtract(const Duration(days: 1)),
        maxBuyAtCheck: 0,
        profitAtCheck: 0,
        roiAtCheck: 0,
        buybackPriceAtCheck: 300,
        buybackProviderAtCheck: 'ZOXS',
        buybackConditionAtCheck: 'very_good',
        buybackCheckedAt: now.subtract(const Duration(days: 1)),
        buybackQuoteKindAtCheck: 'live_provider',
      );
      final monetization = V13Monetization(onProUnlocked: () {});

      await tester.pumpWidget(MaterialApp(
        home: V13CheckPage(
          english: false,
          input: normalizeV13Search(saved.name),
          targetRoi: 35,
          minProfit: 20,
          plan: UserPlan.free,
          taxMode: V13TaxMode.privateSeller,
          sources: const [],
          flips: [saved],
          existingSnapshot: saved,
          monetization: monetization,
          onHistory: (_) {},
          onAddFlip: (_) {},
          buybackSearch: (query, condition) async => const BuybackSearchResult(
            configured: true,
            live: false,
            unavailable: false,
            readiness: BuybackReadiness.ready,
            offers: [],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final recheck = find.byKey(const ValueKey('buyback-recheck-card'));
      await tester.scrollUntilVisible(
        recheck,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(recheck, findsOneWidget);
      expect(find.text('Aktuell kein Angebot'), findsOneWidget);
      expect(find.textContaining('Vorher: ZOXS · 300,00 €'), findsOneWidget);
      expect(find.textContaining('kein qualitätsgeprüftes LIVE-Ankaufangebot'),
          findsOneWidget);
      expect(find.text('0,00 €'), findsNothing);

      monetization.dispose();
    },
  );

}
