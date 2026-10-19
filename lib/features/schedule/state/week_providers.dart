import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chores/models/models.dart';
import 'package:chores/providers/providers.dart';
import 'package:chores/shared/week.dart';
import 'package:chores/features/schedule/state/week_board.dart';

// ── Current ISO week ─────────────────────────────────────────
// Rolls over on its own at Monday midnight; HomeShell also calls [refresh]
// when the app resumes, since timers don't fire while suspended.
class CurrentWeekIdNotifier extends Notifier<String> {
  Timer? _rollover;

  @override
  String build() {
    ref.onDispose(() => _rollover?.cancel());
    final now = ref.watch(clockProvider)();
    final weekId = WeekId.of(now);
    _scheduleRollover(now, weekId);
    return weekId;
  }

  void refresh() {
    final weekId = WeekId.of(ref.read(clockProvider)());
    if (weekId != state) ref.invalidateSelf();
  }

  void _scheduleRollover(DateTime now, String weekId) {
    _rollover?.cancel();
    final nextMonday = WeekId.startOf(WeekId.shift(weekId, 1));
    _rollover = Timer(nextMonday.difference(now), refresh);
  }
}

final currentWeekIdProvider =
    NotifierProvider<CurrentWeekIdNotifier, String>(CurrentWeekIdNotifier.new);

// ── Week being viewed on the Schedule page ───────────────────
class SelectedWeekIdNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(currentWeekIdProvider);

  void previous() => state = WeekId.shift(state, -1);
  void next() => state = WeekId.shift(state, 1);
  void goToCurrent() => state = ref.read(currentWeekIdProvider);
}

final selectedWeekIdProvider =
    NotifierProvider<SelectedWeekIdNotifier, String>(
        SelectedWeekIdNotifier.new);

// ── Per-week Firestore streams ───────────────────────────────
final weekItemsProvider =
    StreamProvider.family<List<WeekItem>, String>((ref, weekId) {
  final hid = ref.watch(householdIdProvider);
  if (hid == null) return const Stream.empty();
  return ref.watch(weekItemRepoProvider).streamWeek(hid, weekId);
});

final weekLogsProvider =
    StreamProvider.family<List<TimeLog>, String>((ref, weekId) {
  final hid = ref.watch(householdIdProvider);
  if (hid == null) return const Stream.empty();
  return ref.watch(timeLogRepoProvider).streamWeekLogs(hid, weekId);
});

// ── Combined board for a week ────────────────────────────────
final weekBoardProvider =
    Provider.family<AsyncValue<WeekBoard>, String>((ref, weekId) {
  final schedules = ref.watch(schedulesProvider);
  final chores = ref.watch(choresProvider);
  final members = ref.watch(membersProvider);
  final items = ref.watch(weekItemsProvider(weekId));
  final logs = ref.watch(weekLogsProvider(weekId));

  final all = <AsyncValue<Object?>>[schedules, chores, members, items, logs];
  for (final value in all) {
    if (value.hasError) {
      return AsyncError(value.error!, value.stackTrace ?? StackTrace.empty);
    }
  }
  if (all.any((v) => !v.hasValue)) return const AsyncLoading();

  return AsyncData(
    buildWeekBoard(
      weekId: weekId,
      schedules: schedules.requireValue,
      chores: chores.requireValue,
      members: members.requireValue,
      items: items.requireValue,
      logs: logs.requireValue,
    ),
  );
});

// ── 1s ticker for running timers ─────────────────────────────
// Watched only by widgets that display a running session, so the rest of the
// page doesn't rebuild every second.
final tickProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) => clock());
});
