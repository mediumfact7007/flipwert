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

      monetization.dispose();
    },
  );
}
