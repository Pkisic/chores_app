import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// Member id of the signed-in user (member docs are keyed by auth uid).
final currentMemberIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(firebaseAuthProvider).currentUser?.uid;
});

/// Firestore instance (overridden with a fake in tests).
final firestoreProvider =
    Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

/// Wall clock (overridden in tests).
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

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

final householdRepoProvider = Provider<HouseholdRepository>(
  (ref) => HouseholdRepository(firestore: ref.watch(firestoreProvider)),
);

final choreRepoProvider = Provider<ChoreRepository>(
  (ref) => ChoreRepository(firestore: ref.watch(firestoreProvider)),
);

final scheduleRepoProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(firestore: ref.watch(firestoreProvider)),
);

final timeLogRepoProvider = Provider<TimeLogRepository>(
  (ref) => TimeLogRepository(firestore: ref.watch(firestoreProvider)),
);

final weekItemRepoProvider = Provider<WeekItemRepository>(
  (ref) => WeekItemRepository(firestore: ref.watch(firestoreProvider)),
);
