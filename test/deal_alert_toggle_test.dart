import 'package:flipwert/deal_alert.dart';
import 'package:flipwert/deal_alert_store.dart';
import 'package:flipwert/deal_alert_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedAlertStore extends DealAlertStore {
  _FixedAlertStore(this.preference);

  final DealAlertPreference preference;

  @override
  Future<DealAlertPreference?> forFlip(String flipId) async => preference;

  @override
  Future<bool> save(DealAlertPreference preference) async => true;
}

void main() {
  testWidgets('custom private and LIVE thresholds are shown separately',
      (tester) async {
    final store = _FixedAlertStore(DealAlertPreference(
      flipId: 'flip-1',
      enabled: true,
      minProfitIncrease: 8,
      minBuybackProfitIncrease: 12,
      minRoiIncrease: 6,
      updatedAt: DateTime(2026),
    ));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DealAlertToggle(
          flipId: 'flip-1',
          english: false,
          store: store,
        ),
      ),
    ));
    await tester.pump();

    expect(
      find.textContaining(
        'Eigene Schwelle: Privat +8 €, LIVE-Ankauf +12 €, ROI +6 %-Pkt.',
      ),
      findsOneWidget,
    );
  });
}
