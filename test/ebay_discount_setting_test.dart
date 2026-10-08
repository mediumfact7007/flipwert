import 'package:flipwert/source_registry.dart';
import 'package:flipwert/scanner_page.dart';
import 'package:flipwert/v13_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('eBay base discount is visible and adjustable', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    double? changed;

    await tester.pumpWidget(MaterialApp(
      home: V13SettingsPage(
        english: false,
        backend: '',
        targetRoi: 35,
        minProfit: 20,
        ebayDiscount: .15,
        plan: UserPlan.free,
        taxMode: V13TaxMode.privateSeller,
        sources: SourceRegistry.builtIns(),
        monetization: monetization,
        onLanguage: (_) {},
        onRoi: (_) {},
        onMinProfit: (_) {},
        onEbayDiscount: (value) => changed = value,
        onTaxMode: (_) {},
        onBackend: (_) {},
        onSources: (_) {},
        onPlanPreview: (_) {},
        onDeleteAllLocalData: () async => true,
      ),
    ));

    expect(find.text('eBay-Angebotsabschlag'), findsOneWidget);
    expect(find.text('15 %'), findsOneWidget);
    final slider = find.byKey(const ValueKey('ebay-discount-slider'));
    expect(slider, findsOneWidget);

    await tester.drag(slider, const Offset(120, 0));
    await tester.pump();
    expect(changed, isNotNull);
    expect(changed!, greaterThan(.15));

    monetization.dispose();
  });
}
