import 'package:flipwert/deal_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ROI uses purchase price plus additional costs', () {
    final profit = flipProfit(
      proceeds: 350,
      purchasePrice: 220,
      additionalCosts: 30,
    );

    expect(profit, 100);
    expect(
      flipRoi(
        profit: profit,
        purchasePrice: 220,
        additionalCosts: 30,
      ),
      40,
    );
  });

  test('ROI target lowers max purchase price by all additional costs', () {
    expect(
      flipMaxPurchasePrice(
        proceeds: 350,
        additionalCosts: 30,
        targetRoi: 25,
        minimumProfit: 20,
      ),
      250,
    );
  });

  test('profit target remains the stricter max purchase limit', () {
    expect(
      flipMaxPurchasePrice(
        proceeds: 350,
        additionalCosts: 30,
        targetRoi: 10,
        minimumProfit: 80,
      ),
      240,
    );
  });

  test('zero investment never produces infinite ROI', () {
    expect(
      flipRoi(profit: 100, purchasePrice: 0, additionalCosts: 0),
      0,
    );
  });
}
