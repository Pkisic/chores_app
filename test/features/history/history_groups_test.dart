import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chores/models/models.dart';
import 'package:chores/features/history/state/history_groups.dart';

TimeLog log(
  String itemId,
  String personId,
  DateTime start, {
  int? seconds,
}) {
  final parts = itemId.split('_');
  return TimeLog(
    id: '$itemId-$personId-${start.millisecondsSinceEpoch}',
    itemId: itemId,
    weekId: parts[0],
    scheduleId: parts[1],
    day: int.parse(parts[2]),
    choreId: 'c1',
    personId: personId,
    source: TimeLogSource.timer,
    startedAt: Timestamp.fromDate(start),
    endedAt: seconds == null
        ? null
        : Timestamp.fromDate(start.add(Duration(seconds: seconds))),
    durationSeconds: seconds,
  );
}

void main() {
  final mon = DateTime(2026, 10, 19, 9);

  test('groups sessions by item and items by scheduled date', () {
    final days = groupHistory([
      log('2026-W43_s1_1', 'ana', mon, seconds: 600),
      log('2026-W43_s1_1', 'bob', mon.add(const Duration(hours: 1)), seconds: 300),
      log('2026-W43_s1_1', 'ana', mon.add(const Duration(minutes: 30)), seconds: 60),
      log('2026-W43_s2_3', 'bob', mon, seconds: 120),
    ]);

    expect(days.map((d) => d.date),
        [DateTime(2026, 10, 21), DateTime(2026, 10, 19)]);

    final monday = days.last.entries.single;
    expect(monday.sessions, hasLength(3));
    expect(monday.sessions.first.durationSeconds, 600, reason: 'oldest first');
    expect(monday.totalSeconds, 960);
    expect(monday.secondsByPerson, {'ana': 660, 'bob': 300});
  });

  test('running sessions are left out', () {
    final days = groupHistory([log('2026-W43_s1_1', 'ana', mon)]);
    expect(days, isEmpty);
  });

  test('entries within a day are ordered by most recent activity', () {
    final days = groupHistory([
      log('2026-W43_s1_1', 'ana', mon, seconds: 60),
      log('2026-W43_s2_1', 'ana', mon.add(const Duration(hours: 2)), seconds: 60),
    ]);
    expect(days.single.entries.map((e) => e.itemId),
        ['2026-W43_s2_1', '2026-W43_s1_1']);
  });
}
