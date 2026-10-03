import 'package:flipwert/resale_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

ResaleSaleSample sale(
  String article,
  String category,
  double price,
  int days,
) =>
    ResaleSaleSample(
      article: article,
      category: category,
      salePrice: price,
      purchaseDate: DateTime(2026, 9, 1),
      saleDate: DateTime(2026, 9, 1 + days),
    );

void main() {
  test('model matching tolerates listing noise but keeps variants strict', () {
    expect(
      resaleSameModel(
        'Apple iPhone 15 Pro 256 GB Weiß',
        'iPhone 15 Pro 256GB, black, ohne Simlock',
      ),
      isTrue,
    );
    expect(
      resaleSameModel('Apple iPhone 15 Pro 256 GB', 'iPhone 15 Pro Max 256GB'),
      isFalse,
    );
    expect(
      resaleSameModel('Apple iPhone 15 Pro 256 GB', 'iPhone 15 Pro 128GB'),
      isFalse,
    );
  });

  test('own exact-model sales carry the highest weight', () {
    final estimate = estimateResaleValue(ResaleEstimateInput(
      article: 'Apple iPhone 15 Pro 256 GB',
      category: 'Smartphone',
      ownSales: [
        sale('Apple iPhone 15 Pro 256 GB', 'Smartphone', 800, 8),
        sale('Apple iPhone 15 Pro 256 GB', 'Smartphone', 820, 10),
        sale('Apple iPhone 15 Pro 256 GB', 'Smartphone', 840, 12),
        sale('Samsung Galaxy S24', 'Smartphone', 500, 20),
      ],
      activeEbayAskingPrices: const [1000, 1020, 1040],
      ebayAskingDiscount: .10,
    ))!;

    expect(estimate.ownSalesScope, ResaleOwnSalesScope.exactModel);
    expect(estimate.ownSalesUsed, 3);
    expect(estimate.likely, closeTo(849.4, .001));
    expect(estimate.low, lessThan(estimate.likely));
    expect(estimate.high, greaterThan(estimate.likely));
    expect(estimate.confidence, ResaleEstimateConfidence.high);
    expect(estimate.estimatedDaysToSell, 10);
  });

  test('exact-model sales must belong to the same category and variant', () {
    final estimate = estimateResaleValue(ResaleEstimateInput(
      article: 'iPhone 15 Pro 256GB schwarz',
      category: 'Smartphone',
      ownSales: [
        sale('Apple iPhone 15 Pro 256 GB Weiß', 'Smartphone', 800, 8),
        sale('Apple iPhone 15 Pro Max 256 GB', 'Smartphone', 1200, 4),
        sale('Apple iPhone 15 Pro 256 GB', 'Sonstiges', 50, 1),
      ],
    ))!;

    expect(estimate.ownSalesScope, ResaleOwnSalesScope.exactModel);
    expect(estimate.ownSalesUsed, 1);
    expect(estimate.likely, 800);
    expect(estimate.estimatedDaysToSell, 8);
  });

  test('adjustable eBay discount changes the market estimate', () {
    const input = ResaleEstimateInput(
      article: 'Pixel 9',
      category: 'Smartphone',
      activeEbayAskingPrices: [600, 650, 700, 750, 800],
    );
    final tenPercent = estimateResaleValue(input)!;
    final twentyPercent = estimateResaleValue(const ResaleEstimateInput(
      article: 'Pixel 9',
      category: 'Smartphone',
      activeEbayAskingPrices: [600, 650, 700, 750, 800],
      ebayAskingDiscount: .20,
    ))!;

    expect(tenPercent.likely, 630);
    expect(twentyPercent.likely, 560);
    expect(twentyPercent.likely, lessThan(tenPercent.likely));
    expect(tenPercent.confidence, ResaleEstimateConfidence.medium);
  });

  test('buyback price is a strict lower bound for the range', () {
    final estimate = estimateResaleValue(const ResaleEstimateInput(
      article: 'Nintendo Switch OLED',
      category: 'Konsole',
      activeEbayAskingPrices: [210, 220, 230],
      buybackFloor: 250,
    ))!;

    expect(estimate.low, 250);
    expect(estimate.likely, 250);
    expect(estimate.high, 250);
    expect(estimate.confidence, ResaleEstimateConfidence.low);
  });

  test('category sales are fallback and invalid data is ignored', () {
    final estimate = estimateResaleValue(ResaleEstimateInput(
      article: 'Unknown ThinkPad variant',
      category: 'Laptop',
      ownSales: [
        sale('ThinkPad T14', 'Laptop', 500, 15),
        sale('ThinkPad X1', 'Laptop', 600, 25),
        ResaleSaleSample(
          article: 'Broken row',
          category: 'Laptop',
          salePrice: -1,
          purchaseDate: DateTime(2026, 9, 2),
          saleDate: DateTime(2026, 9, 1),
        ),
      ],
    ))!;

    expect(estimate.ownSalesScope, ResaleOwnSalesScope.category);
    expect(estimate.ownSalesUsed, 2);
    expect(estimate.likely, 550);
    expect(estimate.estimatedDaysToSell, 20);
    expect(estimate.confidence, ResaleEstimateConfidence.medium);
  });

  test('stale personal sales do not distort the current estimate', () {
    final estimate = estimateResaleValue(ResaleEstimateInput(
      article: 'Google Pixel 9 256 GB',
      category: 'Smartphone',
      asOf: DateTime(2026, 10, 3),
      ownSales: [
        ResaleSaleSample(
          article: 'Google Pixel 9 256 GB',
          category: 'Smartphone',
          salePrice: 900,
          purchaseDate: DateTime(2023, 8, 1),
          saleDate: DateTime(2023, 8, 10),
        ),
        ResaleSaleSample(
          article: 'Samsung Galaxy S24 256 GB',
          category: 'Smartphone',
          salePrice: 500,
          purchaseDate: DateTime(2026, 8, 1),
          saleDate: DateTime(2026, 8, 20),
        ),
      ],
    ))!;

    expect(estimate.ownSalesScope, ResaleOwnSalesScope.category);
    expect(estimate.ownSalesUsed, 1);
    expect(estimate.likely, 500);
    expect(estimate.estimatedDaysToSell, 19);
  });

  test('obvious price outliers do not dominate the resale forecast', () {
    final estimate = estimateResaleValue(ResaleEstimateInput(
      article: 'Apple iPhone 15 Pro 256 GB',
      category: 'Smartphone',
      ownSales: [
        sale('Apple iPhone 15 Pro 256 GB', 'Smartphone', 500, 8),
        sale('Apple iPhone 15 Pro 256 GB', 'Smartphone', 520, 10),
        sale('Apple iPhone 15 Pro 256 GB', 'Smartphone', 540, 12),
        sale('Apple iPhone 15 Pro 256 GB', 'Smartphone', 5000, 1),
      ],
      activeEbayAskingPrices: const [600, 620, 640, 6000],
      ebayAskingDiscount: .10,
    ))!;

    expect(estimate.ownSalesUsed, 3);
    expect(estimate.activeEbayListingsUsed, 3);
    expect(estimate.likely, closeTo(531.4, .001));
    expect(estimate.high, closeTo(541.1, .001));
    expect(estimate.estimatedDaysToSell, 10);
    expect(estimate.confidence, ResaleEstimateConfidence.high);
  });

  test('returns no estimate without usable evidence', () {
    expect(
      estimateResaleValue(const ResaleEstimateInput(
        article: 'Unknown',
        category: 'Sonstiges',
      )),
      isNull,
    );
    expect(
      () => estimateResaleValue(const ResaleEstimateInput(
        article: 'Unknown',
        category: 'Sonstiges',
        ebayAskingDiscount: 1,
      )),
      throwsArgumentError,
    );
  });
}
