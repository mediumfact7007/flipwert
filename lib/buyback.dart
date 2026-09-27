enum BuybackCondition {
  newSealed,
  likeNew,
  veryGood,
  usedGood,
  acceptable,
  defective,
}

extension BuybackConditionWire on BuybackCondition {
  String get wireValue => switch (this) {
        BuybackCondition.newSealed => 'new_sealed',
        BuybackCondition.likeNew => 'like_new',
        BuybackCondition.veryGood => 'very_good',
        BuybackCondition.usedGood => 'used_good',
        BuybackCondition.acceptable => 'acceptable',
        BuybackCondition.defective => 'defective',
      };

  static BuybackCondition? tryParse(String value) {
    for (final condition in BuybackCondition.values) {
      if (condition.wireValue == value) return condition;
    }
    return null;
  }
}

bool _hasPublicOfferHost(String host) {
  var normalized = host.toLowerCase();
  while (normalized.endsWith('.')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  if (normalized.isEmpty || normalized == 'localhost' || normalized.endsWith('.localhost') || normalized.endsWith('.local') || normalized == '::1') return false;
  if (normalized.contains(':')) {
    if (normalized.startsWith('::ffff:')) return false;
    return normalized != '::' && !normalized.startsWith('fc') && !normalized.startsWith('fd') && !normalized.startsWith('fe8') && !normalized.startsWith('fe9') && !normalized.startsWith('fea') && !normalized.startsWith('feb');
  }
  final octets = normalized.split('.');
  if (octets.length != 4) return true;
  final ipv4 = octets.map(int.tryParse).toList();
  if (ipv4.any((part) => part == null || part < 0 || part > 255)) return true;
  final a = ipv4[0]!; final b = ipv4[1]!; final c = ipv4[2]!;
  return !(a == 0 || a == 10 || a == 127 || (a == 100 && b >= 64 && b <= 127) || (a == 169 && b == 254) || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 0 && c == 0) || (a == 192 && b == 0 && c == 2) || (a == 192 && b == 168) || (a == 198 && (b == 18 || b == 19)) || (a == 198 && b == 51 && c == 100) || (a == 203 && b == 0 && c == 113) || a >= 224);
}

bool _hasSafeOfferUrl(Uri url) => url.hasScheme && url.scheme == 'https' && url.host.isNotEmpty && _hasPublicOfferHost(url.host) && url.userInfo.isEmpty && (!url.hasPort || url.port == 443);

bool _hasExplicitTimeZone(String value) {
  final normalized = value.trim();
  return normalized.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(normalized);
}

class BuybackOffer {
  const BuybackOffer({required this.providerId, required this.providerName, required this.productId, required this.matchedTitle, required this.condition, required this.price, required this.currency, required this.offerUrl, required this.checkedAt, required this.requiresInspection, required this.matchConfidence, this.conditionUncertain = false, this.affiliateLink = false, this.listedPrice, this.mandatoryDeductionsEur = 0});
  static const double maxComparablePriceEur = 10000;
  final String providerId; final String providerName; final String productId; final String matchedTitle; final BuybackCondition condition; final double price; final String currency; final Uri offerUrl; final DateTime checkedAt; final bool requiresInspection; final double matchConfidence; final bool conditionUncertain; final bool affiliateLink; final double? listedPrice; final double mandatoryDeductionsEur;
  double get displayedListedPrice => listedPrice ?? price;
  bool get hasMandatoryDeductions => mandatoryDeductionsEur > 0;
  bool get isEligibleForComparison => !conditionUncertain && providerId.trim().isNotEmpty && providerName.trim().isNotEmpty && productId.trim().isNotEmpty && matchedTitle.trim().isNotEmpty && price.isFinite && price > 0 && price <= maxComparablePriceEur && displayedListedPrice.isFinite && displayedListedPrice >= price && displayedListedPrice <= maxComparablePriceEur && mandatoryDeductionsEur.isFinite && mandatoryDeductionsEur >= 0 && (displayedListedPrice - mandatoryDeductionsEur - price).abs() < 0.011 && currency == 'EUR' && _hasSafeOfferUrl(offerUrl) && matchConfidence.isFinite && matchConfidence >= 0.9 && matchConfidence <= 1;
  bool isFreshAt(DateTime now, {Duration maxAge = const Duration(hours: 24), Duration futureTolerance = const Duration(minutes: 5)}) { final age = now.toUtc().difference(checkedAt.toUtc()); return age >= -futureTolerance && age <= maxAge; }

  factory BuybackOffer.fromJson(Map<String, dynamic> json) {
    final condition = BuybackConditionWire.tryParse(json['condition'] as String? ?? '');
    if (condition == null) throw const FormatException('Unsupported buyback condition');
    if (json['price_kind'] != 'indicative_buyback') throw const FormatException('Unsupported buyback price kind');
    final price = (json['price'] as num?)?.toDouble();
    final listedPrice = (json['listed_price'] as num?)?.toDouble() ?? price;
    final mandatoryDeductions = (json['mandatory_deductions_eur'] as num?)?.toDouble() ?? 0;
    final priceBasis = json['price_basis'];
    final confidence = (json['match_confidence'] as num?)?.toDouble();
    final checkedAtRaw = json['checked_at'] as String? ?? '';
    final checkedAt = DateTime.tryParse(checkedAtRaw);
    final offerUrl = Uri.tryParse(json['offer_url'] as String? ?? '');
    if (price == null || listedPrice == null || confidence == null || checkedAt == null || !_hasExplicitTimeZone(checkedAtRaw) || offerUrl == null || !offerUrl.hasScheme || offerUrl.host.isEmpty) throw const FormatException('Incomplete buyback offer');
    if (priceBasis != null && priceBasis != 'net_after_mandatory_deductions') throw const FormatException('Unsupported buyback price basis');
    if (!listedPrice.isFinite || !mandatoryDeductions.isFinite || mandatoryDeductions < 0 || listedPrice < price || (listedPrice - mandatoryDeductions - price).abs() >= 0.011) throw const FormatException('Invalid buyback deductions');
    if (!_hasSafeOfferUrl(offerUrl)) throw const FormatException('Unsafe buyback offer URL');
    return BuybackOffer(providerId: json['provider_id'] as String? ?? '', providerName: json['provider_name'] as String? ?? '', productId: json['product_id'] as String? ?? '', matchedTitle: json['matched_title'] as String? ?? '', condition: condition, price: price, currency: json['currency'] as String? ?? '', offerUrl: offerUrl, checkedAt: checkedAt, requiresInspection: json['requires_inspection'] as bool? ?? true, matchConfidence: confidence, conditionUncertain: json['condition_uncertain'] as bool? ?? false, affiliateLink: json['affiliate_link'] as bool? ?? false, listedPrice: listedPrice, mandatoryDeductionsEur: mandatoryDeductions);
  }
}

BuybackOffer? bestComparableBuybackOffer(Iterable<BuybackOffer> offers, {required BuybackCondition condition, DateTime? now, Duration maxAge = const Duration(hours: 24)}) {
  BuybackOffer? best;
  for (final offer in offers) {
    if (offer.condition != condition || !offer.isEligibleForComparison) continue;
    if (now != null && !offer.isFreshAt(now, maxAge: maxAge)) continue;
    if (best == null || offer.price > best.price) best = offer;
  }
  return best;
}
