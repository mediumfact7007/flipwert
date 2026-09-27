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
    expect(find.text('Geschätzt: 12 Tage'), findsOneWidget);
    expect(find.text('Gesamteinsatz: 999,99 €'), findsOneWidget);
    expect(find.text('Festes Geldangebot'), findsOneWidget);
  });
}
