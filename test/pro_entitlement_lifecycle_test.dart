import 'package:flipwert/main.dart';
import 'package:flipwert/pro_entitlement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verified PRO is revoked when its server expiry is reached', () async {
    var unlocked = 0;
    var locked = 0;
    final monetization = V13Monetization(
      onProUnlocked: () => unlocked += 1,
      onProLocked: () => locked += 1,
    );

    monetization.applyEntitlementResult(ProEntitlementResult.verified(
      productId: V13Monetization.monthlyId,
      expiresAt: DateTime.now().toUtc().add(const Duration(milliseconds: 40)),
    ));
    expect(unlocked, 1);
    expect(monetization.verifiedEntitlement, isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(locked, 1);
    expect(monetization.verifiedEntitlement, isNull);
    expect(monetization.billingStage, V13BillingStage.expired);
    monetization.dispose();
  });

  test('temporary outage preserves PRO but matching rejection revokes it', () {
    var locked = 0;
    final monetization = V13Monetization(
      onProUnlocked: () {},
      onProLocked: () => locked += 1,
    );
    monetization.applyEntitlementResult(ProEntitlementResult.verified(
      productId: V13Monetization.yearlyId,
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
    ));

    monetization.applyEntitlementResult(
      const ProEntitlementResult.unavailable(),
      checkedProductId: V13Monetization.yearlyId,
    );
    expect(locked, 0);
    expect(monetization.verifiedEntitlement, isNotNull);

    monetization.applyEntitlementResult(
      const ProEntitlementResult.rejected(),
      checkedProductId: V13Monetization.yearlyId,
    );
    expect(locked, 1);
    expect(monetization.verifiedEntitlement, isNull);
    monetization.dispose();
  });

  test('rejected old product does not revoke a different active plan', () {
    var locked = 0;
    final monetization = V13Monetization(
      onProUnlocked: () {},
      onProLocked: () => locked += 1,
    );
    monetization.applyEntitlementResult(ProEntitlementResult.verified(
      productId: V13Monetization.yearlyId,
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
    ));

    monetization.applyEntitlementResult(
      const ProEntitlementResult.rejected(),
      checkedProductId: V13Monetization.monthlyId,
    );
    expect(locked, 0);
    expect(monetization.verifiedEntitlement?.productId,
        V13Monetization.yearlyId);
    monetization.dispose();
  });

  test('a shorter verified purchase cannot replace a longer entitlement', () {
    final monetization = V13Monetization(onProUnlocked: () {});
    final longerExpiry = DateTime.now().toUtc().add(const Duration(days: 90));
    monetization.applyEntitlementResult(ProEntitlementResult.verified(
      productId: V13Monetization.yearlyId,
      expiresAt: longerExpiry,
    ));

    monetization.applyEntitlementResult(ProEntitlementResult.verified(
      productId: V13Monetization.monthlyId,
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
    ));

    expect(monetization.verifiedEntitlement?.productId,
        V13Monetization.yearlyId);
    expect(monetization.verifiedEntitlement?.expiresAt, longerExpiry);
    monetization.dispose();
  });
}
