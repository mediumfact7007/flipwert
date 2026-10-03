import 'dart:io';

import 'package:flipwert/main.dart';
import 'package:flipwert/source_registry.dart';
import 'package:flutter_test/flutter_test.dart';

SourceListing comp(
  double price, {
  String source = 'ebay_de',
  bool live = true,
  String title = 'Test listing',
}) =>
    SourceListing(
      sourceId: source,
      sourceName: source,
      role: 'resale',
      title: title,
      price: price,
      shipping: 0,
      url: 'https://example.test/item',
      condition: 'USED',
      live: live,
    );

void main() {
  test('Sandbox/reference data never creates market confidence', () {
    final result = v13MarketConfidence([
      comp(600, live: false),
      comp(620, live: false),
      comp(640, live: false),
    ]);
    expect(result.score, 0);
    expect(result.hasLiveData, isFalse);
    expect(result.label(false), 'Keine Live-Daten');
  });

  test('manual sale price is clearly separated from automatic confidence', () {
    final result = v13MarketConfidence(const <SourceListing>[], manualOverride: true);
    expect(result.manual, isTrue);
    expect(result.label(false), 'Manuell');
  });

  test('many consistent LIVE comps across sources earn very high confidence', () {
    final values = <SourceListing>[];
    for (var i = 0; i < 12; i++) {
      values.add(comp(590 + i * 5.0, source: i.isEven ? 'ebay_de' : 'partner_live'));
    }
    final result = v13MarketConfidence(values);
    expect(result.liveCount, 12);
    expect(result.sourceCount, 2);
    expect(result.score, greaterThanOrEqualTo(85));
    expect(result.label(false), 'Sehr hoch');
  });

  test('one good LIVE source can be high but not very high', () {
    final result = v13MarketConfidence([
      comp(590),
      comp(600),
      comp(610),
      comp(620),
      comp(630),
    ]);
    expect(result.score, inInclusiveRange(70, 84));
    expect(result.label(false), 'Hoch');
  });

  test('removed price outlier is visible in confidence metadata', () {
    final result = v13MarketConfidence([
      comp(24.99),
      comp(599),
      comp(620),
      comp(630),
      comp(650),
      comp(680),
    ]);
    expect(result.liveCount, 5);
    expect(result.removedOutliers, 1);
  });

  test('wrong eBay variants do not inflate market confidence', () {
    final result = v13MarketConfidence(
      [
        comp(800, title: 'Apple iPhone 15 Pro 256GB Weiß'),
        comp(1000, title: 'Apple iPhone 15 Pro Max 256GB'),
        comp(700, title: 'Apple iPhone 15 Pro 128GB'),
      ],
      query: 'Apple iPhone 15 Pro 256 GB',
    );

    expect(result.liveCount, 1);
    expect(result.sourceCount, 1);
    expect(result.score, lessThan(45));
  });

  test('small widely spread sample stays low confidence', () {
    final result = v13MarketConfidence([
      comp(500),
      comp(900),
      comp(1300),
    ]);
    expect(result.score, lessThan(45));
    expect(result.label(false), 'Niedrig');
  });

  test('deal decision stays before detailed confidence UI', () {
    final app = File('lib/v13_app.dart').readAsStringSync();
    final buildStart = app.indexOf('class _V13CheckPageState');
    final buildEnd = app.indexOf('  void _commitManual()', buildStart);
    final flow = app.substring(buildStart, buildEnd);
    final decision = flow.indexOf('_V13DecisionCard(');
    final confidence = flow.indexOf('_V14ConfidenceCard(english:');
    expect(decision, greaterThanOrEqualTo(0));
    expect(confidence, greaterThan(decision));
  });
}
