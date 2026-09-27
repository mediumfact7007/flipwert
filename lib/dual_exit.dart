import 'resale_estimate.dart';

class ExitProfitRange {
  final double low;
  final double likely;
  final double high;

  const ExitProfitRange({
    required this.low,
    required this.likely,
    required this.high,
  });
}

class DualExitComparison {
  final double totalInvestment;
  final double? instantProceeds;
  final double? instantProfit;
  final ResaleEstimate? marketEstimate;
  final ExitProfitRange? marketProfit;

  const DualExitComparison({
    required this.totalInvestment,
    required this.instantProceeds,
    required this.instantProfit,
    required this.marketEstimate,
    required this.marketProfit,
  });
}

DualExitComparison buildDualExitComparison({
  required double purchasePrice,
  required double additionalCosts,
  double? instantProceeds,
  ResaleEstimate? marketEstimate,
}) {
  if (!purchasePrice.isFinite || purchasePrice < 0) {
    throw ArgumentError.value(purchasePrice, 'purchasePrice');
  }
  if (!additionalCosts.isFinite || additionalCosts < 0) {
    throw ArgumentError.value(additionalCosts, 'additionalCosts');
  }
  if (instantProceeds != null &&
      (!instantProceeds.isFinite || instantProceeds <= 0)) {
    throw ArgumentError.value(instantProceeds, 'instantProceeds');
  }

  final investment = purchasePrice + additionalCosts;
  return DualExitComparison(
    totalInvestment: investment,
    instantProceeds: instantProceeds,
    instantProfit:
        instantProceeds == null ? null : instantProceeds - investment,
    marketEstimate: marketEstimate,
    marketProfit: marketEstimate == null
        ? null
        : ExitProfitRange(
            low: marketEstimate.low - investment,
            likely: marketEstimate.likely - investment,
            high: marketEstimate.high - investment,
          ),
  );
}
