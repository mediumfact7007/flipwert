import 'package:flipwert/v13_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('local data deletion requires explicit confirmation',
      (tester) async {
    var deletions = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: V13PrivacyPage(
          english: false,
          onDeleteAllLocalData: () async {
            deletions += 1;
            return false;
          },
        ),
      ),
    );

    final deleteButton = find.byKey(const ValueKey('v13-delete-local-data'));
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('Lokale Daten löschen?'), findsOneWidget);
    expect(deletions, 0);

    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(deletions, 0);

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('v13-confirm-delete-local-data')),
    );
    await tester.pumpAndSettle();
    expect(deletions, 1);
  });

  testWidgets('deleting app data clears preferences and returns to onboarding',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarding_v13_complete': true,
      'english_v13': false,
      'history_v13': <String>['iPhone 15 Pro'],
      'flips_v13': <String>[],
      'custom_sources_v05': <String>['custom source'],
      'enabled_sources_v05': <String>['ebay'],
      'deal_alert_preferences_v1': '[]',
    });

    await tester.pumpWidget(const FlipwertV13App());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('v13-onboarding')), findsNothing);

    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    final privacyEntry = find.byKey(const ValueKey('v13-data-privacy-entry'));
    await tester.scrollUntilVisible(privacyEntry, 300);
    await tester.tap(privacyEntry);
    await tester.pumpAndSettle();
    final deleteButton = find.byKey(const ValueKey('v13-delete-local-data'));
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('v13-confirm-delete-local-data')),
    );
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), isEmpty);
    expect(find.byKey(const ValueKey('v13-onboarding')), findsOneWidget);
  });
}
