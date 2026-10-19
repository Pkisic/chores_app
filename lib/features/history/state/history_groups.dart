import 'package:chores/models/models.dart';
import 'package:chores/shared/week.dart';

/// All completed sessions of one item (chore × day × week).
class HistoryEntry {
  final String itemId;
  final String weekId;
  final int day;
  final String choreId;
  final List<TimeLog> sessions; // oldest first

  const HistoryEntry({
    required this.itemId,
    required this.weekId,
    required this.day,
    required this.choreId,
    required this.sessions,
  });

  /// Calendar date of the scheduled day.
  DateTime get date => WeekId.dateOf(weekId, day);

  int get totalSeconds =>
      sessions.fold(0, (sum, l) => sum + (l.durationSeconds ?? 0));

  Map<String, int> get secondsByPerson {
    final map = <String, int>{};
    for (final l in sessions) {
      map[l.personId] = (map[l.personId] ?? 0) + (l.durationSeconds ?? 0);
    }
    return map;
  }

  DateTime get lastActivity => sessions
      .map((l) => (l.endedAt ?? l.startedAt).toDate())
      .reduce((a, b) => a.isAfter(b) ? a : b);
}

/// Entries of one calendar day, most recent activity first.
class HistoryDay {
  final DateTime date;
  final List<HistoryEntry> entries;

  const HistoryDay({required this.date, required this.entries});
}

/// Groups completed logs by item, then items by their scheduled date
/// (newest day first). Running logs are ignored.
List<HistoryDay> groupHistory(List<TimeLog> logs) {
  final byItem = <String, List<TimeLog>>{};
  for (final log in logs) {
    if (log.isRunning) continue;
    byItem.putIfAbsent(log.itemId, () => []).add(log);
  }

  final byDate = <DateTime, List<HistoryEntry>>{};
  for (final sessions in byItem.values) {
    sessions.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final first = sessions.first;
    final entry = HistoryEntry(
      itemId: first.itemId,
      weekId: first.weekId,
      day: first.day,
      choreId: first.choreId,
      sessions: sessions,
    );
    byDate.putIfAbsent(entry.date, () => []).add(entry);
  }

  final days = byDate.entries
      .map((e) => HistoryDay(
            date: e.key,
            entries: e.value
              ..sort((a, b) => b.lastActivity.compareTo(a.lastActivity)),
          ))
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return days;
}
