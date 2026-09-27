import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'buyback.dart';

/// Current provider quotes stay visible even when no private-market valuation
/// exists. The caller supplies already validated, condition-matched offers.
class BuybackOffersCard extends StatelessWidget {
  const BuybackOffersCard({super.key, required this.offers, required this.purchasePrice, this.english = false});

  final List<BuybackOffer> offers;
  final double purchasePrice;
  final bool english;

  String _money(double amount) => '${amount.toStringAsFixed(2).replaceAll('.', english ? '.' : ',')} €';

  String _checkedAt(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return english ? '$month/$day $hour:$minute' : '$day.$month. $hour:$minute Uhr';
  }

  String _conditionLabel(BuybackCondition condition) => switch (condition) {
        BuybackCondition.newSealed => english ? 'New / sealed' : 'Neu / versiegelt',
        BuybackCondition.likeNew => english ? 'Like new' : 'Wie neu',
        BuybackCondition.veryGood => english ? 'Very good' : 'Sehr gut',
        BuybackCondition.usedGood => english ? 'Good' : 'Gut',
        BuybackCondition.acceptable => english ? 'Acceptable' : 'Akzeptabel',
        BuybackCondition.defective => english ? 'Defective' : 'Defekt',
      };

  @override
  Widget build(BuildContext context) {
    final ranked = offers.where((offer) => offer.isEligibleForComparison).toList()
      ..sort((a, b) => b.price.compareTo(a.price));
    if (ranked.isEmpty) return const SizedBox.shrink();
    final best = ranked.first;
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('buyback-offers-card'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(english ? 'Current buyback offers' : 'Aktuelle Ankaufangebote', style: theme.textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(
            english
                ? '${ranked.length} quality-checked provider ${ranked.length == 1 ? 'offer' : 'offers'}'
                : '${ranked.length} qualitätsgeprüfte Anbieterangebote',
            key: const ValueKey('buyback-provider-count'),
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(english ? 'Indicative prices for the selected condition; inspection may change the payout.' : 'Vorläufige Preise für den gewählten Zustand; die Prüfung kann den Auszahlungsbetrag ändern.', style: theme.textTheme.bodySmall),
          for (final offer in ranked) ...[
            const Divider(height: 20),
            Row(
              key: ValueKey('buyback-offer-${offer.providerId}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(offer.providerName, style: theme.textTheme.titleSmall)),
                    if (identical(offer, best)) ...[
                      const SizedBox(width: 7),
                      Container(
                        key: const ValueKey('buyback-best-margin'),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          english ? 'Best margin' : 'Beste Marge',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ]),
                  Text(offer.matchedTitle, style: theme.textTheme.bodySmall),
                  Text(
                    english
                        ? 'Condition: ${_conditionLabel(offer.condition)}${offer.requiresInspection ? ' · inspection pending' : ''}'
                        : 'Zustand: ${_conditionLabel(offer.condition)}${offer.requiresInspection ? ' · Prüfung ausstehend' : ''}',
                    key: ValueKey('buyback-condition-${offer.providerId}'),
                    style: theme.textTheme.bodySmall,
                  ),
                  Text(
                    english ? 'Checked: ${_checkedAt(offer.checkedAt)} · Match ${(offer.matchConfidence * 100).round()}%' : 'Geprüft: ${_checkedAt(offer.checkedAt)} · Treffer ${(offer.matchConfidence * 100).round()} %',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (purchasePrice > 0)
                    Builder(builder: (context) {
                      final margin = offer.price - purchasePrice;
                      final profitable = margin >= 0;
                      return Text(
                        profitable
                            ? (english ? 'Profit after purchase: ${_money(margin)}' : 'Gewinn nach Einkauf: ${_money(margin)}')
                            : (english ? 'Loss after purchase: ${_money(-margin)}' : 'Verlust nach Einkauf: ${_money(-margin)}'),
                        key: ValueKey('buyback-margin-${offer.providerId}'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: profitable ? const Color(0xFF087F5B) : theme.colorScheme.error,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    '${_money(offer.price)}${offer.requiresInspection ? '*' : ''}',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => launchUrl(offer.offerUrl, mode: LaunchMode.externalApplication),
                    child: Text(
                      offer.affiliateLink
                          ? (english ? 'Open ad link' : 'Werbelink öffnen')
                          : (english ? 'Open' : 'Öffnen'),
                    ),
                  ),
                ]),
              ],
            ),
          ],
          if (ranked.any((offer) => offer.affiliateLink)) ...[
            const SizedBox(height: 6),
            Text(
              english
                  ? 'Ad links are marked. Flipwert may receive a commission; the displayed provider price does not change.'
                  : 'Werbelinks sind gekennzeichnet. Flipwert kann eine Provision erhalten; der angezeigte Anbieterpreis ändert sich dadurch nicht.',
              key: const ValueKey('buyback-affiliate-note'),
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (ranked.any((offer) => offer.requiresInspection)) ...[
            const SizedBox(height: 6),
            Text(
              english
                  ? '* Indicative quote; the provider may change it after inspecting the item.'
                  : '* Vorläufiges Angebot; der Anbieter kann es nach der Artikelprüfung ändern.',
              key: const ValueKey('buyback-inspection-note'),
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ]),
      ),
    );
  }
}
