part of '../v13_app.dart';

class V13SourcesPage extends StatefulWidget {
  final bool english;
  final List<PriceSource> sources;
  final ValueChanged<List<PriceSource>> onChanged;
  const V13SourcesPage({super.key, required this.english, required this.sources, required this.onChanged});
  @override
  State<V13SourcesPage> createState() => _V13SourcesPageState();
}

class _V13SourcesPageState extends State<V13SourcesPage> {
  late List<PriceSource> items;
  MarketBackendStatus? runtimeStatus;
  bool checkingStatus = true;
  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    items = [...widget.sources];
    unawaited(_loadRuntimeStatus());
  }

  Future<void> _loadRuntimeStatus() async {
    if (mounted) setState(() => checkingStatus = true);
    final status = await MarketStatusClient.fetch(items);
    if (!mounted) return;
    setState(() {
      runtimeStatus = status;
      checkingStatus = false;
    });
  }

  String _connection(PriceSource source) {
    if (!source.canFetchInApp) return t('Browser-Suche', 'Browser search');
    if (checkingStatus) return t('Prüfe Live-Status …', 'Checking live status …');
    final status = runtimeStatus;
    if (status == null || !status.reachable) {
      return t('Server nicht erreichbar', 'Server unavailable');
    }
    if (status.isSandbox(source.id)) return 'SANDBOX';
    if (status.isLive(source.id)) return 'LIVE';
    return t('Noch nicht verbunden', 'Not connected yet');
  }

  String _summary() {
    if (checkingStatus) return t('Flipwert-Server wird geprüft …', 'Checking Flipwert server …');
    final status = runtimeStatus;
    if (status == null || !status.reachable) {
      return t(
        'Live-Server momentan nicht erreichbar. Browser-Suchen funktionieren weiter.',
        'Live server is currently unavailable. Browser searches still work.',
      );
    }
    final sandbox = items.where((source) => status.isSandbox(source.id)).map((e) => e.name).toList();
    final live = items.where((source) => status.isLive(source.id)).map((e) => e.name).toList();
    if (sandbox.isNotEmpty && live.isEmpty) {
      return t(
        'eBay Sandbox verbunden. Testdaten werden niemals für Kaufentscheidungen oder MAX-Preise verwendet.',
        'eBay Sandbox connected. Test data is never used for buy decisions or MAX prices.',
      );
    }
    final buyback = status.buyback;
    final buybackDetail = buyback == null
        ? ''
        : status.isBuybackValidated
            ? t(
                'Sofort-Ankauf: Rechte + Feed validiert · ${buyback.approvedProviderCount} Anbieter freigegeben.',
                'Buyback: rights + feed validated · ${buyback.approvedProviderCount} providers approved.',
              )
            : status.isBuybackRightsApproved
                ? t(
                    'Sofort-Ankauf: Anbieterrechte bestätigt, Feed-Validierung noch ausstehend.',
                    'Buyback: provider rights approved, feed validation still pending.',
                  )
                : t(
                    'Sofort-Ankauf: deaktiviert, bis Anbieterrechte und Feed-Validierung vollständig sind.',
                    'Buyback: disabled until provider rights and feed validation are complete.',
                  );
    if (live.isEmpty) {
      final market = t(
        'Live-Marktdaten sind vorbereitet; nicht konfigurierte Quellen liefern keine Preise.',
        'Live market data is prepared; unconfigured sources provide no prices.',
      );
      return buybackDetail.isEmpty ? market : '$market $buybackDetail';
    }
    final market = '${t('Live verbunden', 'Live connected')}: ${live.join(', ')}.';
    return buybackDetail.isEmpty ? market : '$market $buybackDetail';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(t('Preisquellen', 'Price sources'), style: const TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: t('Status neu prüfen', 'Refresh status'),
              onPressed: checkingStatus ? null : _loadRuntimeStatus,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(18, 5, 18, 28), children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              checkingStatus
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                  : Icon(
                      runtimeStatus?.reachable == true ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                      color: runtimeStatus?.reachable == true ? const Color(0xFF087F5B) : const Color(0xFF777B88),
                      size: 21,
                    ),
              const SizedBox(width: 10),
              Expanded(child: Text(_summary(), style: const TextStyle(fontSize: 11.5, color: Color(0xFF666A77), fontWeight: FontWeight.w700))),
            ]),
          ),
          const SizedBox(height: 10),
          Text(t('Nur Quellen aktivieren, die du wirklich sehen willst.', 'Only enable sources you actually want to see.'), style: const TextStyle(fontSize: 12, color: Color(0xFF747885))),
          const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: SwitchListTile(
                value: items[i].enabled,
                onChanged: (v) {
                  setState(() => items[i] = items[i].copyWith(enabled: v));
                  widget.onChanged([...items]);
                },
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                secondary: Icon(_sourceIcon(items[i].id), color: _sourceColor(items[i])),
                title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text('${_role(items[i])} · ${_connection(items[i])}', style: const TextStyle(fontSize: 10.5)),
              ),
            ),
        ]),
      );

  String _role(PriceSource s) { switch (s.role) { case 'resale': return t('Wiederverkauf', 'Resale'); case 'local': return t('Lokal/Secondhand', 'Local/secondhand'); case 'retail': return t('Neupreis', 'Retail'); case 'buyback': return t('Sofort-Ankauf', 'Buyback'); case 'refurb': return 'Refurbished'; default: return t('Referenz', 'Reference'); } }
}
