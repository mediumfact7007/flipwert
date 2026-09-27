import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipwert/buyback.dart';
import 'package:flipwert/buyback_offers_card.dart';

void main() {
  testWidgets('shows independent provider quotes and purchase margins without a private sale value', (tester) async {
    final checkedAt = DateTime.now().toUtc();
    Uri? opened;
    BuybackOffer offer(String id, double price, {bool affiliateLink = false}) => BuybackOffer(
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
          affiliateLink: affiliateLink,
        );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: BuybackOffersCard(
      offers: [offer('Provider A', 610), offer('Provider B', 650, affiliateLink: true), offer('Provider C', 450)],
      purchasePrice: 500,
      launcher: (uri) async {
        opened = uri;
        return true;
      },
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
    expect(find.text('Öffnen'), findsNWidgets(2));
    expect(find.text('Werbelink öffnen'), findsOneWidget);
    expect(find.byKey(const ValueKey('buyback-affiliate-note')), findsOneWidget);
    expect(find.textContaining('Provision erhalten'), findsOneWidget);

    await tester.tap(find.text('Werbelink öffnen'));
    await tester.pump();
    expect(opened, Uri.parse('https://example.com/Provider%20B'));
  });

  testWidgets('reports a provider handoff failure instead of staying silent',
      (tester) async {
    final offer = BuybackOffer(
      providerId: 'provider',
      providerName: 'Provider',
      productId: 'phone-256',
      matchedTitle: 'Phone 256 GB',
      condition: BuybackCondition.likeNew,
      price: 600,
      currency: 'EUR',
      offerUrl: Uri.parse('https://provider.example/offer/123'),
      checkedAt: DateTime.now().toUtc(),
      requiresInspection: true,
      matchConfidence: 0.98,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BuybackOffersCard(
          offers: [offer],
          purchasePrice: 500,
          launcher: (_) async => false,
        ),
      ),
    ));

    await tester.tap(find.text('Öffnen'));
    await tester.pump();

    expect(
      find.text('Der Anbieterlink konnte nicht geöffnet werden.'),
      findsOneWidget,
    );
  });
}
