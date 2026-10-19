import 'package:cloud_firestore/cloud_firestore.dart';

enum TimeLogSource { timer, manual }

/// One session of work on a scheduled item.
///
/// Timer logs are a single active session: opened on start/resume, closed on
/// pause/complete, so paused time is never counted. Manual logs are created
/// closed, with `started_at == ended_at` and an explicit duration.
class TimeLog {
  final String id;
  final String itemId;
  final String weekId;
  final String scheduleId;
  final int day;
  final String choreId;
  final String personId;
  final TimeLogSource source;
  final Timestamp startedAt;
  final Timestamp? endedAt;
  final int? durationSeconds;

  const TimeLog({
    required this.id,
    required this.itemId,
    required this.weekId,
    required this.scheduleId,
    required this.day,
    required this.choreId,
    required this.personId,
    required this.source,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
  });

  factory TimeLog.fromJson(Map<String, dynamic> json, String docId) {
    return TimeLog(
      id: docId,
      itemId: json['item_id'] as String,
      weekId: json['week_id'] as String,
      scheduleId: json['schedule_id'] as String,
      day: json['day'] as int,
      choreId: json['chore_id'] as String,
      personId: json['person_id'] as String,
      source: TimeLogSource.values.byName(json['source'] as String),
      startedAt: json['started_at'] as Timestamp,
      endedAt: json['ended_at'] as Timestamp?,
      durationSeconds: json['duration_seconds'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'week_id': weekId,
        'schedule_id': scheduleId,
        'day': day,
        'chore_id': choreId,
        'person_id': personId,
        'source': source.name,
        'started_at': startedAt,
        'ended_at': endedAt,
        'duration_seconds': durationSeconds,
      };

  bool get isRunning => endedAt == null;

  /// Seconds of work in this log; a running session counts up to [now].
  int secondsAt(DateTime now) {
    if (durationSeconds != null) return durationSeconds!;
    final elapsed = now.difference(startedAt.toDate()).inSeconds;
    return elapsed < 0 ? 0 : elapsed;
  }
}
