import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chores/app/theme.dart';
import 'package:chores/models/models.dart';
import 'package:chores/providers/providers.dart';
import 'package:chores/shared/constants.dart';
import 'package:chores/shared/widgets.dart';
import 'package:chores/features/schedule/views/schedule_form_sheet.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedulesAsync = ref.watch(schedulesProvider);
    final choresAsync = ref.watch(choresProvider);
    final membersAsync = ref.watch(membersProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Weekly Schedule'),
          Expanded(
            child: schedulesAsync.when(
              data: (schedules) => choresAsync.when(
                data: (chores) => membersAsync.when(
                  data: (members) => _buildWeekView(
                      context, ref, schedules, chores, members),
                  loading: () => const LoadingIndicator(),
                  error: (e, _) => ErrorDisplay(message: e.toString()),
                ),
                loading: () => const LoadingIndicator(),
                error: (e, _) => ErrorDisplay(message: e.toString()),
              ),
              loading: () => const LoadingIndicator(),
              error: (e, _) => ErrorDisplay(message: e.toString()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_schedule',
        onPressed: () => _openScheduleForm(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildWeekView(
    BuildContext context,
    WidgetRef ref,
    List<ChoreSchedule> schedules,
    List<Chore> chores,
    List<Member> members,
  ) {
    if (schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 64, color: AppColors.textHint.withAlpha(100)),
            const SizedBox(height: 16),
            const Text(
              'No schedule entries yet.\nTap + to assign a chore!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final choreMap = {for (final c in chores) c.id: c};
    final memberMap = {for (final m in members) m.id: m};
    final timerState = ref.watch(scheduleTimerProvider);
    final timerNotifier = ref.read(scheduleTimerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        children: List.generate(7, (dayIdx) {
          final day = dayIdx + 1; // 1=Mon … 7=Sun
          final daySchedules =
              schedules.where((s) => s.days.contains(day)).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: day == DateTime.now().weekday
                            ? AppColors.primary.withAlpha(40)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          Weekdays.shortName(day).substring(0, 1),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: day == DateTime.now().weekday
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      Weekdays.fullName(day),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: day == DateTime.now().weekday
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (day == DateTime.now().weekday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Today',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (daySchedules.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 62, bottom: 8),
                  child: Text(
                    'Nothing scheduled',
                    style:
                        TextStyle(color: AppColors.textHint, fontSize: 13),
                  ),
                )
              else
                ...daySchedules.map((sched) {
                  final chore = choreMap[sched.choreId];
                  final member = memberMap[sched.personId];
                  if (chore == null) return const SizedBox.shrink();
                  final color = ChoreColors.fromHex(chore.color);

                  final itemKey = '${sched.id}_$day';
                  final isActive = timerState.activeKey == itemKey;
                  final isRunning = isActive && timerState.isRunning;
                  final isPaused = isActive && timerState.isPaused;
                  final elapsedSeconds =
                      timerState.getElapsedSecondsFor(itemKey);

                  final cardBorderColor = isActive
                      ? color
                      : elapsedSeconds > 0
                          ? color.withAlpha(140)
                          : color.withAlpha(60);

                  return Dismissible(
                    key: ValueKey(sched.id + day.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(60),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline,
                          color: AppColors.error),
                    ),
                    onDismissed: (_) {
                      final hid = ref.read(householdIdProvider);
                      if (hid != null) {
                        ref
                            .read(scheduleRepoProvider)
                            .deleteSchedule(hid, sched.id);
                      }
                    },
                    child: GlassCard(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
                      padding: const EdgeInsets.all(14),
                      borderColor: cardBorderColor,
                      onTap: () {
                        if (isActive && isRunning) {
                          timerNotifier.pause();
                        } else {
                          timerNotifier.startOrResume(
                            scheduleId: sched.id,
                            day: day,
                            choreId: chore.id,
                            personId: sched.personId,
                          );
                        }
                      },
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: color.withAlpha(isActive ? 60 : 35),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  ChoreIcons.fromKey(chore.icon),
                                  color: color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          chore.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isActive
                                                ? color
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        if (sched.recurring) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color:
                                                  AppColors.accent.withAlpha(30),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              '↻',
                                              style: TextStyle(
                                                  color: AppColors.accent,
                                                  fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        if (member != null) ...[
                                          Text(
                                            member.displayName,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Text(
                                          isRunning
                                              ? '• Running...'
                                              : isPaused
                                                  ? '• Paused'
                                                  : elapsedSeconds > 0
                                                      ? '• Stopped (Tap to resume)'
                                                      : '• Tap to start',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isRunning
                                                ? AppColors.primary
                                                : isPaused
                                                    ? AppColors.accent
                                                    : AppColors.textHint,
                                            fontWeight: isActive
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    size: 18, color: AppColors.textHint),
                                onPressed: () => _openScheduleForm(context,
                                    schedule: sched),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          if (isActive || elapsedSeconds > 0) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: AppColors.divider),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isRunning
                                          ? Icons.timer
                                          : Icons.timer_outlined,
                                      size: 16,
                                      color: isActive
                                          ? color
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatTimerDuration(elapsedSeconds),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isActive
                                            ? color
                                            : AppColors.textPrimary,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (isActive) ...[
                                      IconButton(
                                        icon: Icon(
                                          isRunning
                                              ? Icons.pause_circle_filled
                                              : Icons.play_circle_filled,
                                          color: color,
                                          size: 28,
                                        ),
                                        tooltip: isRunning
                                            ? 'Pause Timer'
                                            : 'Resume Timer',
                                        onPressed: () {
                                          if (isRunning) {
                                            timerNotifier.pause();
                                          } else {
                                            timerNotifier.startOrResume(
                                              scheduleId: sched.id,
                                              day: day,
                                              choreId: chore.id,
                                              personId: sched.personId,
                                            );
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.stop_circle_rounded,
                                          color: AppColors.error,
                                          size: 28,
                                        ),
                                        tooltip: 'Stop & Complete',
                                        onPressed: () => timerNotifier.stop(),
                                      ),
                                    ] else ...[
                                      TextButton.icon(
                                        onPressed: () {
                                          timerNotifier.startOrResume(
                                            scheduleId: sched.id,
                                            day: day,
                                            choreId: chore.id,
                                            personId: sched.personId,
                                          );
                                        },
                                        icon: Icon(Icons.play_arrow_rounded,
                                            color: color, size: 20),
                                        label: Text(
                                          'Resume',
                                          style: TextStyle(
                                              color: color,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              const Divider(indent: 20, endIndent: 20),
            ],
          );
        }),
      ),
    );
  }

  String _formatTimerDuration(int totalSeconds) {
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

  void _openScheduleForm(BuildContext context, {ChoreSchedule? schedule}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScheduleFormSheet(schedule: schedule),
    );
  }
}

