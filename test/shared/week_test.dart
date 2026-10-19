import 'package:flutter_test/flutter_test.dart';
import 'package:chores/shared/week.dart';

void main() {
  group('WeekId.of', () {
    test('mid-year dates', () {
      expect(WeekId.of(DateTime(2026, 10, 19)), '2026-W43'); // Monday
      expect(WeekId.of(DateTime(2026, 10, 25, 23, 59)), '2026-W43'); // Sunday
      expect(WeekId.of(DateTime(2026, 10, 26)), '2026-W44');
    });

    test('year boundaries follow the Thursday rule', () {
      expect(WeekId.of(DateTime(2026, 1, 1)), '2026-W01');
      expect(WeekId.of(DateTime(2025, 12, 29)), '2026-W01');
      expect(WeekId.of(DateTime(2026, 12, 31)), '2026-W53');
      expect(WeekId.of(DateTime(2027, 1, 3)), '2026-W53');
      expect(WeekId.of(DateTime(2027, 1, 4)), '2027-W01');
      expect(WeekId.of(DateTime(2024, 12, 30)), '2025-W01');
    });
  });

  group('WeekId.startOf / dateOf', () {
    test('returns the Monday of the week', () {
      expect(WeekId.startOf('2026-W43'), DateTime(2026, 10, 19));
      expect(WeekId.startOf('2026-W01'), DateTime(2025, 12, 29));
      expect(WeekId.startOf('2027-W01'), DateTime(2027, 1, 4));
    });

    test('dateOf maps ISO days within the week', () {
      expect(WeekId.dateOf('2026-W43', 1), DateTime(2026, 10, 19));
      expect(WeekId.dateOf('2026-W43', 7), DateTime(2026, 10, 25));
    });

    test('round-trips for every week of several years', () {
      var date = DateTime(2024, 1, 1);
      while (date.year < 2029) {
        final id = WeekId.of(date);
        expect(WeekId.of(WeekId.startOf(id)), id);
        date = DateTime(date.year, date.month, date.day + 7);
      }
    });
  });

  group('WeekId.shift', () {
    test('moves across year boundaries', () {
      expect(WeekId.shift('2026-W53', 1), '2027-W01');
      expect(WeekId.shift('2027-W01', -1), '2026-W53');
      expect(WeekId.shift('2026-W43', 0), '2026-W43');
    });
  });

  test('number and invalid ids', () {
    expect(WeekId.number('2026-W07'), 7);
    expect(() => WeekId.startOf('2026-43'), throwsFormatException);
  });
}
