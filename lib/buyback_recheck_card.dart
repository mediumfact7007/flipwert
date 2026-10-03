import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'buyback.dart';

enum BuybackRecheckAvailability {
  offer,
  noMatch,
  sourceUnavailable,
  sourceNotReady,
}

class BuybackRecheckCard extends StatelessWidget {
  const BuybackRecheckCard({
    super.key,
    required this.previousProvider,
    required this.previousPrice,
    required this.previousProfit,
    required this.currentOffer,
    required this.currentPurchasePrice,
    this.availability = BuybackRecheckAvailability.offer,
    this.english = false,
    this.launcher,
  });

  final String previousProvider;
  final double previousPrice;
  final double previousProfit;
  final BuybackOffer? currentOffer;
  final double currentPurchasePrice;
  final BuybackRecheckAvailability availability;
  final bool english;
  final Future<bool> Function(Uri uri)? launcher;

  String t(String de, String en) => english ? en : de;

  String _money(double amount) {
    final value = amount.toStringAsFixed(2).replaceAll('.', english ? '.' : ',');
    return '$value €';
  }

  Future<void> _openCurrentOffer(BuildContext context) async {
    final offer = currentOffer;
    if (offer == null) return;
    final opened = await (launcher?.call(offer.offerUrl) ??
        launchUrl(
          offer.offerUrl,
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
        previousPrice <= 0) {
      return const SizedBox.shrink();
    }
    final offer = currentOffer;
    if (availability != BuybackRecheckAvailability.offer) {
      return _UnavailableBuybackRecheck(
        previousProvider: previousProvider,
        previousPrice: previousPrice,
        availability: availability,
        english: english,
      );
    }
    if (offer == null ||
        !currentPurchasePrice.isFinite ||
        currentPurchasePrice < 0 ||
        !offer.isEligibleForComparison) {
      return const SizedBox.shrink();
    }
    final currentProfit = offer.price - currentPurchasePrice;
    final priceDelta = offer.price - previousPrice;
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
          '${t('Jetzt', 'Now')}: ${offer.providerName} · ${_money(offer.price)}',
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
              offer.affiliateLink
                  ? t('Aktuellen Werbelink öffnen', 'Open current ad link')
                  : t('Aktuelles Angebot öffnen', 'Open current offer'),
            ),
          ),
        ),
      ]),
    );
  }
}

class _UnavailableBuybackRecheck extends StatelessWidget {
  const _UnavailableBuybackRecheck({
    required this.previousProvider,
    required this.previousPrice,
    required this.availability,
    required this.english,
  });

  final String previousProvider;
  final double previousPrice;
  final BuybackRecheckAvailability availability;
  final bool english;

  String t(String de, String en) => english ? en : de;

  String _money(double amount) {
    final value = amount.toStringAsFixed(2).replaceAll('.', english ? '.' : ',');
    return '$value €';
  }

  @override
  Widget build(BuildContext context) {
    final noMatch = availability == BuybackRecheckAvailability.noMatch;
    final unavailable =
        availability == BuybackRecheckAvailability.sourceUnavailable;
    final color = noMatch
        ? const Color(0xFFC33A46)
        : unavailable
            ? const Color(0xFF9A6700)
            : const Color(0xFF6D7180);
    final status = noMatch
        ? t('Aktuell kein Angebot', 'No current offer')
        : unavailable
            ? t('Prüfung nicht möglich', 'Recheck unavailable')
            : t('LIVE-Quelle nicht bereit', 'LIVE source not ready');
    final detail = noMatch
        ? t(
            'Für dieses Gerät und den gespeicherten Zustand liegt derzeit kein qualitätsgeprüftes LIVE-Ankaufangebot vor.',
            'There is currently no quality-checked LIVE buyback offer for this device and saved condition.',
          )
        : unavailable
            ? t(
                'Die LIVE-Quelle ist vorübergehend nicht erreichbar. Das frühere Angebot bleibt nur als historischer Wert erhalten.',
                'The LIVE source is temporarily unavailable. The previous offer is retained only as a historical value.',
              )
            : t(
                'Die LIVE-Quelle oder ihre aktuelle Freigabe ist nicht bereit. Flipwert berechnet keinen Ersatzpreis.',
                'The LIVE source or its current approval is not ready. Flipwert does not calculate a substitute price.',
              );

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
          Expanded(
            child: Text(
              t('Ankaufangebot seit letztem Check',
                  'Buyback offer since last check'),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11.5,
              ),
            ),
          ),
          Text(
            status,
            key: const ValueKey('buyback-recheck-status'),
            style: TextStyle(fontWeight: FontWeight.w900, color: color),
          ),
        ]),
        const SizedBox(height: 5),
        Text(
          '${t('Vorher', 'Before')}: '
          '${previousProvider.trim().isEmpty ? t('Anbieter', 'Provider') : previousProvider} · '
          '${_money(previousPrice)}',
          style: const TextStyle(
            fontSize: 10.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF6D7180),
            height: 1.35,
          ),
        ),
      ]),
    );
  }
}
