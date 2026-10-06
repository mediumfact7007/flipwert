import 'package:flutter_test/flutter_test.dart';

import 'source_text.dart';

void main() {
  test('compact screen keeps breathing room below the target hint', () {
    final app = readLibDartSource();

    expect(app, contains("Ziel: ${r'${widget.targetRoi.toStringAsFixed(0)}'} % ROI + mindestens ${r'${v13Euro(widget.minProfit)}'} Gewinn."));

    final hint = app.indexOf("Ziel: ${r'${widget.targetRoi.toStringAsFixed(0)}'} % ROI");
    expect(hint, greaterThanOrEqualTo(0));
    final afterHint = app.substring(hint, (hint + 900).clamp(0, app.length));
    expect(afterHint, contains('const SizedBox(height: 14)'));
  });
}
