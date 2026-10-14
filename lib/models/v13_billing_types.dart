part of '../v13_app.dart';

class V13PersonalStats {
  final int sample;
  final double? avgDays;
  final double? avgRoi;
  final double? saleFactor;

  const V13PersonalStats({required this.sample, this.avgDays, this.avgRoi, this.saleFactor});

  factory V13PersonalStats.forCategory(List<V13Flip> flips, String category) {
    final sold = flips.where((f) => f.status == 'Sold' && f.actualSell > 0 && f.category == category).toList();
    if (sold.isEmpty) return const V13PersonalStats(sample: 0);
    final days = sold.map((e) => e.daysToSell).whereType<int>().toList();
    final rois = sold.where((e) => e.buy > 0).map((e) => e.realizedRoi).toList();
    final factors = sold
        .where((e) => e.expectedAtBuy > 0)
        .map((e) => e.actualSell / e.expectedAtBuy)
        .where((e) => e.isFinite && e > 0)
        .toList()
      ..sort();
    final factor = factors.isEmpty
        ? null
        : factors.length.isOdd
            ? factors[factors.length ~/ 2]
            : (factors[factors.length ~/ 2 - 1] + factors[factors.length ~/ 2]) / 2;
    return V13PersonalStats(
      sample: sold.length,
      avgDays: days.isEmpty ? null : days.reduce((a, b) => a + b) / days.length,
      avgRoi: rois.isEmpty ? null : rois.reduce((a, b) => a + b) / rois.length,
      saleFactor: factor?.clamp(.82, 1.15).toDouble(),
    );
  }

  String speedLabel(bool english) {
    if (avgDays == null || sample < 2) return english ? 'Unknown' : 'Offen';
    if (avgDays! <= 14) return english ? 'Fast' : 'Schnell';
    if (avgDays! <= 45) return english ? 'Medium' : 'Mittel';
    return english ? 'Slow' : 'Langsam';
  }
}

enum V13TaxMode { privateSeller, smallBusiness, business, marginScheme }

String v13TaxLabel(V13TaxMode mode, bool english) {
  switch (mode) {
    case V13TaxMode.privateSeller:
      return english ? 'Private' : 'Privat';
    case V13TaxMode.smallBusiness:
      return english ? 'Small business' : 'Kleinunternehmer';
    case V13TaxMode.business:
      return english ? 'Business' : 'Gewerblich';
    case V13TaxMode.marginScheme:
      return english ? 'Margin scheme' : 'Differenzbesteuerung';
  }
}

class V13StoreProduct {
  final String id;
  final String price;
  const V13StoreProduct({required this.id, required this.price});
}

enum V13BillingStage {
  idle,
  loadingStore,
  ready,
  unavailable,
  purchasing,
  restoring,
  restoreRequested,
  verifying,
  verified,
  expired,
  verificationFailed,
  verificationUnavailable,
  canceled,
  error,
}
