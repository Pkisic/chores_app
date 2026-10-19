import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chores/models/models.dart';

/// Repository for time-log entries (timer start/stop + history).
class TimeLogRepository {
  final FirebaseFirestore _db;

  TimeLogRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _logsCol(String hid) =>
      _db.collection('households').doc(hid).collection('time_logs');

  // ── Stream all logs (newest first) ─────────────────────────
  Stream<List<TimeLog>> streamLogs(String householdId) {
    return _logsCol(householdId)
        .orderBy('started_at', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => TimeLog.fromJson(d.data(), d.id)).toList(),
        );
  }

  // ── Stream completed logs only (for history) ──────────────
  // Keep a single ordering query on `started_at` so Firestore does not
  // require a composite index for `ended_at` + `started_at`.
  Stream<List<TimeLog>> streamCompletedLogs(String householdId) {
    return _logsCol(householdId)
        .orderBy('started_at', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .where((d) => d.data()['ended_at'] != null)
              .map((d) => TimeLog.fromJson(d.data(), d.id))
              .toList(),
        );
  }

  // ── Start timer (create log with started_at only) ─────────
  Future<TimeLog> startTimer(
    String householdId,
    String choreId,
    String personId,
  ) async {
    final doc = _logsCol(householdId).doc();
    final log = TimeLog(
      id: doc.id,
      choreId: choreId,
      personId: personId,
      startedAt: Timestamp.now(),
    );
    await doc.set(log.toJson());
    return log;
  }

  // ── Stop timer ─────────────────────────────────────────────
  Future<void> stopTimer(
    String householdId,
    String logId, {
    int? customDurationSeconds,
  }) async {
    final now = Timestamp.now();
    final docRef = _logsCol(householdId).doc(logId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final startedAt = (snap.data()!['started_at'] as Timestamp).toDate();
    final duration = customDurationSeconds ??
        now.toDate().difference(startedAt).inSeconds;

    await docRef.update({'ended_at': now, 'duration_seconds': duration});
  }

  // ── Log completed manual/custom duration time ─────────────
  Future<TimeLog> logCustomTime(
    String householdId,
    String choreId,
    String personId,
    int durationSeconds,
  ) async {
    final doc = _logsCol(householdId).doc();
    final now = DateTime.now();
    final startedAt = now.subtract(Duration(seconds: durationSeconds));
    final log = TimeLog(
      id: doc.id,
      choreId: choreId,
      personId: personId,
      startedAt: Timestamp.fromDate(startedAt),
      endedAt: Timestamp.fromDate(now),
      durationSeconds: durationSeconds,
    );
    await doc.set(log.toJson());
    return log;
  }

  // ── Get currently running log for a chore/person ──────────
  Future<TimeLog?> getRunningLog(
    String householdId,
    String choreId,
    String personId,
  ) async {
    final snap = await _logsCol(householdId)
        .where('chore_id', isEqualTo: choreId)
        .where('person_id', isEqualTo: personId)
        .where('ended_at', isNull: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return TimeLog.fromJson(doc.data(), doc.id);
  }
}
