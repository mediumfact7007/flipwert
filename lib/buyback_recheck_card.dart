import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'buyback.dart';

class BuybackRecheckCard extends StatelessWidget {
  const BuybackRecheckCard({
    super.key,
    required this.previousProvider,
    required this.previousPrice,
    required this.previousProfit,
    required this.currentOffer,
    required this.currentPurchasePrice,
    this.english = false,
    this.launcher,
  });

  final String previousProvider;
  final double previousPrice;
  final double previousProfit;
  final BuybackOffer currentOffer;
  final double currentPurchasePrice;
  final bool english;
  final Future<bool> Function(Uri uri)? launcher;

  String t(String de, String en) => english ? en : de;

  String _money(double amount) {
    final value = amount.toStringAsFixed(2).replaceAll('.', english ? '.' : ',');
    return '$value €';
  }

  Future<void> _openCurrentOffer(BuildContext context) async {
    final opened = await (launcher?.call(currentOffer.offerUrl) ??
        launchUrl(
          currentOffer.offerUrl,
          mode: LaunchMode.externalApplication,
        ));
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        t(
          'Der Anbieterlink konnte nicht geöffnet werden.',
          'The provider link could not be opened.',
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!previousPrice.isFinite ||
        previousPrice <= 0 ||
        !currentPurchasePrice.isFinite ||
        currentPurchasePrice < 0 ||
        !currentOffer.isEligibleForComparison) {
      return const SizedBox.shrink();
    }
    final currentProfit = currentOffer.price - currentPurchasePrice;
    final priceDelta = currentOffer.price - previousPrice;
    final profitDelta = currentProfit - previousProfit;
    final improved = profitDelta > 0;
    final unchanged = profitDelta.abs() < .005;
    final color = unchanged
        ? const Color(0xFF6D7180)
        : improved
            ? const Color(0xFF087F5B)
            : const Color(0xFFC33A46);
    final direction = unchanged
        ? t('unverändert', 'unchanged')
        : '${profitDelta > 0 ? '+' : ''}${_money(profitDelta)}';

    return Container(
      key: const ValueKey('buyback-recheck-card'),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.refresh_rounded, size: 18, color: color),
          const SizedBox(width: 7),
          Expanded(child: Text(t('Ankaufpreis seit letztem Check', 'Buyback price since last check'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11.5))),
          Text(direction, key: const ValueKey('buyback-recheck-delta'), style: TextStyle(fontWeight: FontWeight.w900, color: color)),
        ]),
        const SizedBox(height: 5),
        Text(
          '${t('Vorher', 'Before')}: ${previousProvider.trim().isEmpty ? 'Anbieter' : previousProvider} · ${_money(previousPrice)}\n'
          '${t('Jetzt', 'Now')}: ${currentOffer.providerName} · ${_money(currentOffer.price)}',
          style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w700, height: 1.35),
        ),
        const SizedBox(height: 3),
        Text(
          '${t('Ankaufpreis-Differenz', 'Buyback price difference')}: ${priceDelta > 0 ? '+' : ''}${_money(priceDelta)} · '
          '${t('Gewinn jetzt', 'Profit now')}: ${_money(currentProfit)}',
          style: const TextStyle(fontSize: 10, color: Color(0xFF6D7180)),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey('buyback-recheck-open-current'),
            onPressed: () => _openCurrentOffer(context),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(
              currentOffer.affiliateLink
                  ? t('Aktuellen Werbelink öffnen', 'Open current ad link')
                  : t('Aktuelles Angebot öffnen', 'Open current offer'),
            ),
          ),
        ),
      ]),
    );
  }
}
