import 'package:flipwert/buyback.dart';
import 'package:flipwert/buyback_recheck_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows provider buyback and profit change on a saved-deal recheck', (tester) async {
    Uri? opened;
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
      launcher: (uri) async {
        opened = uri;
        return true;
      },
    ))));

    expect(find.byKey(const ValueKey('buyback-recheck-card')), findsOneWidget);
    expect(find.textContaining('Vorher: reBuy · 300,00 €'), findsOneWidget);
    expect(find.textContaining('Jetzt: ZOXS · 330,00 €'), findsOneWidget);
    expect(find.textContaining('Gewinn jetzt: 80,00 €'), findsOneWidget);
    expect(find.text('+30,00 €'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('buyback-recheck-open-current')));
    await tester.pump();
    expect(opened, offer.offerUrl);
  });

  testWidgets('reports when the current provider link cannot be opened',
      (tester) async {
    final offer = BuybackOffer(
      providerId: 'provider',
      providerName: 'Provider',
      productId: 'phone-256',
      matchedTitle: 'Phone 256 GB',
      condition: BuybackCondition.likeNew,
      price: 330,
      currency: 'EUR',
      offerUrl: Uri.parse('https://provider.example/offer/123'),
      checkedAt: DateTime.now().toUtc(),
      requiresInspection: true,
      matchConfidence: .98,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BuybackRecheckCard(
          previousProvider: 'Provider',
          previousPrice: 300,
          previousProfit: 50,
          currentOffer: offer,
          currentPurchasePrice: 250,
          launcher: (_) async => false,
        ),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('buyback-recheck-open-current')));
    await tester.pump();

    expect(
      find.text('Der Anbieterlink konnte nicht geöffnet werden.'),
      findsOneWidget,
    );
  });

  testWidgets('shows when a previous LIVE offer no longer has a match',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BuybackRecheckCard(
          previousProvider: 'ZOXS',
          previousPrice: 300,
          previousProfit: 50,
          currentOffer: null,
          currentPurchasePrice: 250,
          availability: BuybackRecheckAvailability.noMatch,
        ),
      ),
    ));

    expect(find.text('Aktuell kein Angebot'), findsOneWidget);
    expect(find.textContaining('Vorher: ZOXS · 300,00 €'), findsOneWidget);
    expect(find.textContaining('kein qualitätsgeprüftes LIVE-Ankaufangebot'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('buyback-recheck-open-current')),
        findsNothing);
  });

  testWidgets('does not treat a provider outage as a zero price',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BuybackRecheckCard(
          previousProvider: 'reBuy',
          previousPrice: 280,
          previousProfit: 40,
          currentOffer: null,
          currentPurchasePrice: 240,
          availability: BuybackRecheckAvailability.sourceUnavailable,
        ),
      ),
    ));

    expect(find.text('Prüfung nicht möglich'), findsOneWidget);
    expect(find.textContaining('historischer Wert'), findsOneWidget);
    expect(find.text('0,00 €'), findsNothing);
  });

  testWidgets('explains when LIVE approval is not ready', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: BuybackRecheckCard(
          previousProvider: 'Partner',
          previousPrice: 260,
          previousProfit: 20,
          currentOffer: null,
          currentPurchasePrice: 240,
          availability: BuybackRecheckAvailability.sourceNotReady,
        ),
      ),
    ));

    expect(find.text('LIVE-Quelle nicht bereit'), findsOneWidget);
    expect(find.textContaining('keinen Ersatzpreis'), findsOneWidget);
  });
}
