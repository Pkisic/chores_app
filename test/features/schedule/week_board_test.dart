import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chores/models/models.dart';
import 'package:chores/features/schedule/state/week_board.dart';

const week = '2026-W43';
final t0 = DateTime(2026, 10, 19, 10);

Chore chore(String id, String name) => Chore(
      id: id,
      name: name,
      color: '#FF6B6B',
      icon: 'clean',
      durationEstimate: 30,
    );

Member member(String id) =>
    Member(id: id, displayName: id.toUpperCase(), joinedAt: Timestamp.now());

TimeLog log({
  required String itemId,
  required String personId,
  int? seconds,
  DateTime? startedAt,
  String weekId = week,
}) {
  final start = startedAt ?? t0;
  return TimeLog(
    id: '${itemId}_${personId}_${start.millisecondsSinceEpoch}_$seconds',
    itemId: itemId,
    weekId: weekId,
    scheduleId: itemId.split('_')[1],
    day: int.parse(itemId.split('_')[2]),
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

WeekBoard board({
  List<ChoreSchedule>? schedules,
  List<Chore>? chores,
  List<WeekItem> items = const [],
  List<TimeLog> logs = const [],
}) {
  return buildWeekBoard(
    weekId: week,
    schedules: schedules ??
        const [
          ChoreSchedule(
              id: 's1', choreId: 'c1', personId: 'ana', days: [1, 3], recurring: true),
        ],
    chores: chores ?? [chore('c1', 'Vacuum')],
    members: [member('ana'), member('bob')],
    items: items,
    logs: logs,
  );
}

void main() {
  test('recurring entries appear on each of their days', () {
    final b = board();
    expect(b.days[1]!.single.slot.itemId, '${week}_s1_1');
    expect(b.days[3]!.single.slot.itemId, '${week}_s1_3');
    expect(b.days[2], isEmpty);
    expect(b.isEmpty, isFalse);
  });

  test('one-off entries only appear in their own week', () {
    final b = board(schedules: const [
      ChoreSchedule(
          id: 'here', choreId: 'c1', personId: 'ana', days: [2], recurring: false, weekId: week),
      ChoreSchedule(
          id: 'other', choreId: 'c1', personId: 'ana', days: [2], recurring: false, weekId: '2026-W44'),
    ]);
    expect(b.days[2]!.map((v) => v.schedule.id), ['here']);
  });

  test('entries for missing chores are skipped', () {
    final b = board(chores: const []);
    expect(b.isEmpty, isTrue);
  });

  test('sums closed logs per item and per person; running kept apart', () {
    final id = '${week}_s1_1';
    final b = board(logs: [
      log(itemId: id, personId: 'ana', seconds: 600),
      log(itemId: id, personId: 'bob', seconds: 300),
      log(itemId: id, personId: 'ana', seconds: 60),
      log(itemId: id, personId: 'bob'), // running
      log(itemId: '${week}_s1_3', personId: 'ana', seconds: 999),
      log(itemId: id, personId: 'ana', seconds: 5000, weekId: '2026-W42'),
    ]);

    final view = b.days[1]!.single;
    expect(view.loggedSeconds, 960);
    expect(view.secondsByPerson, {'ana': 660, 'bob': 300});
    expect(view.runningLogs.map((l) => l.personId), ['bob']);
    expect(view.isRunningFor('bob'), isTrue);
    expect(view.isRunningFor('ana'), isFalse);
    expect(view.runningByOthers('ana'), hasLength(1));
    expect(view.elapsedAt(t0.add(const Duration(seconds: 40))), 1000);
  });

  test('status comes from the week item; default is open', () {
    final b = board(items: [
      WeekItem(
        id: '${week}_s1_3',
        weekId: week,
        scheduleId: 's1',
        choreId: 'c1',
        day: 3,
        assignedPersonId: 'ana',
        status: WeekItemStatus.done,
        completedBy: 'bob',
      ),
    ]);
    expect(b.days[1]!.single.isDone, isFalse);
    final done = b.days[3]!.single;
    expect(done.isDone, isTrue);
    expect(b.nameOf(done.completedBy), 'BOB');
  });

  test('items within a day are sorted by chore name', () {
    final b = board(
      chores: [chore('c1', 'Vacuum'), chore('c2', 'Dishes')],
      schedules: const [
        ChoreSchedule(id: 's1', choreId: 'c1', personId: 'ana', days: [1], recurring: true),
        ChoreSchedule(id: 's2', choreId: 'c2', personId: 'bob', days: [1], recurring: true),
      ],
    );
    expect(b.days[1]!.map((v) => v.chore.name), ['Dishes', 'Vacuum']);
  });
}
