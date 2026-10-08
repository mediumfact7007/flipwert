part of '../v13_app.dart';

class FlipwertV13App extends StatefulWidget {
  const FlipwertV13App({super.key});

  @override
  State<FlipwertV13App> createState() => _FlipwertV13AppState();
}

class _FlipwertV13AppState extends State<FlipwertV13App> {
  bool loading = true;
  bool showOnboarding = true;
  bool english = false;
  String backend = '';
  double targetRoi = 35;
  double minProfit = 20;
  double ebayDiscount = .10;
  UserPlan plan = UserPlan.free;
  V13TaxMode taxMode = V13TaxMode.privateSeller;
  List<V13Flip> flips = [];
  List<String> history = [];
  List<PriceSource> sources = [];
  late final V13Monetization monetization;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    monetization = V13Monetization(onProUnlocked: _unlockPro);
    unawaited(_loadSafe());
  }

  Future<void> _loadSafe() async {
    try {
      await _load();
    } catch (_) {
      if (!mounted) return;
      var shouldShowOnboarding = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        shouldShowOnboarding =
            !(prefs.getBool('onboarding_v13_complete') ?? false) &&
                !v13HasExistingUserState(prefs);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        // A corrupt/incompatible preference from an older prototype must never
        // prevent Flipwert from opening. Start with sane local defaults.
        english = false;
        backend = '';
        targetRoi = 35;
        minProfit = 20;
        ebayDiscount = .10;
        plan = UserPlan.free;
        taxMode = V13TaxMode.privateSeller;
        flips = <V13Flip>[];
        history = <String>[];
        sources = SourceRegistry.builtIns();
        showOnboarding = shouldShowOnboarding;
        loading = false;
      });
    }
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete =
        prefs.getBool('onboarding_v13_complete') ?? false;
    final existingUser = v13HasExistingUserState(prefs);
    final rawFlips = prefs.getStringList('flips_v13') ??
        prefs.getStringList('flips_v10') ??
        prefs.getStringList('flips_v09') ??
        prefs.getStringList('flips_v08') ??
        <String>[];
    final loadedFlips = <V13Flip>[];
    for (final raw in rawFlips) {
      try {
        loadedFlips.add(V13Flip.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {}
    }
    final loadedBackend = prefs.getString('backend_v13') ?? prefs.getString('backend_v10') ?? '';
    final loadedSources = await SourceRegistry.load(backendBase: loadedBackend);
    await DealAlertStore().retainOnly(
      loadedFlips
          .where((flip) => flip.isSaved || flip.isArchived)
          .map((flip) => flip.id),
    );
    final rawPlan = prefs.getInt('plan_v13') ?? prefs.getInt('plan_preview_v10') ?? 0;
    final rawTax = prefs.getInt('tax_mode_v13') ?? 0;
    if (!mounted) return;
    setState(() {
      english = prefs.getBool('english_v13') ?? prefs.getBool('english_v10') ?? false;
      backend = loadedBackend;
      targetRoi = (prefs.getDouble('roi_v13') ?? prefs.getDouble('roi_v10') ?? 35).clamp(10, 100).toDouble();
      minProfit = (prefs.getDouble('min_profit_v13') ?? prefs.getDouble('min_profit_v12') ?? 20).clamp(0, 500).toDouble();
      ebayDiscount = (prefs.getDouble('ebay_discount_v13') ?? .10)
          .clamp(0, .40)
          .toDouble();
      plan = rawPlan <= 0 ? UserPlan.free : UserPlan.pro;
      taxMode = V13TaxMode.values[rawTax.clamp(0, V13TaxMode.values.length - 1)];
      flips = loadedFlips;
      history = (prefs.getStringList('history_v13') ?? prefs.getStringList('history_v10') ?? <String>[])
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .take(12)
          .toList();
      sources = loadedSources;
      showOnboarding = !onboardingComplete && !existingUser;
      loading = false;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_v13_complete', true);
    if (!mounted) return;
    setState(() => showOnboarding = false);
  }

  Future<bool> _deleteAllLocalData() async {
    var deleted = false;
    _saveQueue = _saveQueue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      deleted = await prefs.clear();
      if (deleted) deleted = prefs.getKeys().isEmpty;
    }).catchError((_) {
      deleted = false;
    });
    await _saveQueue;
    if (!deleted || !mounted) return false;

    setState(() {
      english = false;
      backend = '';
      targetRoi = 35;
      minProfit = 20;
      ebayDiscount = .10;
      plan = UserPlan.free;
      taxMode = V13TaxMode.privateSeller;
      flips = <V13Flip>[];
      history = <String>[];
      sources = SourceRegistry.builtIns();
      showOnboarding = true;
    });
    return true;
  }

  void _unlockPro() {
    if (!mounted) return;
    setState(() => plan = UserPlan.pro);
    _save();
  }

  void _save() {
    _saveQueue = _saveQueue.then((_) async {
      final p = await SharedPreferences.getInstance();
      await p.setBool('english_v13', english);
      await p.setString('backend_v13', backend);
      await p.setDouble('roi_v13', targetRoi);
      await p.setDouble('min_profit_v13', minProfit);
      await p.setDouble('ebay_discount_v13', ebayDiscount);
      await p.setInt('plan_v13', plan == UserPlan.free ? 0 : 1);
      await p.setInt('tax_mode_v13', taxMode.index);
      await p.setStringList('flips_v13', flips.map((e) => jsonEncode(e.toJson())).toList());
      await p.setStringList('history_v13', history.take(12).toList());
    }).catchError((_) {});
  }

  void _addHistory(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return;
    setState(() {
      history.removeWhere((e) => e.toLowerCase() == q.toLowerCase());
      history.insert(0, q);
      if (history.length > 12) history = history.take(12).toList();
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _v13Bg,
      colorScheme: ColorScheme.fromSeed(seedColor: _v13Primary, surface: _v13Bg),
      appBarTheme: const AppBarTheme(backgroundColor: _v13Bg, surfaceTintColor: Colors.transparent),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Color(0xFFE4E6EE))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _v13Primary, width: 1.8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );

    return MaterialApp(
      title: 'Flipwert',
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : showOnboarding
              ? V13OnboardingPage(
                  english: english,
                  onComplete: _completeOnboarding,
                )
              : V13Shell(
              english: english,
              backend: backend,
              targetRoi: targetRoi,
              minProfit: minProfit,
              ebayDiscount: ebayDiscount,
              plan: plan,
              taxMode: taxMode,
              flips: flips,
              history: history,
              sources: sources,
              monetization: monetization,
              onHistory: _addHistory,
              onAddFlip: (item) {
                setState(() => flips.insert(0, item));
                _save();
              },
              onImportSales: (items) { setState(() => flips.insertAll(0, items)); _save(); },
              onUpdateFlip: (item) {
                final i = flips.indexWhere((e) => e.id == item.id);
                if (i >= 0) {
                  final previous = flips[i];
                  setState(() => flips[i] = item);
                  _save();
                  unawaited(_syncDealAlertLifecycle(previous, item));
                }
              },
              onDeleteFlip: (id) {
                setState(() => flips.removeWhere((e) => e.id == id));
                _save();
                unawaited(DealAlertStore().remove(id));
              },
              onLanguage: (value) {
                setState(() => english = value);
                _save();
              },
              onRoi: (value) {
                setState(() => targetRoi = value.clamp(10, 100).toDouble());
                _save();
              },
              onMinProfit: (value) {
                setState(() => minProfit = value.clamp(0, 500).toDouble());
                _save();
              },
              onEbayDiscount: (value) {
                setState(() => ebayDiscount = value.clamp(0, .40).toDouble());
                _save();
              },
              onTaxMode: (value) {
                setState(() => taxMode = value);
                _save();
              },
              onBackend: (value) async {
                backend = value.trim();
                final loaded = await SourceRegistry.load(backendBase: backend);
                if (mounted) setState(() => sources = loaded);
                _save();
              },
              onSources: (value) {
                setState(() => sources = value);
                unawaited(SourceRegistry.save(value));
              },
              onPlanPreview: (value) {
                setState(() => plan = value == UserPlan.free ? UserPlan.free : UserPlan.pro);
                _save();
              },
              onDeleteAllLocalData: _deleteAllLocalData,
            ),
    );
  }

  @override
  void dispose() {
    monetization.dispose();
    super.dispose();
  }
}

