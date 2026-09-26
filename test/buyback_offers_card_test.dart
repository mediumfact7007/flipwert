import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipwert/buyback.dart';
import 'package:flipwert/buyback_offers_card.dart';

void main() {
  testWidgets('shows independent provider quotes and purchase margins without a private sale value', (tester) async {
    final checkedAt = DateTime.now().toUtc();
    BuybackOffer offer(String id, double price) => BuybackOffer(
          providerId: id,
          providerName: id,
          productId: 'iphone-15-pro-256',
          matchedTitle: 'Apple iPhone 15 Pro 256 GB',
          condition: BuybackCondition.likeNew,
          price: price,
          currency: 'EUR',
          offerUrl: Uri.parse('https://example.com/$id'),
          checkedAt: checkedAt,
          requiresInspection: true,
          matchConfidence: 0.98,
        );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: BuybackOffersCard(
      offers: [offer('Provider A', 610), offer('Provider B', 650), offer('Provider C', 450)],
      purchasePrice: 500,
    )))));
    expect(find.byKey(const ValueKey('buyback-offers-card')), findsOneWidget);
    expect(find.text('650,00 €*'), findsOneWidget);
    expect(find.text('Gewinn nach Einkauf: 150,00 €'), findsOneWidget);
    expect(find.text('610,00 €*'), findsOneWidget);
    expect(find.text('Gewinn nach Einkauf: 110,00 €'), findsOneWidget);
    expect(find.text('450,00 €*'), findsOneWidget);
    expect(find.text('Verlust nach Einkauf: 50,00 €'), findsOneWidget);
    expect(find.text('3 qualitätsgeprüfte Anbieterangebote'), findsOneWidget);
    expect(find.text('Beste Marge'), findsOneWidget);
    expect(find.text('Zustand: Wie neu · Prüfung ausstehend'), findsNWidgets(3));
    expect(find.byKey(const ValueKey('buyback-inspection-note')), findsOneWidget);
    expect(find.text('Öffnen'), findsNWidgets(3));
  });
}
