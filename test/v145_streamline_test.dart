import 'package:flipwert/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'source_text.dart';

void main() {
  test('share listener stays behind first frame and source failures are retryable', () {
    final app = readLibDartSource();

    expect(app, contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(app, contains('Platform.isAndroid || Platform.isIOS'));
    expect(app, contains('if (shareSub != null) return;'));
    expect(app, contains('final Set<String> failed = {};'));
    expect(app, contains('void _retryFailed()'));
    expect(app, contains("ValueKey('v145-retry-sources')"));

    final shellStart = app.indexOf('class _V13ShellState');
    final listenStart = app.indexOf('void _listenShares()', shellStart);
    final initStart = app.indexOf('void initState()', shellStart);
    final initEnd = app.indexOf('void _listenShares()', initStart);
    final initSlice = app.substring(initStart, initEnd);
    expect(initSlice, contains('addPostFrameCallback'));
    expect(initSlice, contains('_listenShares()'));
    expect(listenStart, greaterThan(initStart));
  });

  testWidgets('home keeps pasted listing price and URL, clears quickly and opens flips', (tester) async {
    final monetization = V13Monetization(onProUnlocked: () {});
    String? submitted;
    var openedFlips = false;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: V13Home(
          english: false,
          plan: UserPlan.pro,
          history: const [],
          openFlips: 2,
          savedFlips: 0,
          staleSaved: 0,
          monetization: monetization,
          onSearch: (value) => submitted = value,
          onScan: () {},
          onSettings: () {},
          onOpenFlips: () => openedFlips = true,
          onOpenSaved: () {},
        ),
      ),
    ));

    const raw = 'Samsung Galaxy S25\n499 €\nhttps://www.ebay.de/itm/123456789';
    final field = find.byKey(const ValueKey('v13-universal-search'));
    await tester.enterText(field, raw);
    await tester.pump();

    expect(find.byKey(const ValueKey('v145-clear-search')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('v13-check-button')));
    await tester.pump();
    expect(submitted, isNotNull);
    expect(submitted, contains('499 €'));
    expect(submitted, contains('https://www.ebay.de/itm/123456789'));
    expect(normalizeV13Search(submitted!).detectedPrice, 499);

    final openFlips = find.byKey(const ValueKey('v145-open-flips'));
    await tester.ensureVisible(openFlips);
    await tester.pump();
    await tester.tap(openFlips);
    await tester.pump();
    expect(openedFlips, isTrue);

    await tester.ensureVisible(field);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('v145-clear-search')));
    await tester.pump();
    final input = tester.widget<TextField>(field);
    expect(input.controller?.text, isEmpty);

    monetization.dispose();
  });
}
