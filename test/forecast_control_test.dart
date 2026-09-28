import 'package:flipwert/forecast_control.dart';
import 'package:flipwert/v13_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates range hits and forecast error per category', () {
    const rows = [
      ForecastObservation(
        category: 'Smartphone',
        estimatedLikely: 1000,
        estimatedLow: 900,
        estimatedHigh: 1100,
        actualSalePrice: 1050,
      ),
      ForecastObservation(
        category: 'Smartphone',
        estimatedLikely: 1000,
        estimatedLow: 900,
        estimatedHigh: 1100,
        actualSalePrice: 1200,
      ),
    ];

    final result = forecastAccuracyByCategory(rows).single;
    expect(result.samples, 2);
    expect(result.hitRate, .5);
    expect(result.meanAbsolutePercentageError, closeTo(.125, .0001));
  });

  test('eBay discount learns after each sale without abrupt jumps', () {
    const row = ForecastObservation(
      category: 'Laptop',
      estimatedLikely: 850,
      actualSalePrice: 800,
      ebayAskingReference: 1000,
    );

    expect(
      calibratedEbayDiscount(category: 'Laptop', observations: const [row]),
      closeTo(.12, .0001),
    );
    expect(
      calibratedEbayDiscount(category: 'Smartphone', observations: const [row]),
      .10,
    );
  });

  test('five sales fully calibrate discount and invalid rows are ignored', () {
    final rows = List.generate(
      5,
      (_) => const ForecastObservation(
        category: 'Konsole',
        estimatedLikely: 500,
        actualSalePrice: 700,
        ebayAskingReference: 1000,
      ),
    )..add(const ForecastObservation(
        category: '', estimatedLikely: 0, actualSalePrice: -1));

    expect(
      calibratedEbayDiscount(category: 'Konsole', observations: rows),
      closeTo(.30, .0001),
    );
    expect(forecastAccuracyByCategory(rows).single.samples, 5);
  });

  test('fallback discount must be valid', () {
    expect(
      () => calibratedEbayDiscount(
        category: 'Laptop',
        observations: const [],
        fallback: 1,
      ),
      throwsArgumentError,
    );
  });

  test('user base discount is used until category learning is available', () {
    const row = ForecastObservation(
      category: 'Kamera',
      estimatedLikely: 700,
      actualSalePrice: 690,
    );

    final result = forecastAccuracyByCategory(
      const [row],
      fallbackEbayDiscount: .18,
    ).single;
    expect(result.ebayDiscount, .18);
    expect(result.ebayCalibrationSamples, 0);
  });

  test('deal snapshot fields survive persistence and create an observation', () {
    final flip = V13Flip(
      id: 'forecast-1',
      name: 'Pixel 9',
      category: 'Smartphone',
      buy: 500,
      expectedAtBuy: 800,
      costs: 25,
      sourceCount: 5,
      confidence: 'Mittel',
      status: 'Sold',
      createdAt: DateTime(2026, 9, 1),
      soldAt: DateTime(2026, 9, 10),
      actualSell: 780,
      forecastLikelyAtBuy: 800,
      forecastLowAtBuy: 750,
      forecastHighAtBuy: 850,
      ebayReferenceAtBuy: 900,
      ebayDiscountAtBuy: .11,
    );

    final restored = V13Flip.fromJson(flip.toJson());
    final observation = v13ForecastObservations([restored]).single;
    expect(restored.forecastLowAtBuy, 750);
    expect(restored.ebayDiscountAtBuy, .11);
    expect(observation.estimatedLikely, 800);
    expect(observation.hit, isTrue);
  });

  test('CSV-only sales without a captured forecast are not scored', () {
    final imported = V13Flip(
      id: 'csv-1',
      name: 'Pixel 9',
      category: 'Smartphone',
      buy: 500,
      expectedAtBuy: 0,
      costs: 25,
      sourceCount: 0,
      confidence: 'Eigener Verkauf',
      status: 'Sold',
      createdAt: DateTime(2026, 9, 1),
      soldAt: DateTime(2026, 9, 10),
      actualSell: 780,
    );

    expect(v13ForecastObservations([imported]), isEmpty);
  });
}
