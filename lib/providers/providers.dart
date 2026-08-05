import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chores/models/models.dart';
import 'package:chores/repositories/repositories.dart';

// ═══════════════════════════════════════════════════════════════
//  Core / Infrastructure providers
// ═══════════════════════════════════════════════════════════════

/// Firebase Auth instance.
final firebaseAuthProvider =
    Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

/// Current authenticated user (stream).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// SharedPreferences (must be overridden in main with a pre-loaded instance).
final sharedPrefsProvider = Provider<SharedPreferences>((_) {
  throw UnimplementedError('Override sharedPrefsProvider in main');
});

// ═══════════════════════════════════════════════════════════════
//  Session state (household id, stored in SharedPreferences)
// ═══════════════════════════════════════════════════════════════

const _kHouseholdIdKey = 'household_id';

/// Notifier that manages which household the user belongs to.
class HouseholdIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    final prefs = ref.read(sharedPrefsProvider);
    return prefs.getString(_kHouseholdIdKey);
  }

  Future<void> set(String id) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString(_kHouseholdIdKey, id);
    state = id;
  }

  Future<void> clear() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.remove(_kHouseholdIdKey);
    state = null;
  }
}

final householdIdProvider =
    NotifierProvider<HouseholdIdNotifier, String?>(HouseholdIdNotifier.new);

// ═══════════════════════════════════════════════════════════════
//  Repository singletons
// ═══════════════════════════════════════════════════════════════

final householdRepoProvider =
    Provider<HouseholdRepository>((_) => HouseholdRepository());

final choreRepoProvider =
    Provider<ChoreRepository>((_) => ChoreRepository());

final scheduleRepoProvider =
    Provider<ScheduleRepository>((_) => ScheduleRepository());

final timeLogRepoProvider =
    Provider<TimeLogRepository>((_) => TimeLogRepository());

// ═══════════════════════════════════════════════════════════════
//  Firestore live-stream providers
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

/// All schedule entries.
final schedulesProvider = StreamProvider<List<ChoreSchedule>>((ref) {
  final hid = ref.watch(householdIdProvider);
  if (hid == null) return const Stream.empty();
  return ref.watch(scheduleRepoProvider).streamSchedules(hid);
});

/// All time logs (newest first).
final timeLogsProvider = StreamProvider<List<TimeLog>>((ref) {
  final hid = ref.watch(householdIdProvider);
  if (hid == null) return const Stream.empty();
  return ref.watch(timeLogRepoProvider).streamLogs(hid);
});

/// Completed time logs only (for history view).
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