class V13Shell extends StatefulWidget {
  final bool english;
  final String backend;
  final double targetRoi;
  final double minProfit;
  final double ebayDiscount;
  final UserPlan plan;
  final V13TaxMode taxMode;
  final List<V13Flip> flips;
  final List<String> history;
  final List<PriceSource> sources;
  final V13Monetization monetization;
  final ValueChanged<String> onHistory;
  final ValueChanged<V13Flip> onAddFlip;
  final ValueChanged<V13Flip> onUpdateFlip;
  final ValueChanged<List<V13Flip>> onImportSales;
  final ValueChanged<String> onDeleteFlip;
  final ValueChanged<bool> onLanguage;
  final ValueChanged<double> onRoi;
  final ValueChanged<double> onMinProfit;
  final ValueChanged<double> onEbayDiscount;
  final ValueChanged<V13TaxMode> onTaxMode;
  final ValueChanged<String> onBackend;
  final ValueChanged<List<PriceSource>> onSources;
  final ValueChanged<UserPlan> onPlanPreview;
  final Future<bool> Function() onDeleteAllLocalData;

  const V13Shell({
    super.key,
    required this.english,
    required this.backend,
    required this.targetRoi,
    required this.minProfit,
    this.ebayDiscount = .10,
    required this.plan,
    required this.taxMode,
    required this.flips,
    required this.history,
    required this.sources,
    required this.monetization,
    required this.onHistory,
    required this.onAddFlip,
    required this.onUpdateFlip,
    required this.onImportSales,
    required this.onDeleteFlip,
    required this.onLanguage,
    required this.onRoi,
    required this.onMinProfit,
    required this.onEbayDiscount,
    required this.onTaxMode,
    required this.onBackend,
    required this.onSources,
    required this.onPlanPreview,
    required this.onDeleteAllLocalData,
  });

