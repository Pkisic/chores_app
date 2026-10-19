import 'package:chores/models/models.dart';

/// Everything the Schedule page shows for one [ScheduleSlot] in a week,
/// derived from Firestore state (schedule + week item + time logs).
class ScheduleItemView {
  final ScheduleSlot slot;
  final ChoreSchedule schedule;
  final Chore chore;
  final WeekItemStatus status;
  final String? completedBy;

  /// Seconds from closed logs (timer sessions + manual entries).
  final int loggedSeconds;

  /// Closed-log seconds per member id.
  final Map<String, int> secondsByPerson;

  /// Sessions currently running on this item (any member).
  final List<TimeLog> runningLogs;

  /// Every session on this item (running and closed), oldest first.
  final List<TimeLog> logs;

  const ScheduleItemView({
    required this.slot,
    required this.schedule,
    required this.chore,
    required this.status,
    required this.completedBy,
    required this.loggedSeconds,
    required this.secondsByPerson,
    required this.runningLogs,
    required this.logs,
  });

  bool get isDone => status == WeekItemStatus.done;
  bool get isRunning => runningLogs.isNotEmpty;
  bool get hasTime => loggedSeconds > 0 || isRunning;

  bool isRunningFor(String? personId) =>
      personId != null && runningLogs.any((l) => l.personId == personId);

  /// Running sessions of members other than [personId].
  List<TimeLog> runningByOthers(String? personId) =>
      runningLogs.where((l) => l.personId != personId).toList();

  /// Total seconds including running sessions up to [now].
  int elapsedAt(DateTime now) =>
      runningLogs.fold(loggedSeconds, (sum, l) => sum + l.secondsAt(now));
}

/// One ISO week of the schedule, grouped by day (1=Mon … 7=Sun).
class WeekBoard {
  final String weekId;
  final Map<int, List<ScheduleItemView>> days;
  final Map<String, Member> members;

  const WeekBoard({
    required this.weekId,
    required this.days,
    required this.members,
  });

  String? nameOf(String? memberId) => members[memberId]?.displayName;

  bool get isEmpty => days.values.every((items) => items.isEmpty);
}

/// Combines raw Firestore data into a [WeekBoard]. Pure, so it is unit
/// tested without Firebase.
WeekBoard buildWeekBoard({
  required String weekId,
  required List<ChoreSchedule> schedules,
  required List<Chore> chores,
  required List<Member> members,
  required List<WeekItem> items,
  required List<TimeLog> logs,
}) {
  final choreMap = {for (final c in chores) c.id: c};
  final itemMap = {for (final i in items) i.id: i};
  final logsByItem = <String, List<TimeLog>>{};
  for (final log in logs) {
    if (log.weekId != weekId) continue;
    logsByItem.putIfAbsent(log.itemId, () => []).add(log);
  }

  final days = {for (var d = 1; d <= 7; d++) d: <ScheduleItemView>[]};
  for (final schedule in schedules) {
    if (!schedule.appliesTo(weekId)) continue;
    final chore = choreMap[schedule.choreId];
    if (chore == null) continue;

    for (final day in schedule.days) {
      if (!days.containsKey(day)) continue;
      final slot = ScheduleSlot(
        weekId: weekId,
        scheduleId: schedule.id,
        day: day,
        choreId: chore.id,
        assignedPersonId: schedule.personId,
      );
      final item = itemMap[slot.itemId];
      final itemLogs = logsByItem[slot.itemId] ?? const <TimeLog>[];

      var logged = 0;
      final byPerson = <String, int>{};
      final running = <TimeLog>[];
      for (final log in itemLogs) {
        if (log.isRunning) {
          running.add(log);
          continue;
        }
        final secs = log.durationSeconds ?? 0;
        logged += secs;
        byPerson[log.personId] = (byPerson[log.personId] ?? 0) + secs;
      }

      days[day]!.add(
        ScheduleItemView(
          slot: slot,
          schedule: schedule,
          chore: chore,
          status: item?.status ?? WeekItemStatus.open,
          completedBy: item?.completedBy,
          loggedSeconds: logged,
          secondsByPerson: byPerson,
          runningLogs: running,
          logs: [...itemLogs]
            ..sort((a, b) => a.startedAt.compareTo(b.startedAt)),
        ),
      );
    }
  }

  for (final dayItems in days.values) {
    dayItems.sort((a, b) => a.chore.name.compareTo(b.chore.name));
  }

  return WeekBoard(
    weekId: weekId,
    days: days,
    members: {for (final m in members) m.id: m},
  );
}
