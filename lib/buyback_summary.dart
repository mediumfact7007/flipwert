import 'buyback.dart';

double buybackAppliedSafetyReserve(
  BuybackOffer offer,
  double safetyReserve,
) =>
    offer.requiresInspection &&
            safetyReserve.isFinite &&
            safetyReserve > 0
        ? safetyReserve
        : 0;

double buybackEffectiveProceeds(
  BuybackOffer offer,
  double safetyReserve,
) {
  final reserve = buybackAppliedSafetyReserve(offer, safetyReserve);
  return offer.price > reserve ? offer.price - reserve : 0;
}

BuybackOffer? bestComparableBuybackOfferAfterReserve(
  Iterable<BuybackOffer> offers, {
  required BuybackCondition condition,
  required double safetyReserve,
  DateTime? now,
  Duration maxAge = const Duration(hours: 24),
}) {
  BuybackOffer? best;
  for (final offer in offers) {
    if (offer.condition != condition || !offer.isEligibleForComparison) continue;
    if (now != null && !offer.isFreshAt(now, maxAge: maxAge)) continue;
    if (best == null ||
        buybackEffectiveProceeds(offer, safetyReserve) >
            buybackEffectiveProceeds(best, safetyReserve)) {
      best = offer;
    }
  }
  return best;
}

/// User-facing comparison data for a fast exit via a buyback provider.
///
/// This stays independent from widgets and provider adapters so the same
/// trusted calculation can later power the deal result, watchlist rechecks,
/// and Pro alerts without duplicating margin logic.
class BuybackComparisonSummary {
  const BuybackComparisonSummary({
    required this.offer,
    required this.purchasePrice,
    required this.privateMarketValue,
    this.safetyReserve = 0,
  });

  final BuybackOffer offer;
  final double purchasePrice;
  final double privateMarketValue;
  final double safetyReserve;

  double get appliedSafetyReserve =>
      buybackAppliedSafetyReserve(offer, safetyReserve);

  double get effectiveInstantProceeds =>
      buybackEffectiveProceeds(offer, safetyReserve);

  double get instantMargin => effectiveInstantProceeds - purchasePrice;

  double get privateMargin => privateMarketValue - purchasePrice;

  double get instantRoi =>
      purchasePrice > 0 ? (instantMargin / purchasePrice) * 100 : 0;

  double get privateRoi =>
      purchasePrice > 0 ? (privateMargin / purchasePrice) * 100 : 0;

  /// How much gross upside the user gives up for the faster, simpler exit.
  double get convenienceGap => privateMarketValue - effectiveInstantProceeds;

  bool get instantExitProfitable => instantMargin > 0;
}

BuybackComparisonSummary? buildBuybackComparisonSummary(
  Iterable<BuybackOffer> offers, {
  required BuybackCondition condition,
  required double purchasePrice,
  required double privateMarketValue,
  double safetyReserve = 0,
  DateTime? now,
  Duration maxAge = const Duration(hours: 24),
}) {
  if (!purchasePrice.isFinite || purchasePrice < 0) return null;
  // A zero/negative private value means Flipwert has no usable market anchor.
  // Never turn that absence into a misleading "instant buyback wins" verdict.
  if (!privateMarketValue.isFinite || privateMarketValue <= 0) return null;

  // User-facing comparisons must never silently accept stale provider data.
  // Callers can still inject [now] for deterministic tests/rechecks.
  final comparisonTime = now ?? DateTime.now();
  final best = bestComparableBuybackOfferAfterReserve(
    offers,
    condition: condition,
    safetyReserve: safetyReserve,
    now: comparisonTime,
    maxAge: maxAge,
  );
  if (best == null) return null;

  return BuybackComparisonSummary(
    offer: best,
    purchasePrice: purchasePrice,
    privateMarketValue: privateMarketValue,
    safetyReserve:
        safetyReserve.isFinite && safetyReserve > 0 ? safetyReserve : 0,
  );
}
