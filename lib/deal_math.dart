double flipProfit({
  required double proceeds,
  required double purchasePrice,
  required double additionalCosts,
}) =>
    proceeds - purchasePrice - additionalCosts;

double flipRoi({
  required double profit,
  required double purchasePrice,
  required double additionalCosts,
}) {
  final totalInvestment = purchasePrice + additionalCosts;
  return totalInvestment > 0 ? profit / totalInvestment * 100 : 0;
}

double flipMaxPurchasePrice({
  required double proceeds,
  required double additionalCosts,
  required double targetRoi,
  required double minimumProfit,
}) {
  final roiFactor = 1 + targetRoi / 100;
  final byRoi = proceeds / roiFactor - additionalCosts;
  final byProfit = proceeds - additionalCosts - minimumProfit;
  final result = byRoi < byProfit ? byRoi : byProfit;
  return result > 0 ? result : 0;
}
