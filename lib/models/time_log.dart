import 'package:cloud_firestore/cloud_firestore.dart';

/// A completed (or in-progress) time log entry.
class TimeLog {
  final String id;
  final String choreId;
  final String personId;
  final Timestamp startedAt;
  final Timestamp? endedAt;
  final int? durationSeconds;

  const TimeLog({
    required this.id,
    required this.choreId,
    required this.personId,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
  });

  factory TimeLog.fromJson(Map<String, dynamic> json, String docId) {
    return TimeLog(
      id: docId,
      choreId: json['chore_id'] as String,
      personId: json['person_id'] as String,
      startedAt: json['started_at'] as Timestamp,
      endedAt: json['ended_at'] as Timestamp?,
      durationSeconds: json['duration_seconds'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'chore_id': choreId,
        'person_id': personId,
        'started_at': startedAt,
        'ended_at': endedAt,
        'duration_seconds': durationSeconds,
      };

  bool get isRunning => endedAt == null;
}
