import 'dart:async';
import 'dart:convert';
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

// ═══════════════════════════════════════════════════════════════
//  Schedule Timer State & Notifier
// ═══════════════════════════════════════════════════════════════

const _kScheduleTimerActiveKey = 'sched_timer_active_key';
const _kScheduleTimerActiveChoreId = 'sched_timer_active_chore_id';
const _kScheduleTimerActiveSchedId = 'sched_timer_active_sched_id';
const _kScheduleTimerActiveDay = 'sched_timer_active_day';
const _kScheduleTimerStartedAtMs = 'sched_timer_started_at_ms';
const _kScheduleTimerAccumulatedSecs = 'sched_timer_accumulated_secs';
const _kScheduleTimerIsPaused = 'sched_timer_is_paused';
const _kScheduleTimerActiveLogId = 'sched_timer_active_log_id';
const _kScheduleTimerElapsedMap = 'sched_timer_elapsed_map';
const _kScheduleTimerPersonMap = 'sched_timer_person_map';
const _kScheduleTimerWeekId = 'sched_timer_week_id';

String getIsoWeekId(DateTime date) {
  final thursday = date.add(Duration(days: 3 - ((date.weekday + 6) % 7)));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstThursdayCorrected =
      firstThursday.add(Duration(days: 3 - ((firstThursday.weekday + 6) % 7)));
  final weekNumber =
      1 + (thursday.difference(firstThursdayCorrected).inDays / 7).floor();
  return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
}

class ScheduleTimerState {
  final String? activeKey; // e.g. "${schedId}_$day"
  final String? activeChoreId;
  final String? activeScheduleId;
  final int? activeDay;
  final DateTime? startedAt;
  final int accumulatedSeconds;
  final bool isRunning;
  final bool isPaused;
  final String? activeLogId;
  final Map<String, int> itemElapsedSeconds;
  final Map<String, String> itemPersonMap;
  final String currentWeekId;

  const ScheduleTimerState({
    this.activeKey,
    this.activeChoreId,
    this.activeScheduleId,
    this.activeDay,
    this.startedAt,
    this.accumulatedSeconds = 0,
    this.isRunning = false,
    this.isPaused = false,
    this.activeLogId,
    this.itemElapsedSeconds = const {},
    this.itemPersonMap = const {},
    required this.currentWeekId,
  });

  ScheduleTimerState copyWith({
    String? activeKey,
    String? activeChoreId,
    String? activeScheduleId,
    int? activeDay,
    DateTime? startedAt,
    int? accumulatedSeconds,
    bool? isRunning,
    bool? isPaused,
    String? activeLogId,
    Map<String, int>? itemElapsedSeconds,
    Map<String, String>? itemPersonMap,
    String? currentWeekId,
    bool clearActiveKey = false,
  }) {
    return ScheduleTimerState(
      activeKey: clearActiveKey ? null : (activeKey ?? this.activeKey),
      activeChoreId:
          clearActiveKey ? null : (activeChoreId ?? this.activeChoreId),
      activeScheduleId:
          clearActiveKey ? null : (activeScheduleId ?? this.activeScheduleId),
      activeDay: clearActiveKey ? null : (activeDay ?? this.activeDay),
      startedAt: clearActiveKey ? null : (startedAt ?? this.startedAt),
      accumulatedSeconds:
          clearActiveKey ? 0 : (accumulatedSeconds ?? this.accumulatedSeconds),
      isRunning: clearActiveKey ? false : (isRunning ?? this.isRunning),
      isPaused: clearActiveKey ? false : (isPaused ?? this.isPaused),
      activeLogId: clearActiveKey ? null : (activeLogId ?? this.activeLogId),
      itemElapsedSeconds: itemElapsedSeconds ?? this.itemElapsedSeconds,
      itemPersonMap: itemPersonMap ?? this.itemPersonMap,
      currentWeekId: currentWeekId ?? this.currentWeekId,
    );
  }

  int getElapsedSecondsFor(String key) {
    if (activeKey == key) {
      int total = accumulatedSeconds;
      if (isRunning && startedAt != null) {
        total += DateTime.now().difference(startedAt!).inSeconds;
      }
      return total;
    }
    return itemElapsedSeconds[key] ?? 0;
  }
}

class ScheduleTimerNotifier extends Notifier<ScheduleTimerState> {
  Timer? _ticker;

