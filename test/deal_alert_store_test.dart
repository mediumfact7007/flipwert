import 'package:flipwert/deal_alert.dart';
import 'package:flipwert/deal_alert_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('concurrent saves from separate cards preserve every preference', () async {
    final firstStore = DealAlertStore();
    final secondStore = DealAlertStore();
    final first = DealAlertPreference.defaults(
      'flip-1',
      now: DateTime.utc(2026, 9, 18, 10),
    );
    final second = DealAlertPreference.defaults(
      'flip-2',
      now: DateTime.utc(2026, 9, 18, 10, 1),
    );

    final results = await Future.wait(<Future<bool>>[
      firstStore.save(first),
      secondStore.save(second),
    ]);

    expect(results, everyElement(isTrue));
    final loaded = await DealAlertStore().load();
    expect(loaded.map((item) => item.flipId).toSet(), {'flip-1', 'flip-2'});
  });

  test('concurrent remove and save do not resurrect the removed deal', () async {
    final store = DealAlertStore();
    expect(await store.save(DealAlertPreference.defaults('flip-old')), isTrue);

    final results = await Future.wait(<Future<bool>>[
      DealAlertStore().remove('flip-old'),
      DealAlertStore().save(DealAlertPreference.defaults('flip-new')),
    ]);

    expect(results, everyElement(isTrue));
    final loaded = await DealAlertStore().load();
    expect(loaded.map((item) => item.flipId), contains('flip-new'));
    expect(loaded.map((item) => item.flipId), isNot(contains('flip-old')));
  });

  test('save canonicalizes whitespace before replacing an existing alert', () async {
    final store = DealAlertStore();
    expect(
      await store.save(
        DealAlertPreference.defaults(
          'flip-1',
          now: DateTime.utc(2026, 9, 21, 7),
        ),
      ),
      isTrue,
    );

    final updated = DealAlertPreference(
      flipId: '  flip-1  ',
      enabled: false,
      minProfitIncrease: 9,
      minBuybackProfitIncrease: 11,
      minRoiIncrease: 7,
      updatedAt: DateTime.utc(2026, 9, 21, 8),
    );
    expect(await store.save(updated), isTrue);

    final loaded = await store.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.flipId, 'flip-1');
    expect(loaded.single.enabled, isFalse);
    expect(loaded.single.minProfitIncrease, 9);
    expect(loaded.single.minBuybackProfitIncrease, 11);
    expect(loaded.single.minRoiIncrease, 7);
  });

  test('save rejects an empty canonical alert key', () async {
    final store = DealAlertStore();
    final invalid = DealAlertPreference.defaults('   ');

    expect(await store.save(invalid), isFalse);
    expect(await store.load(), isEmpty);
  });

  test('stale save cannot roll back a newer alert preference', () async {
    final store = DealAlertStore();
    final newer = DealAlertPreference(
      flipId: 'flip-1',
      enabled: false,
      minProfitIncrease: 12,
      minRoiIncrease: 8,
      updatedAt: DateTime.utc(2026, 9, 21, 10),
    );
    final stale = DealAlertPreference(
      flipId: 'flip-1',
      enabled: true,
      minProfitIncrease: 5,
      minRoiIncrease: 5,
      updatedAt: DateTime.utc(2026, 9, 21, 9),
    );

    expect(await store.save(newer), isTrue);
    expect(await DealAlertStore().save(stale), isTrue);

    final loaded = await store.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.enabled, isFalse);
    expect(loaded.single.minProfitIncrease, 12);
    expect(loaded.single.minRoiIncrease, 8);
    expect(loaded.single.updatedAt, newer.updatedAt.toLocal());
  });

  test('equal timestamp cannot make callback order change alert preference', () async {
    final store = DealAlertStore();
    final revision = DateTime.utc(2026, 9, 21, 10, 30);
    final first = DealAlertPreference(
      flipId: 'flip-1',
      enabled: false,
      minProfitIncrease: 10,
      minRoiIncrease: 10,
      updatedAt: revision,
    );
    final conflicting = DealAlertPreference(
      flipId: 'flip-1',
      enabled: true,
      minProfitIncrease: 2,
      minRoiIncrease: 2,
      updatedAt: revision,
    );

    expect(await store.save(first), isTrue);
    expect(await DealAlertStore().save(conflicting), isTrue);

    final loaded = await store.load();
    expect(loaded, hasLength(1));
    expect(loaded.single.enabled, isFalse);
    expect(loaded.single.minProfitIncrease, 10);
    expect(loaded.single.minRoiIncrease, 10);
  });

  test('retainOnly removes orphaned and completed deal alerts', () async {
    final store = DealAlertStore();
    expect(await store.save(DealAlertPreference.defaults('saved-1')), isTrue);
    expect(await store.save(DealAlertPreference.defaults('archived-1')), isTrue);
    expect(await store.save(DealAlertPreference.defaults('deleted-1')), isTrue);
    expect(await store.save(DealAlertPreference.defaults('bought-1')), isTrue);

    expect(
      await store.retainOnly([' saved-1 ', 'archived-1', '', '   ']),
      isTrue,
    );

    final loaded = await store.load();
    expect(
      loaded.map((item) => item.flipId).toSet(),
      {'saved-1', 'archived-1'},
    );
  });

  test('retainOnly clears storage when no alert-eligible deals remain',
      () async {
    final store = DealAlertStore();
    expect(await store.save(DealAlertPreference.defaults('deleted-1')), isTrue);

    expect(await store.retainOnly(const []), isTrue);
    expect(await store.load(), isEmpty);
  });
}
