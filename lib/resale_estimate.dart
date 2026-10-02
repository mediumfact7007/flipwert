enum ResaleEstimateConfidence { low, medium, high }

enum ResaleOwnSalesScope { none, category, exactModel }

class ResaleSaleSample {
  final String article;
  final String category;
  final double salePrice;
  final DateTime purchaseDate;
  final DateTime saleDate;

  const ResaleSaleSample({
    required this.article,
    required this.category,
    required this.salePrice,
    required this.purchaseDate,
    required this.saleDate,
  });

  int get daysToSell {
    final days = saleDate.difference(purchaseDate).inDays;
    return days < 0 ? 0 : days;
  }
}

class ResaleEstimateInput {
  final String article;
  final String category;
  final List<ResaleSaleSample> ownSales;
  final List<double> activeEbayAskingPrices;
  final double? buybackFloor;
  final double ebayAskingDiscount;
  final DateTime? asOf;
  final Duration ownSaleMaxAge;

  const ResaleEstimateInput({
    required this.article,
    required this.category,
    this.ownSales = const [],
    this.activeEbayAskingPrices = const [],
    this.buybackFloor,
    this.ebayAskingDiscount = .10,
    this.asOf,
    this.ownSaleMaxAge = const Duration(days: 730),
  });
}

class ResaleEstimate {
  final double low;
  final double likely;
  final double high;
  final ResaleEstimateConfidence confidence;
  final int? estimatedDaysToSell;
  final int ownSalesUsed;
  final int activeEbayListingsUsed;
  final ResaleOwnSalesScope ownSalesScope;
  final double appliedEbayDiscount;

  const ResaleEstimate({
    required this.low,
    required this.likely,
    required this.high,
    required this.confidence,
    required this.estimatedDaysToSell,
    required this.ownSalesUsed,
    required this.activeEbayListingsUsed,
    required this.ownSalesScope,
    required this.appliedEbayDiscount,
  });
}

const _modelBrandTokens = {
  'apple', 'samsung', 'google', 'sony', 'microsoft', 'nintendo', 'xiaomi',
  'huawei', 'honor', 'oneplus', 'motorola', 'lenovo', 'asus', 'acer', 'hp',
  'dell', 'lg', 'oppo', 'vivo', 'nokia',
};

const _modelNoiseTokens = {
  'neu', 'neuwertig', 'gebraucht', 'zustand', 'gut', 'sehr', 'akzeptabel',
  'ovp', 'originalverpackung', 'unlocked', 'simlock', 'ohne', 'mit',
  'schwarz', 'black', 'weiss', 'white', 'blau', 'blue', 'gruen', 'green',
  'rot', 'red', 'gold', 'silber', 'silver', 'grau', 'gray', 'grey',
  'titan', 'titanium',
};

List<String> _modelTokens(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
  if (normalized.isEmpty) return const [];

  final raw = normalized.split(RegExp(r'\s+'));
  final result = <String>[];
  for (var i = 0; i < raw.length; i++) {
    var token = raw[i];
    if (RegExp(r'^\d+$').hasMatch(token) &&
        i + 1 < raw.length &&
        const {'mb', 'gb', 'tb'}.contains(raw[i + 1])) {
      token += raw[++i];
    }
    if (_modelBrandTokens.contains(token) || _modelNoiseTokens.contains(token)) {
      continue;
    }
    result.add(token);
  }
  result.sort();
  return result;
}

bool resaleSameModel(String left, String right) {
  final leftTokens = _modelTokens(left);
  final rightTokens = _modelTokens(right);
  if (leftTokens.length < 2 || leftTokens.length != rightTokens.length) {
    return false;
  }
  for (var i = 0; i < leftTokens.length; i++) {
    if (leftTokens[i] != rightTokens[i]) return false;
  }
  return true;
}

List<double> _prices(Iterable<double> values) => values
    .where((value) => value.isFinite && value > 0 && value <= 100000)
    .toList()
  ..sort();

double _quantile(List<double> sorted, double quantile) {
  if (sorted.length == 1) return sorted.single;
  final position = (sorted.length - 1) * quantile;
  final lower = position.floor();
  final upper = position.ceil();
  if (lower == upper) return sorted[lower];
  final fraction = position - lower;
  return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction;
}