  @override
  ScheduleTimerState build() {
    ref.onDispose(() {
      _ticker?.cancel();
    });

    final prefs = ref.read(sharedPrefsProvider);
    final now = DateTime.now();
    final weekId = getIsoWeekId(now);

    final storedWeekId = prefs.getString(_kScheduleTimerWeekId);
    // Weekly Reset: if stored week is different from current week, reset all timers!
    if (storedWeekId != null && storedWeekId != weekId) {
      prefs.remove(_kScheduleTimerActiveKey);
      prefs.remove(_kScheduleTimerActiveChoreId);
      prefs.remove(_kScheduleTimerActiveSchedId);
      prefs.remove(_kScheduleTimerActiveDay);
      prefs.remove(_kScheduleTimerStartedAtMs);
      prefs.remove(_kScheduleTimerAccumulatedSecs);
      prefs.remove(_kScheduleTimerIsPaused);
      prefs.remove(_kScheduleTimerActiveLogId);
      prefs.remove(_kScheduleTimerElapsedMap);
      prefs.remove(_kScheduleTimerPersonMap);
      prefs.setString(_kScheduleTimerWeekId, weekId);

      return ScheduleTimerState(currentWeekId: weekId);
    } else {
      prefs.setString(_kScheduleTimerWeekId, weekId);
    }

    final activeKey = prefs.getString(_kScheduleTimerActiveKey);
    final choreId = prefs.getString(_kScheduleTimerActiveChoreId);
    final schedId = prefs.getString(_kScheduleTimerActiveSchedId);
    final day = prefs.getInt(_kScheduleTimerActiveDay);
    final startedAtMs = prefs.getInt(_kScheduleTimerStartedAtMs);
    final accumulatedSecs = prefs.getInt(_kScheduleTimerAccumulatedSecs) ?? 0;
    final isPaused = prefs.getBool(_kScheduleTimerIsPaused) ?? false;
    final activeLogId = prefs.getString(_kScheduleTimerActiveLogId);

    Map<String, int> elapsedMap = {};
    final mapJson = prefs.getString(_kScheduleTimerElapsedMap);
    if (mapJson != null) {
      try {
        final decoded = jsonDecode(mapJson) as Map<String, dynamic>;
        elapsedMap = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    Map<String, String> personMap = {};
    final personJson = prefs.getString(_kScheduleTimerPersonMap);
    if (personJson != null) {
      try {
        final decoded = jsonDecode(personJson) as Map<String, dynamic>;
        personMap = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }

    if (activeKey != null && startedAtMs != null && !isPaused) {
      final startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMs);
      final initialState = ScheduleTimerState(
        activeKey: activeKey,
        activeChoreId: choreId,
        activeScheduleId: schedId,
        activeDay: day,
        startedAt: startedAt,
        accumulatedSeconds: accumulatedSecs,
        isRunning: true,
        isPaused: false,
        activeLogId: activeLogId,
        itemElapsedSeconds: elapsedMap,
        itemPersonMap: personMap,
        currentWeekId: weekId,
      );
      _startTicker();
      return initialState;
    } else if (activeKey != null && isPaused) {
      return ScheduleTimerState(
        activeKey: activeKey,
        activeChoreId: choreId,
        activeScheduleId: schedId,
        activeDay: day,
        startedAt: null,
        accumulatedSeconds: accumulatedSecs,
        isRunning: false,
        isPaused: true,
        activeLogId: activeLogId,
        itemElapsedSeconds: elapsedMap,
        itemPersonMap: personMap,
        currentWeekId: weekId,
      );
    }

    return ScheduleTimerState(
      itemElapsedSeconds: elapsedMap,
      itemPersonMap: personMap,
      currentWeekId: weekId,
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isRunning && state.startedAt != null) {
        state = state.copyWith();
      }
    });
  }

  Future<void> startOrResume({
    required String scheduleId,
    required int day,
    required String choreId,
    required String personId,
  }) async {
    final key = '${scheduleId}_$day';

    // If another timer is active and running, pause it first
    if (state.activeKey != null && state.activeKey != key && state.isRunning) {
      await pause();
    }

    final updatedPersonMap = Map<String, String>.from(state.itemPersonMap);
    updatedPersonMap[key] = personId;

    // If resuming current paused timer
    if (state.activeKey == key && state.isPaused) {
      final now = DateTime.now();
      state = state.copyWith(
        startedAt: now,
        isRunning: true,
        isPaused: false,
        itemPersonMap: updatedPersonMap,
      );
      _startTicker();
      await _persistActiveState();
      return;
    }

    // If already running for this key, no-op
    if (state.activeKey == key && state.isRunning) {
      return;
    }

    // Start fresh or resume from previously accumulated seconds
    final existingElapsed = state.itemElapsedSeconds[key] ?? 0;
    final hid = ref.read(householdIdProvider);
    String? logId = state.activeLogId;

    if (hid != null && (state.activeKey != key || logId == null)) {
      final user = ref.read(firebaseAuthProvider).currentUser;
      final log = await ref
          .read(timeLogRepoProvider)
          .startTimer(hid, choreId, user?.uid ?? personId);
      logId = log.id;
    }

    final now = DateTime.now();
    state = state.copyWith(
      activeKey: key,
      activeChoreId: choreId,
      activeScheduleId: scheduleId,
      activeDay: day,
      startedAt: now,
      accumulatedSeconds: existingElapsed,
      isRunning: true,
      isPaused: false,
      activeLogId: logId,
      itemPersonMap: updatedPersonMap,
    );

    _startTicker();
    await _persistActiveState();
  }

