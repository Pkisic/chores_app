import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chores/models/models.dart';
import 'package:chores/providers/providers.dart';

/// Timer and completion actions on schedule items. All state lives in
/// Firestore: a running timer is a time log with no `ended_at`, so it survives
/// app restarts and is visible to every household member.
///
/// Rules:
/// - One running session per person; starting another closes the current one.
/// - Several people may log time on the same item; totals add up.
/// - Completing or adding manual time marks the item done.
/// - Any member can edit or delete any closed session; deleting the last
///   session of a done item reopens it.
class TimerController {
  TimerController(this._ref);

  final Ref _ref;

  String get _householdId =>
      _ref.read(householdIdProvider) ??
      (throw StateError('No household selected'));

  String get _memberId =>
      _ref.read(currentMemberIdProvider) ??
      (throw StateError('Not signed in'));

  DateTime _now() => _ref.read(clockProvider)();

  // ── Start / resume ─────────────────────────────────────────
  Future<void> start(ScheduleSlot slot) async {
    final hid = _householdId;
    final me = _memberId;
    final logs = _ref.read(timeLogRepoProvider);

    final running = await logs.getRunningLogs(hid, me);
    if (running.any((l) => l.itemId == slot.itemId)) return;

    final now = _now();
    final batch = _ref.read(firestoreProvider).batch();
    for (final log in running) {
      await logs.closeSession(hid, log, now, batch: batch);
    }
    await logs.startSession(hid, slot, me, now, batch: batch);
    await batch.commit();
  }

  // ── Pause (closes my session on this item) ─────────────────
  Future<void> pause(ScheduleSlot slot) async {
    final hid = _householdId;
    final logs = _ref.read(timeLogRepoProvider);
    final mine = await _myRunningOn(slot);
    if (mine.isEmpty) return;

    final now = _now();
    final batch = _ref.read(firestoreProvider).batch();
    for (final log in mine) {
      await logs.closeSession(hid, log, now, batch: batch);
    }
    await batch.commit();
  }

  // ── Stop & complete ────────────────────────────────────────
  Future<void> complete(ScheduleSlot slot) async {
    final hid = _householdId;
    final me = _memberId;
    final logs = _ref.read(timeLogRepoProvider);
    final mine = await _myRunningOn(slot);

    final now = _now();
    final batch = _ref.read(firestoreProvider).batch();
    for (final log in mine) {
      await logs.closeSession(hid, log, now, batch: batch);
    }
    await _ref
        .read(weekItemRepoProvider)
        .markDone(hid, slot, me, now, batch: batch);
    await batch.commit();
  }

  // ── Manual time (credited to whoever did it) ───────────────
  Future<void> addManual(
    ScheduleSlot slot, {
    required String personId,
    required int seconds,
  }) async {
    if (seconds <= 0) {
      throw ArgumentError.value(seconds, 'seconds', 'must be positive');
    }
    final hid = _householdId;
    final now = _now();
    final batch = _ref.read(firestoreProvider).batch();
    await _ref
        .read(timeLogRepoProvider)
        .logManual(hid, slot, personId, seconds, now, batch: batch);
    await _ref
        .read(weekItemRepoProvider)
        .markDone(hid, slot, personId, now, batch: batch);
    await batch.commit();
  }

  // ── Reopen a done item (logged time is kept) ───────────────
  Future<void> reopen(ScheduleSlot slot) {
    return _ref.read(weekItemRepoProvider).reopen(_householdId, slot.itemId);
  }

  // ── Fix a closed session's duration (any member) ───────────
  Future<void> editDuration(TimeLog log, {required int seconds}) async {
    if (log.isRunning) {
      throw StateError('Pause the timer before editing this session');
    }
    if (seconds <= 0) {
      throw ArgumentError.value(seconds, 'seconds', 'must be positive');
    }
    await _ref
        .read(timeLogRepoProvider)
        .updateDuration(_householdId, log.id, seconds);
  }

  // ── Delete a session (any member) ──────────────────────────
  // Deleting the last session of a done item reopens it.
  Future<void> deleteLog(TimeLog log) async {
    final hid = _householdId;
    final logs = _ref.read(timeLogRepoProvider);
    final items = _ref.read(weekItemRepoProvider);

    final batch = _ref.read(firestoreProvider).batch();
    await logs.deleteLog(hid, log.id, batch: batch);

    final remaining = (await logs.getItemLogs(hid, log.itemId))
        .where((l) => l.id != log.id);
    if (remaining.isEmpty) {
      final item = await items.getItem(hid, log.itemId);
      if (item != null && item.isDone) {
        await items.reopen(hid, log.itemId, batch: batch);
      }
    }
    await batch.commit();
  }

  Future<List<TimeLog>> _myRunningOn(ScheduleSlot slot) async {
    final running = await _ref
        .read(timeLogRepoProvider)
        .getRunningLogs(_householdId, _memberId);
    return running.where((l) => l.itemId == slot.itemId).toList();
  }
}

final timerControllerProvider =
    Provider<TimerController>((ref) => TimerController(ref));
