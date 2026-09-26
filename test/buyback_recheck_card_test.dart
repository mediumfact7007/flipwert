import 'package:flipwert/buyback.dart';
import 'package:flipwert/buyback_recheck_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows provider buyback and profit change on a saved-deal recheck', (tester) async {
    final offer = BuybackOffer(
        providerId: 'zoxs',
        providerName: 'ZOXS',
        productId: 'iphone-15-pro-256',
        matchedTitle: 'Apple iPhone 15 Pro 256 GB',
        condition: BuybackCondition.usedGood,
        price: 330,
        currency: 'EUR',
        offerUrl: Uri.parse('https://www.zoxs.de/offer/123'),
        checkedAt: DateTime.now().toUtc(),
        requiresInspection: true,
        matchConfidence: .98,
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BuybackRecheckCard(
      previousProvider: 'reBuy',
      previousPrice: 300,
      previousProfit: 50,
      currentOffer: offer,
      currentPurchasePrice: 250,
    ))));

    expect(find.byKey(const ValueKey('buyback-recheck-card')), findsOneWidget);
    expect(find.textContaining('Vorher: reBuy · 300,00 €'), findsOneWidget);
    expect(find.textContaining('Jetzt: ZOXS · 330,00 €'), findsOneWidget);
    expect(find.textContaining('Gewinn jetzt: 80,00 €'), findsOneWidget);
    expect(find.text('+30,00 €'), findsOneWidget);
  });
}
