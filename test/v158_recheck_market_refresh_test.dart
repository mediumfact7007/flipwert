import 'package:flipwert/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh market estimate replaces the saved recheck fallback', () {
    expect(
      v13ResolveExpectedSale(
        marketEstimate: 420,
        snapshotFallback: 350,
      ),
      420,
    );
  });

  test('explicit manual sale price still wins over the market', () {
    expect(
      v13ResolveExpectedSale(
        manualOverride: 390,
        marketEstimate: 420,
        snapshotFallback: 350,
      ),
      390,
    );
  });

  test('saved value remains a fallback when no market estimate exists', () {
    expect(
      v13ResolveExpectedSale(snapshotFallback: 350),
      350,
    );
  });

  test('invalid values never become a recheck basis', () {
    expect(
      v13ResolveExpectedSale(
        manualOverride: double.nan,
        marketEstimate: double.infinity,
        snapshotFallback: -1,
      ),
      isNull,
    );
  });
}
