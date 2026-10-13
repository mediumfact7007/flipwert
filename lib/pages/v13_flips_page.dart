part of '../v13_app.dart';

class V13FlipsPage extends StatefulWidget {
  final bool english;
  final UserPlan plan;
  final double ebayDiscount;
  final List<V13Flip> flips;
  final V13Monetization monetization;
  final ValueChanged<V13Flip> onUpdate;
  final ValueChanged<List<V13Flip>> onImportSales;
  final ValueChanged<String> onDelete;
  final ValueChanged<V13Flip> onRecheck;
  final VoidCallback onPro;
  final String initialFilter;

  const V13FlipsPage({super.key, required this.english, required this.plan, this.ebayDiscount = .10, required this.flips, required this.monetization, required this.onUpdate, required this.onImportSales, required this.onDelete, required this.onRecheck, required this.onPro, this.initialFilter = 'open'});
  @override
  State<V13FlipsPage> createState() => _V13FlipsPageState();
}

class _V13FlipsPageState extends State<V13FlipsPage> {
  late String filter;
  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    filter = widget.initialFilter;
  }

  Future<void> _importSalesCsv() async {
    final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:const ['csv'],withData:true); if(picked==null||picked.files.isEmpty||!mounted)return;
    final bytes=picked.files.single.bytes; if(bytes==null||bytes.length>5*1024*1024){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('CSV konnte nicht gelesen werden oder ist größer als 5 MB.','CSV could not be read or exceeds 5 MB.'))));return;}
    String content;try{content=utf8.decode(bytes);}catch(_){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(t('CSV muss UTF-8 kodiert sein.','CSV must use UTF-8 encoding.'))));return;}
    final parsed = parseSalesCsv(content);
    var importedCount = 0;
    var duplicateCount = 0;
    if (parsed.rows.isNotEmpty) {
      final knownIds = widget.flips.map((flip) => flip.id).toSet();
      final imported = <V13Flip>[];
      for (final row in parsed.rows) {
        final id = salesCsvRowIdentity(row);
        if (!knownIds.add(id)) {
          duplicateCount++;
          continue;
        }
        imported.add(V13Flip(
          id: id,
          name: row.article,
          category: row.category,
          buy: row.purchasePrice,
          expectedAtBuy: 0,
          costs: row.costs,
          sourceCount: 0,
          confidence: 'Eigener Verkauf',
          status: 'Sold',
          createdAt: row.purchaseDate,
          checkedAt: row.purchaseDate,
          soldAt: row.saleDate,
          actualSell: row.salePrice,
          soldPlatform: row.platform,
        ));
      }
      importedCount = imported.length;
      if (imported.isNotEmpty) widget.onImportSales(imported);
    }
    if (!mounted) return;
    final message = parsed.rows.isEmpty
        ? (parsed.errors.isEmpty ? t('Keine Verkäufe gefunden.', 'No sales found.') : parsed.errors.first)
        : importedCount == 0 && duplicateCount > 0
            ? t('Keine neuen Verkäufe · $duplicateCount bereits vorhanden.', 'No new sales · $duplicateCount already imported.')
            : '$importedCount '+t('Verkäufe importiert','sales imported')+
                (duplicateCount > 0 ? ' · $duplicateCount '+t('Duplikate übersprungen.','duplicates skipped.') : '')+
                (parsed.errors.isEmpty ? '.' : ' · ${parsed.errors.length} '+t('Zeilen fehlerhaft.','invalid rows.'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(message)));
  }

  @override
  void didUpdateWidget(covariant V13FlipsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      filter = widget.initialFilter;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sold = widget.flips.where((e) => e.status == 'Sold').toList();
    final saved = v148PrioritizeSaved(widget.flips);
    final archived = widget.flips.where((e) => e.isArchived).toList()
      ..sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
    final open = widget.flips.where((e) => e.isOpen).toList();
    final shown = filter == 'saved'
        ? saved
        : filter == 'archived'
            ? archived
            : filter == 'sold'
                ? sold
                : filter == 'all'
                    ? widget.flips
                    : open;
    final profit = sold.fold<double>(0, (a, b) => a + b.realizedProfit);
    final capital = open.fold<double>(0, (a, b) => a + b.buy + b.costs);
    final days = sold.map((e) => e.daysToSell).whereType<int>().toList();
    final avgDays = days.isEmpty ? null : days.reduce((a, b) => a + b) / days.length;
    final forecastRows = v13ForecastObservations(sold);
    final forecastAccuracy = forecastAccuracyByCategory(
      forecastRows,
      fallbackEbayDiscount: widget.ebayDiscount,
    );
    final latestForecast = forecastRows.isEmpty ? null : forecastRows.first;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        const Text('Meine Flips', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(t('Gekauft → verkauft → daraus lernt Flipwert.', 'Bought → sold → Flipwert learns from it.'), style: const TextStyle(fontSize: 12.5, color: Color(0xFF777B88))),
        const SizedBox(height: 12),
        OutlinedButton.icon(key: const ValueKey('sales-csv-import'), onPressed: _importSalesCsv, icon: const Icon(Icons.upload_file_rounded), label: Text(t('VERKÄUFE AUS CSV IMPORTIEREN', 'IMPORT SALES CSV'))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: _v13Ink, borderRadius: BorderRadius.circular(22)),
          child: Row(children: [
            Expanded(child: _V13DarkStat(label: t('Gewinn', 'Profit'), value: v13Euro(profit))),
            Expanded(child: _V13DarkStat(label: t('Gebunden', 'Invested'), value: v13Euro(capital))),
            Expanded(child: _V13DarkStat(label: t('Ø Verkauf', 'Avg sell'), value: avgDays == null ? '—' : '${avgDays.toStringAsFixed(0)} T')),
          ]),
        ),
        if (sold.length >= 2) ...[
          const SizedBox(height: 10),
          _V13PersonalInsight(english: widget.english, sold: sold, pro: widget.plan != UserPlan.free, onPro: widget.onPro),
        ],
        if (forecastAccuracy.isNotEmpty) ...[
          const SizedBox(height: 10),
          ForecastAccuracyCard(
            categories: forecastAccuracy,
            latest: latestForecast,
            english: widget.english,
          ),
        ],
        const SizedBox(height: 13),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<String>(segments: [ButtonSegment(value: 'saved', icon: const Icon(Icons.bookmark_outline_rounded, size: 16), label: Text(t('Merkliste', 'Saved'))), ButtonSegment(value: 'open', label: Text(t('Offen', 'Open'))), ButtonSegment(value: 'sold', label: Text(t('Verkauft', 'Sold'))), ButtonSegment(value: 'archived', icon: const Icon(Icons.archive_outlined, size: 16), label: Text(t('Archiv', 'Archive'))), ButtonSegment(value: 'all', label: Text(t('Alle', 'All')))], selected: {filter}, onSelectionChanged: (v) => setState(() => filter = v.first))),
        const SizedBox(height: 12),
        if (filter == 'saved' && saved.isNotEmpty) ...[
          _V149WatchlistAttention(
            english: widget.english,
            saved: saved,
            onRecheck: widget.onRecheck,
          ),
          const SizedBox(height: 10),
        ],
        if (shown.isEmpty)
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)), child: Column(children: [const Icon(Icons.inventory_2_outlined, size: 38, color: _v13Primary), const SizedBox(height: 9), Text(t('Noch nichts hier', 'Nothing here yet'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)), const SizedBox(height: 3), Text(t('Beim Deal einmal auf „Gekauft“ tippen – der Rest wird übernommen.', 'Tap “Bought” once on a deal – the rest is filled automatically.'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, color: Color(0xFF777B88))) ]))
        else
          for (var i = 0; i < shown.length; i++) ...[
            _V13FlipCard(english: widget.english, flip: shown[i], onUpdate: widget.onUpdate, onDelete: widget.onDelete, onRecheck: widget.onRecheck),
            if (widget.plan == UserPlan.free && i == 2) ...[const SizedBox(height: 8), V13BannerAd(monetization: widget.monetization)],
            const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class _V149WatchlistAttention extends StatelessWidget {
  final bool english;
  final List<V13Flip> saved;
  final ValueChanged<V13Flip> onRecheck;
  const _V149WatchlistAttention({required this.english, required this.saved, required this.onRecheck});

  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final stale = saved.where((e) => now.difference(e.checkedAt).inHours >= 24).toList()
      ..sort((a, b) => a.checkedAt.compareTo(b.checkedAt));
    final oldest = stale.isEmpty ? saved.first : stale.first;
    final freshCount = saved.length - stale.length;
    final title = stale.isEmpty
        ? t('Merkliste aktuell', 'Watchlist up to date')
        : t('${stale.length} Deal${stale.length == 1 ? '' : 's'} neu prüfen', '${stale.length} deal${stale.length == 1 ? '' : 's'} to recheck');
    final subtitle = stale.isEmpty
        ? t('Alle gespeicherten Deals wurden in den letzten 24 Std. geprüft.', 'All saved deals were checked within the last 24h.')
        : t('$freshCount von ${saved.length} aktuell · ältester Check ${v147AgeLabel(oldest.checkedAt, false)}.', '$freshCount of ${saved.length} current · oldest check ${v147AgeLabel(oldest.checkedAt, true)}.');
    return Container(
      key: const ValueKey('v149-watchlist-attention'),
      padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
      decoration: BoxDecoration(
        color: stale.isEmpty ? const Color(0xFFF2F7F4) : const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: stale.isEmpty ? const Color(0x22087F5B) : const Color(0x33C47B00)),
      ),
      child: Row(children: [
        Icon(stale.isEmpty ? Icons.check_circle_outline_rounded : Icons.notifications_active_outlined, color: stale.isEmpty ? const Color(0xFF087F5B) : const Color(0xFFC47B00), size: 21),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF707481))),
        ])),
        if (stale.isNotEmpty)
          TextButton(
            key: const ValueKey('v149-recheck-oldest'),
            onPressed: () => onRecheck(oldest),
            child: Text(t(stale.length > 1 ? 'NÄCHSTEN PRÜFEN' : 'PRÜFEN', stale.length > 1 ? 'CHECK NEXT' : 'CHECK')),
          ),
      ]),
    );
  }
}

