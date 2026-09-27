import 'package:flipwert/buyback.dart';
import 'package:flipwert/buyback_summary.dart';
import 'package:flipwert/buyback_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BuybackComparisonSummary summaryWithUrl(
  Uri url, {
  double buybackPrice = 620,
  double safetyReserve = 0,
  DateTime? expiresAt,
}) {
  return BuybackComparisonSummary(
    offer: BuybackOffer(
      providerId: 'provider',
      providerName: 'Provider',
      productId: 'iphone-15-pro-256',
      matchedTitle: 'Apple iPhone 15 Pro 256 GB',
      condition: BuybackCondition.likeNew,
      price: buybackPrice,
      currency: 'EUR',
      offerUrl: url,
      checkedAt: DateTime.parse('2026-09-21T12:00:00Z'),
      requiresInspection: true,
      matchConfidence: 0.98,
      expiresAt: expiresAt,
    ),
    purchasePrice: 500,
    privateMarketValue: 680,
    safetyReserve: safetyReserve,
  );
}

void main() {
  test('reserve can prefer a firm quote over a higher provisional quote', () {
    final now = DateTime.now().toUtc();
    BuybackOffer offer(
      String id,
      double price, {
      required bool requiresInspection,
    }) =>
        BuybackOffer(
          providerId: id,
          providerName: id,
          productId: 'iphone-15-pro-256',
          matchedTitle: 'Apple iPhone 15 Pro 256 GB',
          condition: BuybackCondition.likeNew,
          price: price,
          currency: 'EUR',
          offerUrl: Uri.parse('https://example.com/$id'),
          checkedAt: now,
          requiresInspection: requiresInspection,
          matchConfidence: 0.98,
        );

    final summary = buildBuybackComparisonSummary(
      [
        offer('provisional', 650, requiresInspection: true),
        offer('firm', 640, requiresInspection: false),
      ],
      condition: BuybackCondition.likeNew,
      purchasePrice: 500,
      privateMarketValue: 680,
      safetyReserve: 20,
      now: now,
    );

    expect(summary, isNotNull);
    expect(summary!.offer.providerId, 'firm');
    expect(summary.appliedSafetyReserve, 0);
    expect(summary.instantMargin, 140);
  });

  testWidgets('buyback action stays disabled for non-public offer targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuybackComparisonCard(
            summary: summaryWithUrl(Uri.parse('https://127.0.0.1/offer')),
          ),
        ),
      ),
    );

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('buyback-open-offer')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Angebotslink nicht verfügbar'), findsOneWidget);
  });

  testWidgets('buyback action stays enabled for a trusted public offer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuybackComparisonCard(
            summary: summaryWithUrl(Uri.parse('https://example.com/offer')),
          ),
        ),
      ),
    );

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('buyback-open-offer')),
    );
    expect(button.onPressed, isNotNull);
    expect(find.textContaining('Geldauszahlung'), findsOneWidget);
  });

  testWidgets('shows the provider-specific offer expiry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuybackComparisonCard(
            summary: summaryWithUrl(
              Uri.parse('https://example.com/offer'),
              expiresAt: DateTime.parse('2026-09-21T13:00:00Z'),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('buyback-expiry-note')), findsOneWidget);
  });

  testWidgets('shows the purchase basis used for both profit calculations', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuybackComparisonCard(
            summary: summaryWithUrl(Uri.parse('https://example.com/offer')),
          ),
        ),
      ),
    );

    expect(find.text('Basis: Gesamteinsatz 500 €'), findsOneWidget);
    expect(
      find.text('Gesamteinsatz = Einkaufspreis + eingetragene Zusatzkosten.'),
      findsOneWidget,
    );
  });

  testWidgets('shows provider product match quality for trust', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuybackComparisonCard(
            summary: summaryWithUrl(Uri.parse('https://example.com/offer')),
          ),
        ),
      ),
    );

    expect(find.text('Produkt-Treffer: 98 %'), findsOneWidget);
  });

  testWidgets('recommendation states the concrete private-sale profit advantage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuybackComparisonCard(
            summary: summaryWithUrl(Uri.parse('https://example.com/offer')),
          ),
        ),
      ),
    );

    expect(find.text('Privatverkauf: 60 € mehr Gewinn'), findsOneWidget);
  });

  testWidgets('inspection-dependent buyback advantage is clearly provisional', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuybackComparisonCard(
            summary: summaryWithUrl(
              Uri.parse('https://example.com/offer'),
              buybackPrice: 720,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sofortankauf: 40 € mehr Gewinn (vor Prüfung)'), findsOneWidget);
    expect(find.text('720 €*'), findsOneWidget);
    expect(
      find.text(
        '* Vorläufiger Ankaufspreis: Der Anbieter kann ihn nach Prüfung ändern.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('optional reserve reduces only the provisional buyback margin', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuybackComparisonCard(
            summary: summaryWithUrl(
              Uri.parse('https://example.com/offer'),
              buybackPrice: 720,
              safetyReserve: 30,
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('Sofortankauf: 10 € mehr Gewinn (vor Prüfung)'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Konservativ gerechnet: 690 € Ankaufserlös nach 30 € Sicherheitsabschlag.',
      ),
      findsOneWidget,
    );
  });
}