  Future<void> addCustomTime({
    required String scheduleId,
    required int day,
    required String choreId,
    required String personId,
    required int minutes,
  }) async {
    final key = '${scheduleId}_$day';
    final additionalSeconds = minutes * 60;
    final currentElapsed = state.getElapsedSecondsFor(key);
    final newTotal = currentElapsed + additionalSeconds;

    final updatedMap = Map<String, int>.from(state.itemElapsedSeconds);
    updatedMap[key] = newTotal;

    final updatedPersonMap = Map<String, String>.from(state.itemPersonMap);
    updatedPersonMap[key] = personId;

    // Log to Firestore for history
    final hid = ref.read(householdIdProvider);
    if (hid != null) {
      final log = await ref
          .read(timeLogRepoProvider)
          .startTimer(hid, choreId, personId);
      await ref.read(timeLogRepoProvider).stopTimer(hid, log.id);
    }

    if (state.activeKey == key) {
      state = state.copyWith(
        accumulatedSeconds: state.accumulatedSeconds + additionalSeconds,
        itemElapsedSeconds: updatedMap,
        itemPersonMap: updatedPersonMap,
      );
    } else {
      state = state.copyWith(
        itemElapsedSeconds: updatedMap,
        itemPersonMap: updatedPersonMap,
      );
    }

    await _persistElapsedMap(updatedMap);
    await _persistPersonMap(updatedPersonMap);
  }

  Future<void> pause() async {
    if (!state.isRunning || state.startedAt == null || state.activeKey == null) {
      return;
    }

    _ticker?.cancel();
    final delta = DateTime.now().difference(state.startedAt!).inSeconds;
    final totalAccumulated = state.accumulatedSeconds + delta;
    final key = state.activeKey!;

    final updatedMap = Map<String, int>.from(state.itemElapsedSeconds);
    updatedMap[key] = totalAccumulated;

    state = state.copyWith(
      startedAt: null,
      accumulatedSeconds: totalAccumulated,
      isRunning: false,
      isPaused: true,
      itemElapsedSeconds: updatedMap,
    );

    await _persistActiveState();
  }

  Future<void> stop() async {
    if (state.activeKey == null) return;

    _ticker?.cancel();
    final key = state.activeKey!;
    final finalSeconds = state.getElapsedSecondsFor(key);

    final hid = ref.read(householdIdProvider);
    if (hid != null && state.activeLogId != null) {
      await ref.read(timeLogRepoProvider).stopTimer(hid, state.activeLogId!);
    }

    final updatedMap = Map<String, int>.from(state.itemElapsedSeconds);
    updatedMap[key] = finalSeconds;

    state = ScheduleTimerState(
      itemElapsedSeconds: updatedMap,
      itemPersonMap: state.itemPersonMap,
      currentWeekId: state.currentWeekId,
    );

    await _clearActiveStateFromPrefs();
    await _persistElapsedMap(updatedMap);
  }

  Future<void> _persistActiveState() async {
    final prefs = ref.read(sharedPrefsProvider);
    if (state.activeKey != null) {
      await prefs.setString(_kScheduleTimerActiveKey, state.activeKey!);
      if (state.activeChoreId != null) {
        await prefs.setString(_kScheduleTimerActiveChoreId, state.activeChoreId!);
      }
      if (state.activeScheduleId != null) {
        await prefs.setString(
            _kScheduleTimerActiveSchedId, state.activeScheduleId!);
      }
      if (state.activeDay != null) {
        await prefs.setInt(_kScheduleTimerActiveDay, state.activeDay!);
      }
      if (state.startedAt != null) {
        await prefs.setInt(
            _kScheduleTimerStartedAtMs, state.startedAt!.millisecondsSinceEpoch);
      }
      await prefs.setInt(
          _kScheduleTimerAccumulatedSecs, state.accumulatedSeconds);
      await prefs.setBool(_kScheduleTimerIsPaused, state.isPaused);
      if (state.activeLogId != null) {
        await prefs.setString(_kScheduleTimerActiveLogId, state.activeLogId!);
      }
    }
    await _persistElapsedMap(state.itemElapsedSeconds);
    await _persistPersonMap(state.itemPersonMap);
  }

  Future<void> _clearActiveStateFromPrefs() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.remove(_kScheduleTimerActiveKey);
    await prefs.remove(_kScheduleTimerActiveChoreId);
    await prefs.remove(_kScheduleTimerActiveSchedId);
    await prefs.remove(_kScheduleTimerActiveDay);
    await prefs.remove(_kScheduleTimerStartedAtMs);
    await prefs.remove(_kScheduleTimerAccumulatedSecs);
    await prefs.remove(_kScheduleTimerIsPaused);
    await prefs.remove(_kScheduleTimerActiveLogId);
  }

  Future<void> _persistElapsedMap(Map<String, int> map) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString(_kScheduleTimerElapsedMap, jsonEncode(map));
  }

  Future<void> _persistPersonMap(Map<String, String> map) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString(_kScheduleTimerPersonMap, jsonEncode(map));
  }
}

final scheduleTimerProvider =
    NotifierProvider<ScheduleTimerNotifier, ScheduleTimerState>(
        ScheduleTimerNotifier.new);