class _V13DarkStat extends StatelessWidget {
  final String label;
  final String value;
  const _V13DarkStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 7), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: Color(0xFFB8BACC), fontSize: 9.5))]));
}

class _V13PersonalInsight extends StatelessWidget {
  final bool english;
  final List<V13Flip> sold;
  final bool pro;
  final VoidCallback onPro;
  const _V13PersonalInsight({required this.english, required this.sold, required this.pro, required this.onPro});
  String t(String de, String en) => english ? en : de;

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, List<V13Flip>>{};
    for (final f in sold) { byCategory.putIfAbsent(f.category, () => []).add(f); }
    final best = byCategory.entries.toList()..sort((a, b) => b.value.fold<double>(0, (x, y) => x + y.realizedRoi).compareTo(a.value.fold<double>(0, (x, y) => x + y.realizedRoi)));
    final bestName = best.isEmpty ? '—' : best.first.key;
    return Material(
      color: const Color(0xFFEDEDFC),
      borderRadius: BorderRadius.circular(19),
      child: ListTile(
        leading: const Icon(Icons.psychology_alt_rounded, color: _v13Primary),
        title: Text(t('Dein Flip-Muster', 'Your flip pattern'), style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(pro ? t('Stärkste Kategorie bisher: $bestName · ${sold.length} echte Verkäufe fließen ein.', 'Strongest category so far: $bestName · ${sold.length} real sales are used.') : t('${sold.length} Verkäufe gesammelt · PRO nutzt sie für persönliche Empfehlungen.', '${sold.length} sales collected · PRO uses them for personal recommendations.'), style: const TextStyle(fontSize: 11.5)),
        trailing: pro ? const Icon(Icons.check_circle_rounded, color: Color(0xFF087F5B)) : TextButton(onPressed: onPro, child: const Text('PRO')),
      ),
    );
  }
}

