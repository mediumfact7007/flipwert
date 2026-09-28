import 'package:flutter/material.dart';

import 'forecast_control.dart';

class ForecastAccuracyCard extends StatelessWidget {
  final List<CategoryForecastAccuracy> categories;
  final ForecastObservation? latest;
  final bool english;

  const ForecastAccuracyCard({
    super.key,
    required this.categories,
    required this.latest,
    this.english = false,
  });

  String t(String de, String en) => english ? en : de;

  String _money(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    final grouped = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '$grouped,${parts.last} €';
  }

  String _percent(double value) => '${(value * 100).toStringAsFixed(1).replaceAll('.', ',')} %';

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Container(
      key: const ValueKey('forecast-accuracy-card'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E6EE)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.track_changes_rounded, color: Color(0xFF4E50D8)),
          const SizedBox(width: 8),
          Text(t('PROGNOSE-KONTROLLE', 'FORECAST CONTROL'),
              style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
        if (latest != null) ...[
          const SizedBox(height: 8),
          Text(
            '${t('Letzte Prognose', 'Latest forecast')}: '
            '${_money(latest!.estimatedLikely)} → ${_money(latest!.actualSalePrice)}',
            key: const ValueKey('latest-forecast-comparison'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 10),
        for (final item in categories) ...[
          Row(children: [
            Expanded(child: Text(item.category,
                style: const TextStyle(fontWeight: FontWeight.w800))),
            Text('${item.samples} ${t('Verkäufe', 'sales')}',
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF777B88))),
          ]),
          const SizedBox(height: 3),
          Wrap(spacing: 10, runSpacing: 4, children: [
            Text('${t('Treffer', 'Hits')}: ${_percent(item.hitRate)}',
                style: const TextStyle(fontSize: 11)),
            Text('${t('Ø Fehler', 'Avg error')}: ${_percent(item.meanAbsolutePercentageError)}',
                style: const TextStyle(fontSize: 11)),
            Text('${t('eBay-Abschlag', 'eBay discount')}: ${_percent(item.ebayDiscount)}',
                style: const TextStyle(fontSize: 11)),
          ]),
          if (item != categories.last) const Divider(height: 16),
        ],
        const SizedBox(height: 7),
        Text(
          t(
            'Treffer = Verkauf innerhalb der prognostizierten Spanne. Der eBay-Abschlag lernt vorsichtig aus echten Verkäufen.',
            'A hit is a sale inside the forecast range. The eBay discount learns cautiously from actual sales.',
          ),
          style: const TextStyle(fontSize: 9.8, color: Color(0xFF777B88)),
        ),
      ]),
    );
  }
}
