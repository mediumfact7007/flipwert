part of '../v13_app.dart';

class _V13FlipCard extends StatelessWidget {
  final bool english;
  final V13Flip flip;
  final ValueChanged<V13Flip> onUpdate;
  final ValueChanged<String> onDelete;
  final ValueChanged<V13Flip> onRecheck;
  final VoidCallback? onAlertChanged;
  const _V13FlipCard({required this.english, required this.flip, required this.onUpdate, required this.onDelete, required this.onRecheck, this.onAlertChanged});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final sold = flip.status == 'Sold';
    final saved = flip.isSaved;
    final archived = flip.isArchived;
    final age = DateTime.now().difference(flip.checkedAt);
    final stale = saved && age.inHours >= 24;
    final stateLabel = sold
        ? t('verkauft', 'sold')
        : archived
            ? t('archiviert', 'archived')
            : saved
                ? t('gemerkt', 'saved')
                : flip.status == 'Listed'
                    ? t('inseriert', 'listed')
                    : t('gekauft', 'bought');
    final iconColor = sold
        ? const Color(0xFF087F5B)
        : archived
            ? const Color(0xFF7A7E8B)
            : saved
                ? const Color(0xFFC47B00)
                : _v13Primary;
    return Container(
      key: ValueKey('v147-flip-${flip.id}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: stale ? const Color(0x33C47B00) : const Color(0xFFE9EAF0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: iconColor.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: Icon(sold ? Icons.check_rounded : archived ? Icons.archive_outlined : saved ? Icons.bookmark_rounded : Icons.inventory_2_outlined, color: iconColor)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(flip.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)), Text('${flip.category} · $stateLabel', style: const TextStyle(fontSize: 10.5, color: Color(0xFF7A7E8B)))])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(sold ? v13Euro(flip.realizedProfit) : v13Euro(flip.buy), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: sold && flip.realizedProfit >= 0 ? const Color(0xFF087F5B) : _v13Ink)), Text(sold ? '${flip.daysToSell ?? 0} ${t('Tage', 'days')}' : saved || archived ? t('Angebot', 'asking') : t('Einkauf', 'buy'), style: const TextStyle(fontSize: 9.5, color: Color(0xFF8B8E9A)))]),
          if (sold || saved || archived) ...[
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              key: ValueKey('v148-menu-${flip.id}'),
              tooltip: t('Deal verwalten', 'Manage deal'),
              onSelected: (value) => _handleMenu(context, value),
              itemBuilder: (_) => [
                if (sold)
                  PopupMenuItem(
                    value: 'edit_sale',
                    child: Text(t(
                      'Verkaufsdaten bearbeiten',
                      'Edit sale details',
                    )),
                  ),
                if (flip.sourceUrl.isNotEmpty) PopupMenuItem(value: 'listing', child: Text(t('Inserat öffnen', 'Open listing'))),
                if (saved) PopupMenuItem(value: 'archive', child: Text(t('Archivieren', 'Archive'))),
                if (archived) PopupMenuItem(value: 'restore', child: Text(t('Zur Merkliste', 'Restore to saved'))),
                PopupMenuItem(value: 'delete', child: Text(t('Löschen', 'Delete'))),
              ],
            ),
          ],
        ]),
        if (sold) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _V13Pill(
              text: '${t('Verkauf', 'Sale')} ${v13Euro(flip.actualSell)}',
              foreground: _v13Ink,
              background: const Color(0xFFF4F5F8),
            ),
            _V13Pill(
              text:
                  '${t('Investiert', 'Invested')} ${v13Euro(flip.buy + flip.costs)}',
              foreground: _v13Ink,
              background: const Color(0xFFF4F5F8),
            ),
            _V13Pill(
              text: 'ROI ${flip.realizedRoi.toStringAsFixed(0)} %',
              foreground: flip.realizedRoi >= 0
                  ? const Color(0xFF087F5B)
                  : const Color(0xFFC33A46),
              background: const Color(0xFFF4F5F8),
            ),
            if (flip.soldPlatform.isNotEmpty)
              _V13Pill(
                text: flip.soldPlatform,
                foreground: _v13Ink,
                background: const Color(0xFFF4F5F8),
              ),
          ]),
        ],
        if (saved || archived || (!sold && flip.maxBuyAtCheck > 0)) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (flip.maxBuyAtCheck > 0) _V13Pill(text: 'MAX ${v13Euro(flip.maxBuyAtCheck)}', foreground: _v13Primary, background: const Color(0xFFEDEDFC)),
            if (flip.profitAtCheck != 0) _V13Pill(text: '${flip.profitAtCheck >= 0 ? '+' : ''}${v13Euro(flip.profitAtCheck)}', foreground: flip.profitAtCheck >= 0 ? const Color(0xFF087F5B) : const Color(0xFFC33A46), background: const Color(0xFFF4F5F8)),
            if (flip.roiAtCheck != 0) _V13Pill(text: 'ROI ${flip.roiAtCheck.toStringAsFixed(0)} %', foreground: _v13Ink, background: const Color(0xFFF4F5F8)),
            if (flip.confidenceScore > 0) _V13Pill(text: '${flip.confidenceScore}/100', foreground: _v13Ink, background: const Color(0xFFF4F5F8)),
          ]),
          const SizedBox(height: 6),
          Row(key: const ValueKey('v147-snapshot-age'), children: [
            Icon(stale ? Icons.schedule_rounded : Icons.history_rounded, size: 14, color: stale ? const Color(0xFFC47B00) : const Color(0xFF7A7E8B)),
            const SizedBox(width: 5),
            Expanded(child: Text(
              stale
                  ? t('Check ${v147AgeLabel(flip.checkedAt, false)} · Preise können veraltet sein.', 'Checked ${v147AgeLabel(flip.checkedAt, true)} · prices may be stale.')
                  : t('Check ${v147AgeLabel(flip.checkedAt, false)}.', 'Checked ${v147AgeLabel(flip.checkedAt, true)}.'),
              style: TextStyle(fontSize: 10.2, color: stale ? const Color(0xFFC47B00) : const Color(0xFF7A7E8B), fontWeight: stale ? FontWeight.w800 : FontWeight.w500),
            )),
          ]),
        ],
        if (saved) ...[
          const SizedBox(height: 8),
          DealAlertToggle(flipId: flip.id, english: english, onChanged: onAlertChanged),
        ],
        if (!sold && !archived) ...[
          const SizedBox(height: 10),
          if (saved)
            Row(children: [
              Expanded(child: OutlinedButton.icon(key: const ValueKey('v148-recheck-deal'), onPressed: () => onRecheck(flip), icon: const Icon(Icons.refresh_rounded, size: 17), label: Text(t('NEU PRÜFEN', 'RECHECK')))),
              const SizedBox(width: 7),
              Expanded(child: FilledButton.icon(key: const ValueKey('v147-mark-bought'), onPressed: () => onUpdate(flip.copyWith(status: 'Bought', createdAt: DateTime.now())), icon: const Icon(Icons.inventory_2_rounded, size: 17), label: Text(t('GEKAUFT', 'BOUGHT')))),
            ])
          else
            Row(children: [
              if (flip.status == 'Bought') Expanded(child: OutlinedButton(onPressed: () => onUpdate(flip.copyWith(status: 'Listed', listedAt: DateTime.now())), child: Text(t('Inseriert', 'Listed')))),
              if (flip.status == 'Bought') const SizedBox(width: 7),
              Expanded(child: FilledButton(onPressed: () => _soldDialog(context), child: Text(t('Verkauft', 'Sold')))),
            ]),
        ],
      ]),
    );
  }

  Future<void> _handleMenu(BuildContext context, String value) async {
    switch (value) {
      case 'edit_sale':
        await _soldDialog(context);
        return;
      case 'listing':
        await _openListing();
        return;
      case 'archive':
        onUpdate(flip.copyWith(status: 'Archived'));
        return;
      case 'restore':
        onUpdate(flip.copyWith(status: 'Saved'));
        return;
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(t('Deal löschen?', 'Delete deal?')),
            content: Text(flip.status == 'Sold'
                ? t(
                    'Der Verkaufsdatensatz wird dauerhaft von diesem Gerät entfernt.',
                    'The sale record will be permanently removed from this device.',
                  )
                : t(
                    'Der gespeicherte Snapshot wird dauerhaft von diesem Gerät entfernt.',
                    'The saved snapshot will be permanently removed from this device.',
                  )),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(t('Abbrechen', 'Cancel'))),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(t('Löschen', 'Delete'))),
            ],
          ),
        );
        if (ok == true) onDelete(flip.id);
        return;
    }
  }

  Future<void> _openListing() async {
    final uri = Uri.tryParse(flip.sourceUrl);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _soldDialog(BuildContext context) async {
    final editing = flip.status == 'Sold';
    String formatMoney(double value) => value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2).replaceAll('.', ',');
    var price = editing ? formatMoney(flip.actualSell) : '';
    var actualCosts = flip.costs == flip.costs.roundToDouble()
        ? flip.costs.toStringAsFixed(0)
        : flip.costs.toStringAsFixed(2).replaceAll('.', ',');
    final platforms = <String>[
      'eBay',
      'Kleinanzeigen',
      'Vinted',
      'Amazon',
      'rebuy',
      t('Sonstiges', 'Other'),
    ];
    if (editing &&
        flip.soldPlatform.isNotEmpty &&
        !platforms.contains(flip.soldPlatform)) {
      platforms.add(flip.soldPlatform);
    }
    var platform = editing && flip.soldPlatform.isNotEmpty
        ? flip.soldPlatform
        : 'eBay';
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(editing
              ? t('Verkaufsdaten bearbeiten', 'Edit sale details')
              : t('Verkauf abschließen', 'Finish sale')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                key: const ValueKey('v160-actual-sale-price'),
                initialValue: price,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: t('Verkaufspreis', 'Sale price'),
                  suffixText: '€',
                ),
                onChanged: (value) => price = value,
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('v160-actual-total-costs'),
                initialValue: actualCosts,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: t(
                    'Tatsächliche Zusatzkosten gesamt',
                    'Actual total additional costs',
                  ),
                  helperText: t(
                    'Z. B. Gebühren, Versand und Reparaturen',
                    'E.g. fees, shipping and repairs',
                  ),
                  suffixText: '€',
                ),
                onChanged: (value) => actualCosts = value,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: platform,
                decoration: InputDecoration(
                  labelText: t('Verkauft über', 'Sold on'),
                ),
                items: platforms
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setDialog(() => platform = v ?? platform),
              ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t('Abbrechen', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                final value = v13Money(price);
                if (value > 0) {
                  Navigator.pop(dialogContext, {
                    'price': value,
                    'costs': v13Money(actualCosts),
                    'platform': platform,
                  });
                }
              },
              child: Text(t('Speichern', 'Save')),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      onUpdate(flip.copyWith(
        status: 'Sold',
        soldAt: flip.soldAt ?? DateTime.now(),
        actualSell: result['price'] as double,
        costs: result['costs'] as double,
        soldPlatform: result['platform'] as String,
      ));
    }
  }
}

