/// ISO 8601 week helpers. Weeks run Monday–Sunday and are identified as
/// `YYYY-Www` (e.g. `2026-W43`). Days are ISO ints: 1=Monday … 7=Sunday.
///
/// All arithmetic is done on calendar dates (`DateTime(y, m, d + n)`) rather
/// than `Duration`s so DST changes never shift a date.
class WeekId {
  WeekId._();

  /// The ISO week id the given date falls in.
  static String of(DateTime date) {
    // The ISO week belongs to the year of its Thursday.
    final thursday = DateTime(date.year, date.month, date.day + 4 - date.weekday);
    final dayOfYear =
        DateTime.utc(thursday.year, thursday.month, thursday.day)
                .difference(DateTime.utc(thursday.year, 1, 1))
                .inDays +
            1;
    final week = (dayOfYear - 1) ~/ 7 + 1;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  /// Local midnight of the Monday starting [weekId].
  static DateTime startOf(String weekId) {
    final (year, week) = _parse(weekId);
    // 4 January is always in week 1.
    final jan4 = DateTime(year, 1, 4);
    return DateTime(year, 1, 4 - (jan4.weekday - 1) + (week - 1) * 7);
  }

  /// Local midnight of [day] (1=Mon … 7=Sun) within [weekId].
  static DateTime dateOf(String weekId, int day) {
    final start = startOf(weekId);
    return DateTime(start.year, start.month, start.day + day - 1);
  }

  /// The week id [weeks] weeks before (negative) or after (positive) [weekId].
  static String shift(String weekId, int weeks) {
    final start = startOf(weekId);
    return of(DateTime(start.year, start.month, start.day + weeks * 7));
  }

  /// Week number part of [weekId], e.g. 43 for `2026-W43`.
  static int number(String weekId) => _parse(weekId).$2;

  static (int, int) _parse(String weekId) {
    final parts = weekId.split('-W');
    if (parts.length != 2) {
      throw FormatException('Invalid ISO week id', weekId);
    }
    return (int.parse(parts[0]), int.parse(parts[1]));
  }
}
