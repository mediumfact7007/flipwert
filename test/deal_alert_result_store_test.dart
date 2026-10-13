import 'package:flipwert/deal_alert.dart';
import 'package:flipwert/deal_alert_result_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DealAlertResult _result(
  String id, {
  required DateTime checkedAt,
  bool triggered = true,
}) =>
    DealAlertResult.fromEvaluation(
      flipId: id,
      checkedAt: checkedAt,
      evaluation: DealAlertEvaluation(
        triggered: triggered,
        profitIncrease: triggered ? 15 : 2,
        roiIncrease: triggered ? 8 : 1,
        buybackProfitIncrease: 0,
        profitThresholdReached: triggered,
        roiThresholdReached: triggered,
        buybackProfitThresholdReached: false,
        becameProfitable: false,
        buybackBecameProfitable: false,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('latest manual recheck result survives a new store instance', () async {
    final checkedAt = DateTime(2026, 10, 13, 18);
    expect(await DealAlertResultStore().save(
      _result(' flip-1 ', checkedAt: checkedAt),
    ), isTrue);

    final loaded = await DealAlertResultStore().load();
    expect(loaded, hasLength(1));
    expect(loaded.single.flipId, 'flip-1');
    expect(loaded.single.triggered, isTrue);
    expect(loaded.single.profitIncrease, 15);
    expect(loaded.single.checkedAt, checkedAt);
  });

  test('older callback cannot replace a newer recheck result', () async {
    final store = DealAlertResultStore();
    final newer = DateTime(2026, 10, 13, 18);
    await store.save(_result('flip-1', checkedAt: newer));
    await store.save(_result(
      'flip-1',
      checkedAt: newer.subtract(const Duration(minutes: 1)),
      triggered: false,
    ));

    final loaded = await store.load();
    expect(loaded.single.checkedAt, newer);
    expect(loaded.single.triggered, isTrue);
  });

  test('retention removes results for deleted deals', () async {
    final store = DealAlertResultStore();
    await store.save(_result(
      'keep',
      checkedAt: DateTime(2026, 10, 13, 18),
    ));
    await store.save(_result(
      'remove',
      checkedAt: DateTime(2026, 10, 13, 19),
    ));

    expect(await store.retainOnly(['keep']), isTrue);
    expect((await store.load()).map((item) => item.flipId), ['keep']);
    expect(await store.remove('keep'), isTrue);
    expect(await store.load(), isEmpty);
  });
}
