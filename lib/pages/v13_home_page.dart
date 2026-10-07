part of '../v13_app.dart';

class V13Home extends StatefulWidget {
  final bool english;
  final UserPlan plan;
  final List<String> history;
  final int openFlips;
  final int savedFlips;
  final int staleSaved;
  final V13Monetization monetization;
  final ValueChanged<String> onSearch;
  final VoidCallback onScan;
  final VoidCallback onSettings;
  final VoidCallback onOpenFlips;
  final VoidCallback onOpenSaved;

  const V13Home({
    super.key,
    required this.english,
    required this.plan,
    required this.history,
    required this.openFlips,
    required this.savedFlips,
    required this.staleSaved,
    required this.monetization,
    required this.onSearch,
    required this.onScan,
    required this.onSettings,
    required this.onOpenFlips,
    required this.onOpenSaved,
  });

  @override
  State<V13Home> createState() => _V13HomeState();
}

class _V13HomeState extends State<V13Home> {
  final query = TextEditingController();
  V13SearchInput preview = const V13SearchInput(raw: '', query: '', kind: V13InputKind.text);

  String t(String de, String en) => widget.english ? en : de;

  void _changed(String value) => setState(() => preview = normalizeV13Search(value));

  void _submit([String? value]) {
    final raw = value ?? query.text;
    final normalized = normalizeV13Search(raw);
    if (normalized.query.isNotEmpty) widget.onSearch(raw);
  }

  void _clearSearch() {
    query.clear();
    setState(() => preview = const V13SearchInput(raw: '', query: '', kind: V13InputKind.text));
  }

