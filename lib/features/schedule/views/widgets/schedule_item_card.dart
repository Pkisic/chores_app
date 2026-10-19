import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chores/app/theme.dart';
import 'package:chores/models/models.dart';
import 'package:chores/providers/providers.dart';
import 'package:chores/shared/constants.dart';
import 'package:chores/features/schedule/state/timer_controller.dart';
import 'package:chores/features/schedule/state/week_board.dart';
import 'package:chores/features/schedule/views/widgets/add_time_dialog.dart';
import 'package:chores/features/schedule/views/widgets/elapsed_text.dart';
import 'package:chores/features/schedule/views/widgets/session_editing.dart';

/// One scheduled item (chore × day × week) with its timer and done state.
///
/// States: open · running (mine) · in progress by others · paused (has time)
/// · done. Tapping the card starts/pauses my timer.
class ScheduleItemCard extends ConsumerWidget {
  final ScheduleItemView view;
  final WeekBoard board;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ScheduleItemCard({
    super.key,
    required this.view,
    required this.board,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentMemberIdProvider);
    final controller = ref.read(timerControllerProvider);
    final color = ChoreColors.fromHex(view.chore.color);

    final mineRunning = view.isRunningFor(me);
    final others = view.runningByOthers(me);
    final highlighted = view.hasTime || view.isDone;
    final accent = view.isDone ? AppColors.success : color;

    Future<void> run(Future<void> Function() action) async {
      HapticFeedback.lightImpact();
      try {
        await action();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
        }
      }
    }

    Future<void> addTime() async {
      final members = board.members.values.toList();
      final entry = await AddTimeDialog.show(
        context,
        chore: view.chore,
        members: members,
        initialPersonId: me ?? view.slot.assignedPersonId,
      );
      if (entry == null) return;
      await run(() => controller.addManual(
            view.slot,
            personId: entry.personId,
            seconds: entry.seconds,
          ));
    }

    void onTap() {
      if (view.isDone) return;
      if (mineRunning) {
        run(() => controller.pause(view.slot));
      } else {
        run(() => controller.start(view.slot));
      }
    }

    final textColor = highlighted ? Colors.white : AppColors.textPrimary;
    final subColor = highlighted ? Colors.white70 : AppColors.textSecondary;

    return Dismissible(
      key: ValueKey(view.slot.itemId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(60),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: highlighted ? accent.withAlpha(45) : AppColors.card.withAlpha(200),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted ? accent : color.withAlpha(60),
            width: highlighted ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: highlighted ? accent.withAlpha(70) : Colors.black.withAlpha(40),
              blurRadius: highlighted ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      _ChoreIcon(
                        icon: ChoreIcons.fromKey(view.chore.icon),
                        color: color,
                        highlighted: highlighted,
                        done: view.isDone,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    view.chore.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                      decoration: view.isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor: Colors.white70,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _Tag(
                                  label: view.schedule.recurring ? '↻' : 'once',
                                  color: AppColors.accent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.person_outline, size: 13, color: subColor),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    board.nameOf(view.slot.assignedPersonId) ?? '—',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12, color: subColor),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  flex: 2,
                                  child: Text(
                                    _statusText(mineRunning, others),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _statusColor(mineRunning, others),
                                      fontWeight: view.isRunning || view.isDone
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.alarm_add_rounded,
                          size: 20,
                          color: highlighted ? Colors.white : color,
                        ),
                        tooltip: 'Add custom time',
                        onPressed: addTime,
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: highlighted ? Colors.white70 : AppColors.textHint,
                        ),
                        tooltip: 'Edit schedule',
                        onPressed: onEdit,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  if (highlighted) ...[
                    const SizedBox(height: 10),
                    Divider(height: 1, color: Colors.white.withAlpha(50)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Tap the time to see, edit or delete sessions.
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => SessionsSheet.show(context, view),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                            child: Row(
                              children: [
                                Icon(
                                  view.isRunning
                                      ? Icons.timer
                                      : Icons.timer_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                ElapsedText(
                                  view: view,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.expand_more,
                                    size: 16, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _Contributors(view: view, board: board)),
                        ..._actions(
                          mineRunning: mineRunning,
                          onRun: run,
                          controller: controller,
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
  }

  List<Widget> _actions({
    required bool mineRunning,
    required Future<void> Function(Future<void> Function()) onRun,
    required TimerController controller,
  }) {
    if (view.isDone) {
      return [
        IconButton(
          icon: const Icon(Icons.undo_rounded, color: Colors.white),
          tooltip: 'Reopen',
          onPressed: () => onRun(() => controller.reopen(view.slot)),
        ),
      ];
    }
    return [
      IconButton(
        icon: Icon(
          mineRunning ? Icons.pause_circle_filled : Icons.play_circle_filled,
          color: Colors.white,
          size: 30,
        ),
        tooltip: mineRunning ? 'Pause' : 'Start my timer',
        onPressed: () => onRun(() => mineRunning
            ? controller.pause(view.slot)
            : controller.start(view.slot)),
      ),
      IconButton(
        icon: const Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 30),
        tooltip: 'Stop & Complete',
        onPressed: () => onRun(() => controller.complete(view.slot)),
      ),
    ];
  }

  String _statusText(bool mineRunning, List<TimeLog> others) {
    if (view.isDone) {
      final by = board.nameOf(view.completedBy);
      return by == null ? '• Done' : '• Done by $by';
    }
    if (mineRunning) return '• Running…';
    if (others.isNotEmpty) {
      final names = others.map((l) => board.nameOf(l.personId) ?? '?').toSet();
      return '• In progress by ${names.join(', ')}';
    }
    if (view.loggedSeconds > 0) return '• Paused · tap to resume';
    return '• Tap to start';
  }

  Color _statusColor(bool mineRunning, List<TimeLog> others) {
    if (view.isDone) return Colors.white;
    if (mineRunning) return AppColors.primaryLight;
    if (others.isNotEmpty) return AppColors.accentLight;
    if (view.hasTime) return Colors.white60;
    return AppColors.textHint;
  }
}

class _ChoreIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool highlighted;
  final bool done;

  const _ChoreIcon({
    required this.icon,
    required this.color,
    required this.highlighted,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: done
            ? AppColors.success.withAlpha(110)
            : color.withAlpha(highlighted ? 110 : 35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted ? (done ? AppColors.success : color) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Icon(
        done ? Icons.check_rounded : icon,
        color: highlighted ? Colors.white : color,
        size: 22,
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

/// Small chips naming everyone who logged time or is timing right now.
class _Contributors extends StatelessWidget {
  final ScheduleItemView view;
  final WeekBoard board;

  const _Contributors({required this.view, required this.board});

  @override
  Widget build(BuildContext context) {
    final ids = {
      ...view.secondsByPerson.keys,
      ...view.runningLogs.map((l) => l.personId),
    };
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: ids.map((id) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(40),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person, size: 11, color: Colors.white),
              const SizedBox(width: 3),
              Text(
                board.nameOf(id) ?? '?',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
