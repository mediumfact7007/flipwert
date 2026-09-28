import 'dart:math' as math;

class ForecastObservation {
  final String category;
  final double estimatedLikely;
  final double estimatedLow;
  final double estimatedHigh;
  final double actualSalePrice;
  final double ebayAskingReference;

  const ForecastObservation({
    required this.category,
    required this.estimatedLikely,
    required this.actualSalePrice,
    this.estimatedLow = 0,
    this.estimatedHigh = 0,
    this.ebayAskingReference = 0,
  });

  double get percentageError =>
      (actualSalePrice - estimatedLikely) / estimatedLikely;

  bool get hit {
    if (estimatedLow > 0 && estimatedHigh >= estimatedLow) {
      return actualSalePrice >= estimatedLow && actualSalePrice <= estimatedHigh;
    }
    return percentageError.abs() <= .10;
  }
}

class CategoryForecastAccuracy {
  final String category;
  final int samples;
  final double hitRate;
  final double meanAbsolutePercentageError;
  final double ebayDiscount;
  final int ebayCalibrationSamples;

  const CategoryForecastAccuracy({
    required this.category,
    required this.samples,
    required this.hitRate,
    required this.meanAbsolutePercentageError,
    required this.ebayDiscount,
    required this.ebayCalibrationSamples,
  });
}

List<ForecastObservation> validForecastObservations(
  Iterable<ForecastObservation> observations,
) =>
    observations
        .where((item) =>
            item.category.trim().isNotEmpty &&
            item.estimatedLikely.isFinite &&
            item.estimatedLikely > 0 &&
            item.estimatedLikely <= 100000 &&
            item.actualSalePrice.isFinite &&
            item.actualSalePrice > 0 &&
            item.actualSalePrice <= 100000)
        .toList();

double calibratedEbayDiscount({
  required String category,
  required Iterable<ForecastObservation> observations,
  double fallback = .10,
}) {
  if (!fallback.isFinite || fallback < 0 || fallback >= 1) {
    throw ArgumentError.value(fallback, 'fallback', 'must be from 0 to below 1');
  }
  final wanted = category.trim().toLowerCase();
  final learned = validForecastObservations(observations)
      .where((item) =>
          item.category.trim().toLowerCase() == wanted &&
          item.ebayAskingReference.isFinite &&
          item.ebayAskingReference > 0 &&
          item.actualSalePrice <= item.ebayAskingReference * 1.25)
      .map((item) =>
          (1 - item.actualSalePrice / item.ebayAskingReference)
              .clamp(.05, .40)
              .toDouble())
      .toList()
    ..sort();
  if (learned.isEmpty) return fallback;
  final middle = learned.length ~/ 2;
  final median = learned.length.isOdd
      ? learned[middle]
      : (learned[middle - 1] + learned[middle]) / 2;
  // One sale starts learning immediately, while five observations fully
  // replace the default. This avoids violent jumps from a single outlier.
  final weight = math.min(1.0, learned.length / 5.0);
  return (fallback * (1 - weight) + median * weight)
      .clamp(.05, .40)
      .toDouble();
}

List<CategoryForecastAccuracy> forecastAccuracyByCategory(
  Iterable<ForecastObservation> observations, {
  double fallbackEbayDiscount = .10,
}) {
  final valid = validForecastObservations(observations);
  final categories = valid.map((item) => item.category.trim()).toSet();
  final result = categories.map((category) {
    final rows = valid
        .where((item) =>
            item.category.trim().toLowerCase() == category.toLowerCase())
        .toList();
    final ebayRows = rows
        .where((item) =>
            item.ebayAskingReference.isFinite &&
            item.ebayAskingReference > 0)
        .length;
    return CategoryForecastAccuracy(
      category: category,
      samples: rows.length,
      hitRate: rows.where((item) => item.hit).length / rows.length,
      meanAbsolutePercentageError:
          rows.map((item) => item.percentageError.abs()).reduce((a, b) => a + b) /
              rows.length,
      ebayDiscount: calibratedEbayDiscount(
        category: category,
        observations: rows,
        fallback: fallbackEbayDiscount,
      ),
      ebayCalibrationSamples: ebayRows,
    );
  }).toList()
    ..sort((a, b) {
      final sampleOrder = b.samples.compareTo(a.samples);
      return sampleOrder != 0 ? sampleOrder : a.category.compareTo(b.category);
    });
  return result;
}
