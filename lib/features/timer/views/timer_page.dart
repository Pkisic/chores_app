import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chores/app/theme.dart';
import 'package:chores/models/models.dart';
import 'package:chores/providers/providers.dart';
import 'package:chores/shared/constants.dart';
import 'package:chores/shared/widgets.dart';

// ── Persistence keys for surviving app kill ──────────────────
const _kActiveChoreId = 'timer_active_chore_id';
const _kActiveLogId = 'timer_active_log_id';
const _kActiveStartedAtMs = 'timer_started_at_ms';

class TimerPage extends ConsumerStatefulWidget {
  const TimerPage({super.key});

  @override
  ConsumerState<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends ConsumerState<TimerPage> {
  Timer? _ticker;
  int _elapsedSeconds = 0;

  // Active timer state
  String? _activeChoreId;
  String? _activeLogId;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _restoreTimerState();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Restore timer state from SharedPreferences (survives app kill).
  void _restoreTimerState() {
    final prefs = ref.read(sharedPrefsProvider);
    final choreId = prefs.getString(_kActiveChoreId);
    final logId = prefs.getString(_kActiveLogId);
    final startedAtMs = prefs.getInt(_kActiveStartedAtMs);

    if (choreId != null && logId != null && startedAtMs != null) {
      _activeChoreId = choreId;
      _activeLogId = logId;
      _startedAt = DateTime.fromMillisecondsSinceEpoch(startedAtMs);
      _elapsedSeconds = DateTime.now().difference(_startedAt!).inSeconds;
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startedAt != null && mounted) {
        setState(() {
          _elapsedSeconds = DateTime.now().difference(_startedAt!).inSeconds;
        });
      }
    });
  }

  Future<void> _persistTimerState(
      String choreId, String logId, DateTime startedAt) async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setString(_kActiveChoreId, choreId);
    await prefs.setString(_kActiveLogId, logId);
    await prefs.setInt(_kActiveStartedAtMs, startedAt.millisecondsSinceEpoch);
  }

  Future<void> _clearTimerState() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.remove(_kActiveChoreId);
    await prefs.remove(_kActiveLogId);
    await prefs.remove(_kActiveStartedAtMs);
  }

  Future<void> _startTimer(Chore chore) async {
    final hid = ref.read(householdIdProvider);
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (hid == null || user == null) return;

    final log = await ref
        .read(timeLogRepoProvider)
        .startTimer(hid, chore.id, user.uid);

    final now = DateTime.now();
    await _persistTimerState(chore.id, log.id, now);

    setState(() {
      _activeChoreId = chore.id;
      _activeLogId = log.id;
      _startedAt = now;
      _elapsedSeconds = 0;
    });

    _startTicker();
  }

  Future<void> _stopTimer() async {
    final hid = ref.read(householdIdProvider);
    if (hid == null || _activeLogId == null) return;

    await ref.read(timeLogRepoProvider).stopTimer(hid, _activeLogId!);
    await _clearTimerState();

    _ticker?.cancel();
    setState(() {
      _activeChoreId = null;
      _activeLogId = null;
      _startedAt = null;
      _elapsedSeconds = 0;
    });
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final choresAsync = ref.watch(choresProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Timer'),

          // ── Active timer display ───────────────────────
          if (_activeChoreId != null)
            _buildActiveTimer(choresAsync),

          // ── Chore grid to start timers ─────────────────
          Expanded(
            child: choresAsync.when(
              data: (chores) {
                if (chores.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer_outlined,
                            size: 64,
                            color: AppColors.textHint.withAlpha(100)),
                        const SizedBox(height: 16),
                        const Text(
                          'Add chores first to start timing them!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 12, bottom: 24),
                  itemCount: chores.length,
                  itemBuilder: (_, i) {
                    final chore = chores[i];
                    final isActive = _activeChoreId == chore.id;
                    final color = ChoreColors.fromHex(chore.color);

                    return GlassCard(
                      borderColor: isActive
                          ? color
                          : AppColors.divider,
                      onTap: _activeChoreId == null
                          ? () => _startTimer(chore)
                          : isActive
                              ? () => _stopTimer()
                              : null,
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color.withAlpha(isActive ? 80 : 40),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              ChoreIcons.fromKey(chore.icon),
                              color: color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  chore.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? color
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  isActive
                                      ? 'Tap to stop'
                                      : _activeChoreId != null
                                          ? 'Another timer is running'
                                          : 'Tap to start',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isActive
                                        ? color.withAlpha(180)
                                        : AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isActive) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: color.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatDuration(_elapsedSeconds),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                  fontSize: 16,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ] else
                            Icon(
                              Icons.play_circle_outline,
                              color: _activeChoreId != null
                                  ? AppColors.textHint.withAlpha(80)
                                  : color,
                              size: 28,
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const LoadingIndicator(),
              error: (e, _) => ErrorDisplay(message: e.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTimer(AsyncValue<List<Chore>> choresAsync) {
    return choresAsync.when(
      data: (chores) {
        final chore =
            chores.where((c) => c.id == _activeChoreId).firstOrNull;
        if (chore == null) return const SizedBox.shrink();
        final color = ChoreColors.fromHex(chore.color);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withAlpha(40),
                color.withAlpha(15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(60)),
          ),
          child: Column(
            children: [
              Icon(ChoreIcons.fromKey(chore.icon), color: color, size: 36),
              const SizedBox(height: 8),
              Text(
                chore.name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _formatDuration(_elapsedSeconds),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 160,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _stopTimer,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