double _weighted(double own, double market) => own * .70 + market * .30;

ResaleEstimate? estimateResaleValue(ResaleEstimateInput input) {
  final discount = input.ebayAskingDiscount;
  if (!discount.isFinite || discount < 0 || discount >= 1) {
    throw ArgumentError.value(
      discount,
      'ebayAskingDiscount',
      'must be at least 0 and below 1',
    );
  }
  if (input.ownSaleMaxAge.isNegative) {
    throw ArgumentError.value(
      input.ownSaleMaxAge,
      'ownSaleMaxAge',
      'must not be negative',
    );
  }

  final category = input.category.trim().toLowerCase();
  final validSales = input.ownSales
      .where((sale) =>
          sale.salePrice.isFinite &&
          sale.salePrice > 0 &&
          sale.salePrice <= 100000 &&
          !sale.saleDate.isBefore(sale.purchaseDate) &&
          (input.asOf == null ||
              (!sale.saleDate.isAfter(input.asOf!) &&
                  input.asOf!
                          .difference(sale.saleDate)
                          .compareTo(input.ownSaleMaxAge) <=
                      0)))
      .toList();
  final exactSales = validSales
      .where((sale) =>
          sale.category.trim().toLowerCase() == category &&
          resaleSameModel(sale.article, input.article))
      .toList();
  final categorySales = validSales
      .where((sale) => sale.category.trim().toLowerCase() == category)
      .toList();
  final selectedSales = exactSales.isNotEmpty ? exactSales : categorySales;
  final scope = exactSales.isNotEmpty
      ? ResaleOwnSalesScope.exactModel
      : categorySales.isNotEmpty
          ? ResaleOwnSalesScope.category
          : ResaleOwnSalesScope.none;
  final ownPrices = _prices(selectedSales.map((sale) => sale.salePrice));
  final ebayPrices = _prices(input.activeEbayAskingPrices)
      .map((price) => price * (1 - discount))
      .toList();
  final floor = input.buybackFloor != null &&
          input.buybackFloor!.isFinite &&
          input.buybackFloor! > 0
      ? input.buybackFloor!
      : null;

  if (ownPrices.isEmpty && ebayPrices.isEmpty && floor == null) return null;

  double low;
  double likely;
  double high;
  if (ownPrices.isNotEmpty && ebayPrices.isNotEmpty) {
    low = _weighted(_quantile(ownPrices, .25), _quantile(ebayPrices, .25));
    likely = _weighted(_quantile(ownPrices, .50), _quantile(ebayPrices, .50));
    high = _weighted(_quantile(ownPrices, .75), _quantile(ebayPrices, .75));
  } else if (ownPrices.isNotEmpty) {
    low = _quantile(ownPrices, .25);
    likely = _quantile(ownPrices, .50);
    high = _quantile(ownPrices, .75);
  } else if (ebayPrices.isNotEmpty) {
    low = _quantile(ebayPrices, .25);
    likely = _quantile(ebayPrices, .50);
    high = _quantile(ebayPrices, .75);
  } else {
    low = likely = high = floor!;
  }

  if (floor != null) {
    low = low < floor ? floor : low;
    likely = likely < low ? low : likely;
    high = high < likely ? likely : high;
  }

  final confidence = scope == ResaleOwnSalesScope.exactModel &&
          ownPrices.length >= 3 &&
          ebayPrices.length >= 3
      ? ResaleEstimateConfidence.high
      : ownPrices.length >= 2 || ebayPrices.length >= 5
          ? ResaleEstimateConfidence.medium
          : ResaleEstimateConfidence.low;
  final saleDays = selectedSales.map((sale) => sale.daysToSell).toList()
    ..sort();
  final estimatedDays = saleDays.isEmpty
      ? null
      : _quantile(saleDays.map((days) => days.toDouble()).toList(), .50)
          .round();

  return ResaleEstimate(
    low: low,
    likely: likely,
    high: high,
    confidence: confidence,
    estimatedDaysToSell: estimatedDays,
    ownSalesUsed: ownPrices.length,
    activeEbayListingsUsed: ebayPrices.length,
    ownSalesScope: scope,
    appliedEbayDiscount: discount,
  );
}
