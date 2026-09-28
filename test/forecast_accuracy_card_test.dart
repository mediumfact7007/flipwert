import 'package:flipwert/forecast_accuracy_card.dart';
import 'package:flipwert/forecast_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows German prices, accuracy and learned discount', (tester) async {
    const latest = ForecastObservation(
      category: 'Smartphone',
      estimatedLikely: 1299.99,
      actualSalePrice: 1250,
    );
    const category = CategoryForecastAccuracy(
      category: 'Smartphone',
      samples: 4,
      hitRate: .75,
      meanAbsolutePercentageError: .083,
      ebayDiscount: .14,
      ebayCalibrationSamples: 3,
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ForecastAccuracyCard(categories: [category], latest: latest),
      ),
    ));

    expect(find.text('Letzte Prognose: 1.299,99 € → 1.250,00 €'), findsOneWidget);
    expect(find.text('Treffer: 75,0 %'), findsOneWidget);
    expect(find.text('eBay-Abschlag: 14,0 %'), findsOneWidget);
  });
}
