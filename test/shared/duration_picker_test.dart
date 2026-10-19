import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chores/shared/duration_picker.dart';

void main() {
  Future<int Function()> pump(WidgetTester tester, int initial, {int? max}) async {
    var value = initial;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => DurationPicker(
            seconds: value,
            max: max ?? 24 * 3600 - 1,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    ));
    return () => value;
  }

  // Up arrows are [h, m, s] left to right; same for down arrows.
  Finder up(int i) => find.byIcon(Icons.keyboard_arrow_up).at(i);
  Finder down(int i) => find.byIcon(Icons.keyboard_arrow_down).at(i);

  testWidgets('each column steps its own unit', (tester) async {
    final value = await pump(tester, 0);
    // Pump after each tap: the picker is controlled, like real taps that
    // each get a frame.
    for (final i in [0, 1, 2]) {
      await tester.tap(up(i));
      await tester.pump();
    }
    expect(value(), 3600 + 60 + 1);
    expect(find.text('01'), findsNWidgets(3));
  });

  testWidgets('stepping carries across units and clamps at 0', (tester) async {
    final value = await pump(tester, 60);
    await tester.tap(down(2)); // 60s - 1s = 59s
    await tester.pump();
    expect(value(), 59);

    await tester.tap(down(1)); // would go negative → clamped
    await tester.pump();
    expect(value(), 0);
  });

  testWidgets('respects max', (tester) async {
    final value = await pump(tester, 100, max: 120);
    await tester.tap(up(1));
    await tester.pump();
    expect(value(), 120);
  });
}
