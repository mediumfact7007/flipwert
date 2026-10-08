import 'package:flipwert/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpStartup(WidgetTester tester) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    final onboardingReady =
        find.byKey(const ValueKey('v13-onboarding')).evaluate().isNotEmpty;
    final searchReady = find
        .byKey(const ValueKey('v13-universal-search'))
        .evaluate()
        .isNotEmpty;
    if (onboardingReady || searchReady) return;
  }
}

void main() {
  testWidgets('fresh install completes onboarding before opening search',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const FlipwertV13App());
    await pumpStartup(tester);

    expect(find.byKey(const ValueKey('v13-onboarding')), findsOneWidget);
    expect(find.text('Kaufpreis eingeben.\nErgebnis verstehen.'), findsOneWidget);
    expect(find.byKey(const ValueKey('v13-universal-search')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('v13-onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('LIVE heißt wirklich aktuell.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('v13-onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('Links bleiben unter deiner Kontrolle.'), findsOneWidget);
    expect(find.text('FLIPWERT STARTEN'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('v13-onboarding-next')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('v13-onboarding')), findsNothing);
    expect(find.byKey(const ValueKey('v13-universal-search')), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_v13_complete'), isTrue);
  });

  test('completed onboarding marker remains distinct from migrated user data',
      () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_v13_complete': true,
    });

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_v13_complete'), isTrue);
    expect(v13HasExistingUserState(prefs), isFalse);
  });

  test('existing local state is detected for onboarding migration', () async {
    SharedPreferences.setMockInitialValues({
      'history_v10': <String>['iPhone 15 Pro'],
    });

    final prefs = await SharedPreferences.getInstance();
    expect(v13HasExistingUserState(prefs), isTrue);
  });
}
