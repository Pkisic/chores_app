import 'package:flutter_test/flutter_test.dart';
import 'package:chores/features/schedule/views/widgets/session_editing.dart';

void main() {
  const current = 80 * 60 + 30; // 1h 20m 30s

  test('set replaces the duration', () {
    expect(applyDurationEdit(DurationEditMode.set, current, 45), 45);
  });

  test('subtract and add work to the second', () {
    expect(applyDurationEdit(DurationEditMode.subtract, current, 20), current - 20);
    expect(applyDurationEdit(DurationEditMode.add, current, 90), current + 90);
  });

  test('a 40s session can be trimmed by seconds', () {
    expect(applyDurationEdit(DurationEditMode.subtract, 40, 15), 25);
  });

  test('results at or below zero are rejected', () {
    expect(applyDurationEdit(DurationEditMode.subtract, 40, 40), isNull);
    expect(applyDurationEdit(DurationEditMode.subtract, 40, 60), isNull);
    expect(applyDurationEdit(DurationEditMode.set, current, 0), isNull);
  });
}
