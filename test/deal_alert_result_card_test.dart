import 'package:flipwert/deal_alert.dart';
import 'package:flipwert/deal_alert_result_card.dart';
import 'package:flipwert/deal_alert_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FixedAlertStore extends DealAlertStore {
  _FixedAlertStore(this.preference);

  final DealAlertPreference preference;

  @override
  Future<DealAlertPreference?> forFlip(String flipId) async => preference;
}

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('verified LIVE buyback improvement is explained separately',
      (tester) async {
    final store = _FixedAlertStore(DealAlertPreference.defaults('flip-1'));
    await tester.pumpWidget(_host(DealAlertResultCard(
      flipId: 'flip-1',
      english: false,
      previousProfit: 0,
      currentProfit: 0,
      previousRoi: 0,
      currentRoi: 0,
      hasPrivateComparison: false,
      previousBuybackProfit: 4,
      currentBuybackProfit: 11,
      verifiedBuybackComparison: true,
      store: store,
    )));
    await tester.pump();

    expect(find.byKey(const ValueKey('v153-deal-alert-result')), findsOneWidget);
    expect(find.textContaining('LIVE-Ankaufgewinn +7 €'), findsOneWidget);
    expect(find.textContaining('LIVE-Ankauf vorher: 4 € Gewinn'), findsOneWidget);
    expect(find.textContaining('Privat vorher'), findsNothing);
  });

  testWidgets('LIVE buyback crossing from loss to profit is explicit',
      (tester) async {
    final store = _FixedAlertStore(DealAlertPreference.defaults('flip-1'));
    await tester.pumpWidget(_host(DealAlertResultCard(
      flipId: 'flip-1',
      english: false,
      previousProfit: 0,
      currentProfit: 0,
      previousRoi: 0,
      currentRoi: 0,
      hasPrivateComparison: false,
      previousBuybackProfit: -4,
      currentBuybackProfit: 2,
      verifiedBuybackComparison: true,
      store: store,
    )));
    await tester.pump();

    expect(find.textContaining('LIVE-Ankauf jetzt profitabel'), findsOneWidget);
    expect(find.textContaining('LIVE-Ankauf vorher: 4 € Verlust'), findsOneWidget);
    expect(find.textContaining('LIVE-Ankauf jetzt: 2 € Gewinn'), findsOneWidget);
  });

  testWidgets('unverified manual buyback improvement stays silent',
      (tester) async {
    final store = _FixedAlertStore(DealAlertPreference.defaults('flip-1'));
    await tester.pumpWidget(_host(DealAlertResultCard(
      flipId: 'flip-1',
      english: false,
      previousProfit: 0,
      currentProfit: 0,
      previousRoi: 0,
      currentRoi: 0,
      hasPrivateComparison: false,
      previousBuybackProfit: 4,
      currentBuybackProfit: 50,
      verifiedBuybackComparison: false,
      store: store,
    )));
    await tester.pump();

    expect(find.byKey(const ValueKey('v153-deal-alert-result')), findsNothing);
  });
}
