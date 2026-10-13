import 'package:flipwert/deal_alert.dart';
import 'package:flipwert/deal_alert_overview.dart';
import 'package:flipwert/deal_alert_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedAlertStore extends DealAlertStore {
  _FixedAlertStore(this.preferences);

  final List<DealAlertPreference> preferences;

  @override
  Future<List<DealAlertPreference>> load() async => preferences;
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
}
