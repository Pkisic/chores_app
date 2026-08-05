import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final timerState = ref.watch(scheduleTimerProvider);

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            title: 'Weekly Schedule',
            actions: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withAlpha(80)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.date_range,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      timerState.currentWeekId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
                  final assignedMember = memberMap[sched.personId];
                  if (chore == null) return const SizedBox.shrink();
                  final color = ChoreColors.fromHex(chore.color);

                  final itemKey = '${sched.id}_$day';
                  final isActive = timerState.activeKey == itemKey;
                  final isRunning = isActive && timerState.isRunning;
                  final isPaused = isActive && timerState.isPaused;
                  final elapsedSeconds =
                      timerState.getElapsedSecondsFor(itemKey);

                  // Lookup person who did/logged the time on this item
                  final loggedPersonId =
                      timerState.itemPersonMap[itemKey] ?? sched.personId;
                  final loggedMember = memberMap[loggedPersonId] ?? assignedMember;

                  final hasTime = elapsedSeconds > 0 || isActive;

                  // Brighter, vivid card styling for chores with time on them!
                  final cardBorderColor = hasTime ? color : color.withAlpha(60);

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
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        color: hasTime
                            ? color.withAlpha(45)
                            : AppColors.card.withAlpha(200),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cardBorderColor,
                          width: hasTime ? 2.0 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: hasTime
                                ? color.withAlpha(70)
                                : Colors.black.withAlpha(40),
                            blurRadius: hasTime ? 12 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
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
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: color.withAlpha(hasTime ? 110 : 35),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: hasTime ? color : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        ChoreIcons.fromKey(chore.icon),
                                        color: hasTime ? Colors.white : color,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                chore.name,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: hasTime
                                                      ? Colors.white
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                              if (sched.recurring) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.accent
                                                        .withAlpha(30),
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
                                              // Person in charge of the chore (always shown)
                                              if (assignedMember != null) ...[
                                                Icon(
                                                  Icons.person_outline,
                                                  size: 13,
                                                  color: hasTime
                                                      ? Colors.white70
                                                      : AppColors.textSecondary,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  assignedMember.displayName,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: hasTime
                                                        ? Colors.white70
                                                        : AppColors.textSecondary,
                                                  ),
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
                                                          : hasTime
                                                              ? Colors.white60
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

                                    // Button 1: Custom Time button (before edit button)
                                    IconButton(
                                      icon: Icon(
                                        Icons.alarm_add_rounded,
                                        size: 20,
                                        color: hasTime
                                            ? Colors.white
                                            : color,
                                      ),
                                      tooltip: 'Add custom time',
                                      onPressed: () => _showAddCustomTimeDialog(
                                        context,
                                        ref,
                                        sched,
                                        day,
                                        chore,
                                        members,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),

                                    // Button 2: Edit pencil button
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: hasTime
                                            ? Colors.white70
                                            : AppColors.textHint,
                                      ),
                                      onPressed: () => _openScheduleForm(
                                          context,
                                          schedule: sched),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                if (isActive || elapsedSeconds > 0) ...[
                                  const SizedBox(height: 10),
                                  Divider(
                                    height: 1,
                                    color: Colors.white.withAlpha(50),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isRunning
                                                ? Icons.timer
                                                : Icons.timer_outlined,
                                            size: 16,
                                            color: hasTime
                                                ? Colors.white
                                                : color,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _formatTimerDuration(
                                                elapsedSeconds),
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: hasTime
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures()
                                              ],
                                            ),
                                          ),
                                          if (loggedMember != null) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                              decoration: BoxDecoration(
                                                color:
                                                    Colors.white.withAlpha(40),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.person,
                                                      size: 11,
                                                      color: Colors.white),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    loggedMember.displayName,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
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
                                                color: Colors.white,
                                                size: 30,
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
                                                size: 30,
                                              ),
                                              tooltip: 'Stop & Complete',
                                              onPressed: () =>
                                                  timerNotifier.stop(),
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
                                              icon: const Icon(
                                                  Icons.play_arrow_rounded,
                                                  color: Colors.white,
                                                  size: 20),
                                              label: const Text(
                                                'Resume',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.w700),
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
                        ),
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

  void _showAddCustomTimeDialog(
    BuildContext context,
    WidgetRef ref,
    ChoreSchedule sched,
    int day,
    Chore chore,
    List<Member> members,
  ) {
    int selectedMinutes = 15;
    String selectedPersonId = sched.personId;
    final controller = TextEditingController(text: '15');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.alarm_add_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add Time: ${chore.name}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Minutes:',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [15, 30, 45, 60, 90].map((mins) {
                      final isSelected = selectedMinutes == mins;
                      return ChoiceChip(
                        label: Text('+$mins m'),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        onSelected: (_) {
                          setStateDialog(() {
                            selectedMinutes = mins;
                            controller.text = mins.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Custom Minutes',
                      hintText: 'Enter minutes',
                      suffixText: 'min',
                    ),
                    onChanged: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed > 0) {
                        setStateDialog(() {
                          selectedMinutes = parsed;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Done By:',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: members.any((m) => m.id == selectedPersonId)
                        ? selectedPersonId
                        : (members.isNotEmpty ? members.first.id : null),
                    items: members.map((m) {
                      return DropdownMenuItem(
                        value: m.id,
                        child: Text(m.displayName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() {
                          selectedPersonId = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    final mins = int.tryParse(controller.text) ?? selectedMinutes;
                    if (mins > 0) {
                      ref.read(scheduleTimerProvider.notifier).addCustomTime(
                            scheduleId: sched.id,
                            day: day,
                            choreId: chore.id,
                            personId: selectedPersonId,
                            minutes: mins,
                          );
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Add Time'),
                ),
              ],
            );
          },
        );
      },
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


