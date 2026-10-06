import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_text.dart';

void main() {
  test('V0.14.2 preserves the V0.14.1 extra-cost label clipping fix', () {
    final app = readLibDartSource();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 0.14.2+25'));
    expect(app, contains("v0141-cost-label-top-space"));
    expect(app, contains("v0141-extra-costs-input"));

    final spacer = app.indexOf("v0141-cost-label-top-space");
    final field = app.indexOf("v0141-extra-costs-input");
    final label = app.indexOf("labelText: t('Zusatzkosten gesamt', 'Extra costs total')");

    expect(spacer, greaterThanOrEqualTo(0));
    expect(field, greaterThan(spacer));
    expect(label, greaterThan(field));
    expect(field - spacer, lessThan(300));
  });
}
