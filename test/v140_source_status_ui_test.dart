import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_text.dart';

void main() {
  test('V0.14 wires live source status into price sources page', () {
    final app = readLibDartSource();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('version: 0.14.0+23'));
    expect(app, contains("import 'source_status.dart';"));
    expect(app, contains('MarketBackendStatus? runtimeStatus;'));
    expect(app, contains('MarketStatusClient.fetch(items)'));
    expect(app, contains("'Browser-Suche'"));
    expect(app, contains("'Noch nicht verbunden'"));
    expect(app, contains("'Live-Marktdaten sind vorbereitet; nicht konfigurierte Quellen liefern keine Preise.'"));
    expect(app, contains("'Sofort-Ankauf: Anbieterrechte bestätigt, Feed-Validierung noch ausstehend.'"));
  });
}
