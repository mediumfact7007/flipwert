import 'package:flipwert/dual_exit.dart';
import 'package:flipwert/dual_exit_card.dart';
import 'package:flipwert/resale_estimate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows both exits, range, reliability and duration side by side',
      (tester) async {
    const estimate = ResaleEstimate(
      low: 1299.99,
      likely: 1350,
      high: 1420,
      confidence: ResaleEstimateConfidence.high,
      estimatedDaysToSell: 12,
      ownSalesUsed: 4,
      activeEbayListingsUsed: 6,
      ownSalesScope: ResaleOwnSalesScope.exactModel,
      appliedEbayDiscount: .10,
    );
    final comparison = buildDualExitComparison(
      purchasePrice: 900,
      additionalCosts: 99.99,
      instantProceeds: 1100,
      marketEstimate: estimate,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DualExitCard(
            comparison: comparison,
            instantProvider: 'Anbieter A',
            instantRequiresInspection: false,
          ),
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('instant-exit-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('market-exit-panel')), findsOneWidget);
    expect(find.text('1.299,99 € – 1.420,00 €'), findsOneWidget);
    expect(find.text('Verlässlichkeit: Hoch'), findsOneWidget);
    expect(
      find.text(
          'Datengrundlage: 4 eigene Modellverkäufe · 6 aktive eBay-Angebote · 10 % Abschlag'),
      findsOneWidget,
    );
    expect(find.text('Geschätzt: 12 Tage'), findsOneWidget);
    expect(find.text('Gesamteinsatz: 999,99 €'), findsOneWidget);
    expect(find.text('Festes Geldangebot'), findsOneWidget);
  });

  testWidgets('explains category evidence and buyback-only estimates',
      (tester) async {
    const categoryEstimate = ResaleEstimate(
      low: 500,
      likely: 550,
      high: 600,
      confidence: ResaleEstimateConfidence.medium,
      estimatedDaysToSell: 20,
      ownSalesUsed: 1,
      activeEbayListingsUsed: 1,
      ownSalesScope: ResaleOwnSalesScope.category,
      appliedEbayDiscount: .125,
    );
    final comparison = buildDualExitComparison(
      purchasePrice: 400,
      additionalCosts: 20,
      instantProceeds: null,
      marketEstimate: categoryEstimate,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DualExitCard(
          comparison: comparison,
          instantProvider: null,
          instantRequiresInspection: false,
        ),
      ),
    ));

    expect(
      find.text(
          'Datengrundlage: 1 eigener Kategorieverkauf · 1 aktive eBay-Anzeige · 12,5 % Abschlag'),
      findsOneWidget,
    );

    const floorEstimate = ResaleEstimate(
      low: 300,
      likely: 300,
      high: 300,
      confidence: ResaleEstimateConfidence.low,
      estimatedDaysToSell: null,
      ownSalesUsed: 0,
      activeEbayListingsUsed: 0,
      ownSalesScope: ResaleOwnSalesScope.none,
      appliedEbayDiscount: .1,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DualExitCard(
          comparison: buildDualExitComparison(
            purchasePrice: 250,
            additionalCosts: 10,
            instantProceeds: null,
            marketEstimate: floorEstimate,
          ),
          instantProvider: null,
          instantRequiresInspection: false,
        ),
      ),
    ));

    expect(find.text('Datengrundlage: Nur Ankauf-Untergrenze'), findsOneWidget);
  });
}
