import 'package:flipwert/dual_exit.dart';
import 'package:flipwert/resale_estimate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('both exits subtract purchase and every entered additional cost', () {
    const estimate = ResaleEstimate(
      low: 450,
      likely: 500,
      high: 560,
      confidence: ResaleEstimateConfidence.medium,
      estimatedDaysToSell: 18,
      ownSalesUsed: 2,
      activeEbayListingsUsed: 5,
      ownSalesScope: ResaleOwnSalesScope.category,
      appliedEbayDiscount: .10,
    );
    final result = buildDualExitComparison(
      purchasePrice: 300,
      additionalCosts: 45,
      instantProceeds: 410,
      marketEstimate: estimate,
    );

    expect(result.totalInvestment, 345);
    expect(result.instantProfit, 65);
    expect(result.marketProfit!.low, 105);
    expect(result.marketProfit!.likely, 155);
    expect(result.marketProfit!.high, 215);
  });

  test('missing exit remains missing instead of inventing a value', () {
    final result = buildDualExitComparison(
      purchasePrice: 100,
      additionalCosts: 10,
    );
    expect(result.instantProfit, isNull);
    expect(result.marketProfit, isNull);
  });

  test('invalid cost inputs fail closed', () {
    expect(
      () => buildDualExitComparison(
        purchasePrice: -1,
        additionalCosts: 0,
      ),
      throwsArgumentError,
    );
    expect(
      () => buildDualExitComparison(
        purchasePrice: 1,
        additionalCosts: double.nan,
      ),
      throwsArgumentError,
    );
  });
}
