import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chores/models/models.dart';

/// Repository for time-log sessions (timer + manual entries) and history.
///
/// Write methods take an optional [WriteBatch] so callers can combine them
/// atomically with other writes (e.g. closing a session + completing an item).
class TimeLogRepository {
  final FirebaseFirestore _db;

  TimeLogRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _logsCol(String hid) =>
      _db.collection('households').doc(hid).collection('time_logs');

  // ── Stream completed logs (for history, newest first) ──────
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

  // ── Stream every log (running + closed) of one week ────────
  Stream<List<TimeLog>> streamWeekLogs(String householdId, String weekId) {
    return _logsCol(householdId)
        .where('week_id', isEqualTo: weekId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => TimeLog.fromJson(d.data(), d.id)).toList(),
        );
  }

  // ── Running sessions of a person (any week) ────────────────
  Future<List<TimeLog>> getRunningLogs(
    String householdId,
    String personId,
  ) async {
    final snap = await _logsCol(householdId)
        .where('person_id', isEqualTo: personId)
        .where('ended_at', isNull: true)
        .get();
    return snap.docs.map((d) => TimeLog.fromJson(d.data(), d.id)).toList();
  }

  // ── All logs of one item (running + closed) ────────────────
  Future<List<TimeLog>> getItemLogs(String householdId, String itemId) async {
    final snap = await _logsCol(householdId)
        .where('item_id', isEqualTo: itemId)
        .get();
    return snap.docs.map((d) => TimeLog.fromJson(d.data(), d.id)).toList();
  }

  // ── Edit a closed log's duration ───────────────────────────
  // `duration_seconds` is authoritative; `started_at`/`ended_at` keep the
  // real wall-clock span for reference.
  Future<void> updateDuration(
    String householdId,
    String logId,
    int durationSeconds,
  ) {
    return _logsCol(householdId)
        .doc(logId)
        .update({'duration_seconds': durationSeconds});
  }

  // ── Delete a log ───────────────────────────────────────────
  Future<void> deleteLog(
    String householdId,
    String logId, {
    WriteBatch? batch,
  }) async {
    final doc = _logsCol(householdId).doc(logId);
    await _write(batch, (b) => b.delete(doc), doc.delete);
  }

  // ── Open a timer session ───────────────────────────────────
  Future<TimeLog> startSession(
    String householdId,
    ScheduleSlot slot,
    String personId,
    DateTime now, {
    WriteBatch? batch,
  }) async {
    final doc = _logsCol(householdId).doc();
    final log = TimeLog(
      id: doc.id,
      itemId: slot.itemId,
      weekId: slot.weekId,
      scheduleId: slot.scheduleId,
      day: slot.day,
      choreId: slot.choreId,
      personId: personId,
      source: TimeLogSource.timer,
      startedAt: Timestamp.fromDate(now),
    );
    await _write(
      batch,
      (b) => b.set(doc, log.toJson()),
      () => doc.set(log.toJson()),
    );
    return log;
  }

  // ── Close a timer session ──────────────────────────────────
  Future<void> closeSession(
    String householdId,
    TimeLog log,
    DateTime now, {
    WriteBatch? batch,
  }) async {
    final doc = _logsCol(householdId).doc(log.id);
    final data = {
      'ended_at': Timestamp.fromDate(now),
      'duration_seconds': log.secondsAt(now),
    };
    await _write(batch, (b) => b.update(doc, data), () => doc.update(data));
  }

  // ── Log manually entered time (created already closed) ─────
  Future<TimeLog> logManual(
    String householdId,
    ScheduleSlot slot,
    String personId,
    int durationSeconds,
    DateTime now, {
    WriteBatch? batch,
  }) async {
    final doc = _logsCol(householdId).doc();
    final at = Timestamp.fromDate(now);
    final log = TimeLog(
      id: doc.id,
      itemId: slot.itemId,
      weekId: slot.weekId,
      scheduleId: slot.scheduleId,
      day: slot.day,
      choreId: slot.choreId,
      personId: personId,
      source: TimeLogSource.manual,
      startedAt: at,
      endedAt: at,
      durationSeconds: durationSeconds,
    );
    await _write(
      batch,
      (b) => b.set(doc, log.toJson()),
      () => doc.set(log.toJson()),
    );
    return log;
  }

  Future<void> _write(
    WriteBatch? batch,
    void Function(WriteBatch) inBatch,
    Future<void> Function() direct,
  ) async {
    if (batch != null) {
      inBatch(batch);
    } else {
      await direct();
    }
  }
}
