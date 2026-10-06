import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_text.dart';

void main() {
  test('billing remains lazy and isolated from normal app startup', () {
    final app = readLibDartSource();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('in_app_purchase: ^3.3.0'));
    expect(app, contains("package:in_app_purchase/in_app_purchase.dart"));
    expect(app, contains('Billing is initialized lazily by V13Paywall only.'));
    expect(app, contains('unawaited(widget.monetization.init());'));
    expect(app, isNot(contains('  void _scheduleBillingInit() {')));

    final appStateStart = app.indexOf('class _FlipwertV13AppState');
    final homeStart = app.indexOf('class V13Home extends StatefulWidget');
    final startupSlice = app.substring(appStateStart, homeStart);
    expect(startupSlice, isNot(contains('monetization.init()')));
  });
}