  @override
  State<V13Shell> createState() => _V13ShellState();
}

class _V13ShellState extends State<V13Shell> {
  int tab = 0;
  String flipsInitialFilter = 'open';
  bool opening = false;
  StreamSubscription<List<SharedMediaFile>>? shareSub;
  String lastShare = '';
  DateTime? lastShareAt;

  String t(String de, String en) => widget.english ? en : de;

  @override
  void initState() {
    super.initState();
    // Keep first-frame startup clean, then restore the native share listener.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (Platform.isAndroid || Platform.isIOS) _listenShares();
    });
  }

  // ignore: unused_element
  void _listenShares() {
    if (shareSub != null) return;
    try {
      shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(_handleShare, onError: (_) {});
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final initial = await ReceiveSharingIntent.instance.getInitialMedia();
          if (initial.isNotEmpty) _handleShare(initial);
          await ReceiveSharingIntent.instance.reset();
        } catch (_) {}
      });
    } catch (_) {}
  }

  void _handleShare(List<SharedMediaFile> items) {
    if (!mounted) return;
    for (final item in items) {
      final mime = item.mimeType ?? '';
      if (item.type == SharedMediaType.text || item.type == SharedMediaType.url || mime.startsWith('text/')) {
        final normalized = normalizeV13Search(item.path);
        if (normalized.query.isEmpty) return;
        final now = DateTime.now();
        if (normalized.query.toLowerCase() == lastShare.toLowerCase() && lastShareAt != null && now.difference(lastShareAt!).inSeconds < 4) return;
        lastShare = normalized.query;
        lastShareAt = now;
        unawaited(_openCheck(item.path));
        return;
      }
    }
  }

  Future<void> _openCheck(String raw, {V13Flip? existingSnapshot}) async {
    if (opening) return;
    final normalized = normalizeV13Search(raw);
    if (normalized.query.isEmpty) return;
    opening = true;
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => V13CheckPage(
            english: widget.english,
            input: normalized,
            backendBase: widget.backend,
            targetRoi: widget.targetRoi,
            minProfit: widget.minProfit,
            ebayDiscount: widget.ebayDiscount,
            plan: widget.plan,
            taxMode: widget.taxMode,
            sources: widget.sources,
            flips: widget.flips,
            monetization: widget.monetization,
            onHistory: widget.onHistory,
            onAddFlip: widget.onAddFlip,
            existingSnapshot: existingSnapshot,
            onUpdateFlip: widget.onUpdateFlip,
          ),
        ),
      );
    } finally {
      opening = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _recheckFlip(V13Flip flip) async {
    final raw = flip.sourceUrl.isNotEmpty ? '${flip.name}\n${flip.sourceUrl}' : flip.name;
    await _openCheck(raw, existingSnapshot: flip);
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => ScannerPage(english: widget.english)));
    if (code != null && code.trim().isNotEmpty && mounted) await _openCheck(code);
  }

  Future<void> _settings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => V13SettingsPage(
          english: widget.english,
          backend: widget.backend,
          targetRoi: widget.targetRoi,
          minProfit: widget.minProfit,
          ebayDiscount: widget.ebayDiscount,
          plan: widget.plan,
          taxMode: widget.taxMode,
          sources: widget.sources,
          monetization: widget.monetization,
          onLanguage: widget.onLanguage,
          onRoi: widget.onRoi,
          onMinProfit: widget.onMinProfit,
          onEbayDiscount: widget.onEbayDiscount,
          onTaxMode: widget.onTaxMode,
          onBackend: widget.onBackend,
          onSources: widget.onSources,
          onPlanPreview: widget.onPlanPreview,
          onDeleteAllLocalData: widget.onDeleteAllLocalData,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final savedFlips = v148PrioritizeSaved(widget.flips);
    final staleSaved = savedFlips.where((e) => DateTime.now().difference(e.checkedAt).inHours >= 24).length;
    final pages = [
      V13Home(
        english: widget.english,
        plan: widget.plan,
        history: widget.history,
        openFlips: widget.flips.where((e) => e.isOpen).length,
        savedFlips: savedFlips.length,
        staleSaved: staleSaved,
        monetization: widget.monetization,
        onSearch: _openCheck,
        onScan: _scan,
        onSettings: _settings,
        onOpenFlips: () => setState(() { flipsInitialFilter = 'open'; tab = 1; }),
        onOpenSaved: () => setState(() { flipsInitialFilter = 'saved'; tab = 1; }),
      ),
      V13FlipsPage(
        english: widget.english,
        plan: widget.plan,
        ebayDiscount: widget.ebayDiscount,
        flips: widget.flips,
        monetization: widget.monetization,
        onUpdate: widget.onUpdateFlip,
        onImportSales: widget.onImportSales,
        onDelete: widget.onDeleteFlip,
        onRecheck: _recheckFlip,
        onPro: () => _openPaywall(context),
        initialFilter: flipsInitialFilter,
      ),
    ];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        height: 66,
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.search_rounded), label: t('Prüfen', 'Check')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_outlined), selectedIcon: const Icon(Icons.inventory_2_rounded), label: t('Meine Flips', 'My flips')),
        ],
      ),
    );
  }

  Future<void> _openPaywall(BuildContext context) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => V13Paywall(english: widget.english, monetization: widget.monetization)));
  }

  @override
  void dispose() {
    shareSub?.cancel();
    super.dispose();
  }
}

