import 'package:flipwert/deal_alert.dart';
import 'package:flipwert/deal_alert_overview.dart';
import 'package:flipwert/deal_alert_result_store.dart';
import 'package:flipwert/deal_alert_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedAlertStore extends DealAlertStore {
  _FixedAlertStore(this.preferences);

  final List<DealAlertPreference> preferences;

  @override
  Future<List<DealAlertPreference>> load() async => preferences;
}

class _FixedResultStore extends DealAlertResultStore {
  _FixedResultStore(this.results);

  final List<DealAlertResult> results;

  @override
  Future<List<DealAlertResult>> load() async => results;
}

DealAlertPreference _preference(String id, {bool enabled = true}) =>
    DealAlertPreference(
      flipId: id,
      enabled: enabled,
      minProfitIncrease: 5,
      minBuybackProfitIncrease: 5,
      minRoiIncrease: 5,
      updatedAt: DateTime(2026, 10, 13),
    );

void main() {
  testWidgets('shows active local alerts and rechecks the oldest due deal',
      (tester) async {
    final now = DateTime(2026, 10, 13, 12);
    String? requested;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DealAlertOverview(
          english: false,
          now: now,
          store: _FixedAlertStore([
            _preference('fresh'),
            _preference('oldest'),
            _preference('disabled', enabled: false),
          ]),
          resultStore: _FixedResultStore(const []),
          items: [
            DealAlertOverviewItem(
              flipId: 'fresh',
              name: 'Frischer Deal',
              checkedAt: now.subtract(const Duration(hours: 2)),
            ),
            DealAlertOverviewItem(
              flipId: 'oldest',
              name: 'Ältester Deal',
              checkedAt: now.subtract(const Duration(days: 3)),
            ),
            DealAlertOverviewItem(
              flipId: 'disabled',
              name: 'Ausgeschaltet',
              checkedAt: now.subtract(const Duration(days: 5)),
            ),
          ],
          onRecheck: (id) => requested = id,
        ),
      ),
    ));
    await tester.pump();

    expect(find.byKey(const ValueKey('deal-alert-overview')), findsOneWidget);
    expect(find.text('2 aktive Deal-Alarme'), findsOneWidget);
    expect(find.textContaining('1 Prüfung ist fällig.'), findsOneWidget);
    expect(find.textContaining('Nur lokal; Auswertung beim Recheck.'),
        findsOneWidget);
    expect(find.text('Ausgeschaltet'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('deal-alert-recheck-next')));
    expect(requested, 'oldest');
  });

  testWidgets('stays hidden when no alert is enabled', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DealAlertOverview(
          english: false,
          store: _FixedAlertStore([_preference('deal', enabled: false)]),
          resultStore: _FixedResultStore(const []),
          items: [
            DealAlertOverviewItem(
              flipId: 'deal',
              name: 'Deal',
              checkedAt: DateTime(2026),
            ),
          ],
          onRecheck: (_) {},
        ),
      ),
    ));
    await tester.pump();

    expect(find.byKey(const ValueKey('deal-alert-overview')), findsNothing);
  });

  testWidgets('keeps the latest triggered result visible in the overview',
      (tester) async {
    final now = DateTime(2026, 10, 13, 18);
    final evaluation = DealAlertEvaluation(
      triggered: true,
      profitIncrease: 15,
      roiIncrease: 8,
      buybackProfitIncrease: 0,
      profitThresholdReached: true,
      roiThresholdReached: true,
      buybackProfitThresholdReached: false,
      becameProfitable: false,
      buybackBecameProfitable: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DealAlertOverview(
          english: false,
          now: now,
          store: _FixedAlertStore([_preference('deal')]),
          resultStore: _FixedResultStore([
            DealAlertResult.fromEvaluation(
              flipId: 'deal',
              checkedAt: now,
              evaluation: evaluation,
            ),
          ]),
          items: [
            DealAlertOverviewItem(
              flipId: 'deal',
              name: 'Nintendo Switch OLED',
              checkedAt: now,
            ),
          ],
          onRecheck: (_) {},
        ),
      ),
    ));
    await tester.pump();

    expect(find.textContaining('1 zuletzt ausgelöst.'), findsOneWidget);
    expect(find.byKey(const ValueKey('deal-alert-result-deal')), findsOneWidget);
    expect(find.text('AUSGELÖST'), findsOneWidget);
  });
}
