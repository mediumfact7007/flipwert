import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_text.dart';

void main() {
  test('AdMob stays explicit and isolated from normal startup', () {
    final app = readLibDartSource();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('google_mobile_ads: ^9.1.0'));
    expect(app, contains("package:google_mobile_ads/google_mobile_ads.dart"));
    expect(app, contains('Future<bool> prepareAds() async'));
    expect(app, contains('MobileAds.instance.initialize()'));
    expect(app, contains('if (!await prepareAds()) return false;'));

    // Google sample IDs only in this recovery build; no publisher IDs yet.
    expect(app, contains('ca-app-pub-3940256099942544/6300978111'));
    expect(app, contains('ca-app-pub-3940256099942544/5224354917'));

    // No automatic Dart-side ad initialization during normal app startup.
    final appStateStart = app.indexOf('class _FlipwertV13AppState');
    final homeStart = app.indexOf('class V13Home extends StatefulWidget');
    final startupSlice = app.substring(appStateStart, homeStart);
    expect(startupSlice, isNot(contains('prepareAds()')));
    expect(startupSlice, isNot(contains('MobileAds.instance.initialize()')));

    // Banner surfaces intentionally remain inert until a later isolated step.
    expect(app, contains('class V13BannerAd extends StatelessWidget'));
    expect(app, contains('Widget build(BuildContext context) => const SizedBox.shrink();'));
  });
}