  Future<void> _paste() async {
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clip?.text?.trim() ?? '';
    if (text.isEmpty || !mounted) return;
    query.text = text.length > 500 ? text.substring(0, 500) : text;
    query.selection = TextSelection.collapsed(offset: query.text.length);
    _changed(query.text);
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final typed = query.text.trim().toLowerCase();
    final suggestions = widget.history
        .where((e) => typed.isEmpty || e.toLowerCase().contains(typed))
        .take(4)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        Row(
          children: [
            const Expanded(child: Text('Flipwert', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.6))),
            if (widget.plan != UserPlan.free)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: _V13Pill(text: 'PRO', foreground: Colors.white, background: _v13Primary),
              ),
            IconButton.filledTonal(onPressed: widget.onSettings, tooltip: t('Einstellungen', 'Settings'), icon: const Icon(Icons.tune_rounded)),
          ],
        ),
        const SizedBox(height: 25),
        Text(t('Artikel rein.\nEntscheidung raus.', 'Item in.\nDecision out.'), style: const TextStyle(fontSize: 34, height: .98, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
        const SizedBox(height: 9),
        Text(t('Suchen → Maximalpreis, Gewinn, Markt & Risiko.', 'Search → max buy, profit, market & risk.'), style: const TextStyle(fontSize: 14, color: Color(0xFF717585))),
        const SizedBox(height: 20),
        TextField(
          key: const ValueKey('v13-universal-search'),
          controller: query,
          autofocus: false,
          minLines: 1,
          maxLines: 3,
          onChanged: _changed,
          onSubmitted: _submit,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            labelText: t('Produkt, Link, EAN oder ASIN', 'Product, link, EAN or ASIN'),
            hintText: t('z. B. Samsung Fold 8 512 GB', 'e.g. Samsung Fold 8 512 GB'),
            prefixIcon: const Icon(Icons.search_rounded, size: 25),
            suffixIcon: query.text.trim().isEmpty
                ? IconButton(key: const ValueKey('v150-paste-and-check'), onPressed: _paste, tooltip: t('Einfügen & prüfen', 'Paste & check'), icon: const Icon(Icons.content_paste_rounded))
                : IconButton(key: const ValueKey('v145-clear-search'), onPressed: _clearSearch, tooltip: t('Leeren', 'Clear'), icon: const Icon(Icons.close_rounded)),
          ),
        ),
        if (query.text.trim().isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(
            _inputHint(preview),
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF6C7080), fontWeight: FontWeight.w700),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('v13-check-button'),
                onPressed: () => _submit(),
                style: FilledButton.styleFrom(backgroundColor: _v13Ink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 18)),
                icon: const Icon(Icons.bolt_rounded),
                label: Text(t('FLIP PRÜFEN', 'CHECK FLIP')),
              ),
            ),
            const SizedBox(width: 9),
            OutlinedButton.icon(onPressed: widget.onScan, icon: const Icon(Icons.qr_code_scanner_rounded, size: 19), label: Text(t('Barcode', 'Barcode'))),
          ],
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(t('Schnell wiederholen', 'Quick repeat'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: suggestions.map((e) => ActionChip(
                  avatar: const Icon(Icons.history_rounded, size: 15),
                  label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 190), child: Text(e, overflow: TextOverflow.ellipsis)),
                  onPressed: () => _submit(e),
                )).toList(),
          ),
        ],
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EF))),
          child: Row(
            children: [
              const Icon(Icons.speed_rounded, color: _v13Primary),
              const SizedBox(width: 10),
              Expanded(child: Text(t('Ziel: in wenigen Sekunden wissen, ob und bis wohin du kaufen solltest.', 'Goal: know within seconds whether to buy and your maximum price.'), style: const TextStyle(fontSize: 12.3, fontWeight: FontWeight.w800, color: Color(0xFF555968)))),
            ],
          ),
        ),
        if (widget.savedFlips > 0) ...[
          const SizedBox(height: 13),
          Material(
            key: const ValueKey('v152-watchlist-home-attention'),
            color: widget.staleSaved > 0 ? const Color(0xFFFFF7E8) : const Color(0xFFF4F5FA),
            borderRadius: BorderRadius.circular(18),
            child: ListTile(
              onTap: widget.onOpenSaved,
              leading: Icon(widget.staleSaved > 0 ? Icons.notifications_active_outlined : Icons.bookmark_rounded, color: widget.staleSaved > 0 ? const Color(0xFFC47B00) : _v13Primary),
              title: Text(widget.staleSaved > 0 ? t('${widget.staleSaved} gespeicherte Deals neu prüfen', '${widget.staleSaved} saved deals need a recheck') : t('${widget.savedFlips} Deals gemerkt', '${widget.savedFlips} deals saved'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              subtitle: Text(widget.staleSaved > 0 ? t('Marktpreise sind älter als 24 Std.', 'Market prices are older than 24h.') : t('Merkliste öffnen und Preise erneut prüfen.', 'Open saved deals and recheck prices.'), style: const TextStyle(fontSize: 10.8)),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        ],
        if (widget.openFlips > 0) ...[
          const SizedBox(height: 13),
          OutlinedButton.icon(
            key: const ValueKey('v145-open-flips'),
            onPressed: widget.onOpenFlips,
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: Text(t('${widget.openFlips} offene Flips ansehen', 'View ${widget.openFlips} open flips')),
          ),
        ],
        if (widget.plan == UserPlan.free) ...[
          const SizedBox(height: 26),
          V13BannerAd(monetization: widget.monetization),
        ],
      ],
    );
  }

  String _inputHint(V13SearchInput input) {
    switch (input.kind) {
      case V13InputKind.url:
        return t('Link erkannt → Flipwert sucht nach „${input.query}“', 'Link detected → searching for “${input.query}”');
      case V13InputKind.ean:
        return t('EAN erkannt', 'EAN detected');
      case V13InputKind.asin:
        return t('ASIN erkannt', 'ASIN detected');
      case V13InputKind.text:
        if (input.correction != null) return t('Schreibweise erkannt → ${input.query}', 'Spelling normalized → ${input.query}');
        return t('Direkte Produktsuche', 'Direct product search');
    }
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }
}
