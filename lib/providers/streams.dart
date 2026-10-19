import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chores/models/models.dart';
import 'package:chores/providers/core.dart';

// ═══════════════════════════════════════════════════════════════
//  Firestore live-stream providers (household-wide)
// ═══════════════════════════════════════════════════════════════

/// Members of the current household.
final membersProvider = StreamProvider<List<Member>>((ref) {
  final hid = ref.watch(householdIdProvider);
  if (hid == null) return const Stream.empty();
  return ref.watch(householdRepoProvider).streamMembers(hid);
});

/// All chore definitions.
final choresProvider = StreamProvider<List<Chore>>((ref) {
  final hid = ref.watch(householdIdProvider);
  if (hid == null) return const Stream.empty();
  return ref.watch(choreRepoProvider).streamChores(hid);
});

/// All schedule entries (recurring and one-off).
final schedulesProvider = StreamProvider<List<ChoreSchedule>>((ref) {
  final hid = ref.watch(householdIdProvider);
  if (hid == null) return const Stream.empty();
  return ref.watch(scheduleRepoProvider).streamSchedules(hid);
});

/// Completed time logs only (for history view, newest first).
final completedLogsProvider = StreamProvider<List<TimeLog>>((ref) {
  final hid = ref.watch(householdIdProvider);
  if (hid == null) return const Stream.empty();
  return ref.watch(timeLogRepoProvider).streamCompletedLogs(hid);
});

/// Household stream.
final householdProvider = StreamProvider<Household?>((ref) {
  final hid = ref.watch(householdIdProvider);
  if (hid == null) return const Stream.empty();
  return ref.watch(householdRepoProvider).streamHousehold(hid);
});
