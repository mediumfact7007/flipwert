import 'package:flipwert/buyback.dart';
import 'package:flipwert/buyback_client.dart';
import 'package:flipwert/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows that an approved feed still awaits technical activation',
    (tester) async {
      final monetization = V13Monetization(onProUnlocked: () {});

      await tester.pumpWidget(
        MaterialApp(
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
            onAddFlip: (_) {},
            buybackSearch: (_, __) async => const BuybackSearchResult(
              offers: [],
              configured: false,
              live: false,
              unavailable: false,
              readiness: BuybackReadiness.awaitingValidation,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final condition =
          find.byKey(const ValueKey('v151-buyback-condition'));
      await tester.scrollUntilVisible(
        condition,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(condition);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sehr gut').last);
      await tester.pumpAndSettle();

      expect(
        find.text('LIVE-Ankaufquelle wartet auf technische Freigabe'),
        findsOneWidget,
      );
      expect(
        find.textContaining('repräsentative Geräte-, Varianten- und'),
        findsOneWidget,
      );

      monetization.dispose();
    },
  );
}
