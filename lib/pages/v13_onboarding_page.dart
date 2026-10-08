part of '../v13_app.dart';

const _v13ExistingUserKeys = <String>{
  'backend_v13',
  'backend_v10',
  'ebay_discount_v13',
  'english_v13',
  'english_v10',
  'flips_v13',
  'flips_v10',
  'flips_v09',
  'flips_v08',
  'history_v13',
  'history_v10',
  'min_profit_v13',
  'min_profit_v12',
  'plan_v13',
  'plan_preview_v10',
  'roi_v13',
  'roi_v10',
  'tax_mode_v13',
};

bool v13HasExistingUserState(SharedPreferences prefs) =>
    prefs.getKeys().any(_v13ExistingUserKeys.contains);

class V13OnboardingPage extends StatefulWidget {
  final bool english;
  final Future<void> Function() onComplete;

  const V13OnboardingPage({
    super.key,
    required this.english,
    required this.onComplete,
  });

  @override
  State<V13OnboardingPage> createState() => _V13OnboardingPageState();
}

class _V13OnboardingPageState extends State<V13OnboardingPage> {
  final controller = PageController();
  int page = 0;
  bool completing = false;

  String t(String de, String en) => widget.english ? en : de;

  Future<void> _next() async {
    if (page < 2) {
      await controller.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _complete();
  }

  Future<void> _complete() async {
    if (completing) return;
    setState(() => completing = true);
    try {
      await widget.onComplete();
    } finally {
      if (mounted) setState(() => completing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        key: const ValueKey('v13-onboarding'),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
                child: Row(
                  children: [
                    const Text(
                      'Flipwert',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.5,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      key: const ValueKey('v13-onboarding-skip'),
                      onPressed: completing ? null : _complete,
                      child: Text(t('Überspringen', 'Skip')),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  key: const ValueKey('v13-onboarding-pages'),
                  controller: controller,
                  onPageChanged: (value) => setState(() => page = value),
                  children: [
                    _V13OnboardingStep(
                      icon: Icons.bolt_rounded,
                      title: t(
                        'Kaufpreis eingeben.\nErgebnis verstehen.',
                        'Enter the buy price.\nUnderstand the result.',
                      ),
                      body: t(
                        'Flipwert berechnet Maximalpreis, erwarteten Gewinn, ROI und Risiko – damit du schneller entscheiden kannst.',
                        'Flipwert calculates your maximum price, expected profit, ROI and risk so you can decide faster.',
                      ),
                      points: [
                        t('Produkt oder Kennung suchen', 'Search for a product or identifier'),
                        t('Einkaufspreis ergänzen', 'Add your purchase price'),
                        t('Angebote und Ergebnis prüfen', 'Review offers and the result'),
                      ],
                    ),
                    _V13OnboardingStep(
                      icon: Icons.verified_outlined,
                      title: t(
                        'LIVE heißt wirklich aktuell.',
                        'LIVE means genuinely current.',
                      ),
                      body: t(
                        'Nur freigegebene Anbieterquellen mit aktuellem Preis werden als LIVE gewertet. Fehlende Werte werden nicht geschätzt.',
                        'Only approved provider sources with a current price count as LIVE. Missing values are not estimated.',
                      ),
                      points: [
                        t('LIVE und Sandbox klar getrennt', 'LIVE and sandbox clearly separated'),
                        t('Gerät und Zustand exakt abgleichen', 'Match exact device and condition'),
                        t('Alter und Herkunft sichtbar', 'Age and origin remain visible'),
                      ],
                    ),
                    _V13OnboardingStep(
                      icon: Icons.link_rounded,
                      title: t(
                        'Links bleiben unter deiner Kontrolle.',
                        'Links stay under your control.',
                      ),
                      body: t(
                        'Geteilte Anzeigen werden nur extern geöffnet. Nutze freiwillig geteilten Text oder trage den Angebotspreis manuell ein.',
                        'Shared listings only open externally. Use voluntarily shared text or enter the asking price manually.',
                      ),
                      points: [
                        t('Keine automatisierten Anzeigenabrufe', 'No automated listing requests'),
                        t('Preis vor der Entscheidung bestätigen', 'Confirm the price before deciding'),
                        t('Danach direkt den Flip prüfen', 'Then check the flip directly'),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: index == page ? 22 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: index == page
                                ? _v13Primary
                                : const Color(0xFFD8DAE4),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const ValueKey('v13-onboarding-next'),
                        onPressed: completing ? null : _next,
                        icon: completing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(page == 2
                                ? Icons.arrow_forward_rounded
                                : Icons.navigate_next_rounded),
                        label: Text(page == 2
                            ? t('FLIPWERT STARTEN', 'START FLIPWERT')
                            : t('WEITER', 'NEXT')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class _V13OnboardingStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final List<String> points;

  const _V13OnboardingStep({
    required this.icon,
    required this.title,
    required this.body,
    required this.points,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE9E8FF),
                borderRadius: BorderRadius.circular(21),
              ),
              child: Icon(icon, size: 34, color: _v13Primary),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: const TextStyle(
                fontSize: 31,
                height: 1.02,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              body,
              style: const TextStyle(
                fontSize: 14.5,
                height: 1.45,
                color: Color(0xFF676B79),
              ),
            ),
            const SizedBox(height: 28),
            for (final point in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: Color(0xFF087F5B),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        point,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}
