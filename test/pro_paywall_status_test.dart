import 'package:flipwert/main.dart';
import 'package:flipwert/pro_entitlement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMonetization extends V13Monetization {
  _FakeMonetization() : super(onProUnlocked: () {});

  int preparePaywallCalls = 0;

  @override
  Future<void> preparePaywall() async {
    preparePaywallCalls += 1;
  }

  @override
  Future<void> restore() async {
    billingStage = V13BillingStage.restoreRequested;
    notifyListeners();
  }
}

void main() {
  testWidgets('paywall starts one lazy existing-purchase check', (tester) async {
    final monetization = _FakeMonetization();

    await tester.pumpWidget(MaterialApp(
      home: V13Paywall(english: false, monetization: monetization),
    ));
    await tester.pump();

    expect(monetization.preparePaywallCalls, 1);
    monetization.dispose();
  });

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

  testWidgets('paywall shows the verified plan and expiry', (tester) async {
    final monetization = _FakeMonetization()
      ..billingStage = V13BillingStage.verified
      ..verifiedEntitlement = ProEntitlementResult.verified(
        productId: V13Monetization.yearlyId,
        expiresAt: DateTime.parse('2027-10-14T00:00:00Z'),
      );

    await tester.pumpWidget(MaterialApp(
      home: V13Paywall(english: false, monetization: monetization),
    ));
    await tester.pump();

    expect(find.textContaining('Jahrestarif'), findsOneWidget);
    expect(find.textContaining('14.10.2027'), findsOneWidget);
    monetization.dispose();
  });

  testWidgets('paywall keeps temporary verification outages distinct',
      (tester) async {
    final monetization = _FakeMonetization()
      ..billingStage = V13BillingStage.verificationUnavailable;

    await tester.pumpWidget(MaterialApp(
      home: V13Paywall(english: false, monetization: monetization),
    ));
    await tester.pump();

    expect(find.textContaining('vorübergehend nicht erreichbar'), findsOneWidget);
    expect(find.textContaining('PRO bleibt unverändert'), findsOneWidget);
    monetization.dispose();
  });
}
