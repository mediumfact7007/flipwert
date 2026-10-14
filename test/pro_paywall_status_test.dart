import 'package:flipwert/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMonetization extends V13Monetization {
  _FakeMonetization() : super(onProUnlocked: () {});

  @override
  Future<void> init() async {}

  @override
  Future<void> restore() async {
    billingStage = V13BillingStage.restoreRequested;
    notifyListeners();
  }
}

void main() {
  testWidgets('paywall explains failed server verification', (tester) async {
    final monetization = _FakeMonetization()
      ..billingStage = V13BillingStage.verificationFailed;

    await tester.pumpWidget(MaterialApp(
      home: V13Paywall(english: false, monetization: monetization),
    ));
    await tester.pump();

    expect(find.byKey(const ValueKey('pro-billing-status')), findsOneWidget);
    expect(find.textContaining('nicht als aktive PRO-Berechtigung bestätigt'),
        findsOneWidget);
    monetization.dispose();
  });

  testWidgets('restore action confirms secure verification is pending',
      (tester) async {
    final monetization = _FakeMonetization()..billingAvailable = true;

    await tester.pumpWidget(MaterialApp(
      home: V13Paywall(english: false, monetization: monetization),
    ));
    await tester.pump();
    await tester.tap(find.text('Käufe wiederherstellen'));
    await tester.pump();

    expect(find.textContaining('Wiederherstellung angefordert'), findsOneWidget);
    expect(find.textContaining('serverseitig geprüft'), findsOneWidget);
    monetization.dispose();
  });
}
