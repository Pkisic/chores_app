import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chores/app/theme.dart';
import 'package:chores/models/models.dart';
import 'package:chores/shared/constants.dart';
import 'package:chores/shared/duration_picker.dart';
import 'package:chores/shared/format.dart';
import 'package:chores/shared/week.dart';
import 'package:chores/features/schedule/state/timer_controller.dart';
import 'package:chores/features/schedule/state/week_board.dart';
import 'package:chores/features/schedule/state/week_providers.dart';

/// One time-log session with edit / delete actions (any member may fix any
/// session). Running sessions can't be edited until paused.
class SessionRow extends ConsumerWidget {
  final TimeLog log;
  final String personName;

  const SessionRow({super.key, required this.log, required this.personName});

  static final _timeFmt = DateFormat('h:mm a');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manual = log.source == TimeLogSource.manual;
    final when = _timeFmt.format(log.startedAt.toDate());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  personName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  manual ? 'manual · $when' : when,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          Text(
            log.isRunning
                ? 'running'
                : DurationFormat.format(log.durationSeconds ?? 0),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: log.isRunning
                  ? AppColors.primaryLight
                  : AppColors.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppColors.textHint,
            tooltip: log.isRunning ? 'Pause the timer to edit' : 'Edit time',
            visualDensity: VisualDensity.compact,
            onPressed:
                log.isRunning ? null : () => _editDuration(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            color: AppColors.error,
            tooltip: 'Delete session',
            visualDensity: VisualDensity.compact,
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _editDuration(BuildContext context, WidgetRef ref) async {
    final seconds = await showDialog<int>(
      context: context,
      builder: (_) =>
          _EditDurationDialog(currentSeconds: log.durationSeconds ?? 0),
    );
    if (seconds == null || !context.mounted) return;
    await _run(
      context,
      () => ref.read(timerControllerProvider).editDuration(log, seconds: seconds),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete session?'),
        content: Text(
          log.isRunning
              ? "This stops $personName's running timer and discards it."
              : 'Removes ${DurationFormat.format(log.durationSeconds ?? 0)} '
                  'logged by $personName.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(context, () => ref.read(timerControllerProvider).deleteLog(log));
  }
}

Future<void> _run(BuildContext context, Future<void> Function() action) async {
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

enum DurationEditMode { set, subtract, add }

/// Resulting duration in seconds, or null when it would be zero or less
/// (delete the session instead).
int? applyDurationEdit(
  DurationEditMode mode,
  int currentSeconds,
  int amountSeconds,
) {
  final result = switch (mode) {
    DurationEditMode.set => amountSeconds,
    DurationEditMode.subtract => currentSeconds - amountSeconds,
    DurationEditMode.add => currentSeconds + amountSeconds,
  };
  return result > 0 ? result : null;
}

class _EditDurationDialog extends StatefulWidget {
  final int currentSeconds;

  const _EditDurationDialog({required this.currentSeconds});

  @override
  State<_EditDurationDialog> createState() => _EditDurationDialogState();
}

class _EditDurationDialogState extends State<_EditDurationDialog> {
  DurationEditMode _mode = DurationEditMode.set;
  late int _amount = widget.currentSeconds;

  int? get _result => applyDurationEdit(_mode, widget.currentSeconds, _amount);

  void _setMode(DurationEditMode mode) {
    setState(() {
      _mode = mode;
      _amount = mode == DurationEditMode.set ? widget.currentSeconds : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = DurationFormat.format(widget.currentSeconds);
    final result = _result;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit time'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<DurationEditMode>(
              segments: const [
                ButtonSegment(value: DurationEditMode.set, label: Text('Set')),
                ButtonSegment(
                    value: DurationEditMode.subtract, label: Text('Subtract')),
                ButtonSegment(value: DurationEditMode.add, label: Text('Add')),
              ],
              selected: {_mode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => _setMode(selection.first),
            ),
            const SizedBox(height: 16),
            DurationPicker(
              seconds: _amount,
              onChanged: (v) => setState(() => _amount = v),
            ),
            const SizedBox(height: 16),
            Text(
              result == null
                  ? 'Must stay above 0s. Delete the session instead.'
                  : '$current → ${DurationFormat.format(result)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: result == null ? AppColors.error : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: result == null || result == widget.currentSeconds
              ? null
              : () => Navigator.pop(context, result),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Bottom sheet listing every session of one schedule item. Watches the
/// week board so it updates live after edits.
class SessionsSheet extends ConsumerWidget {
  final String weekId;
  final String itemId;

  const SessionsSheet({super.key, required this.weekId, required this.itemId});

  static Future<void> show(BuildContext context, ScheduleItemView view) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SessionsSheet(weekId: view.slot.weekId, itemId: view.slot.itemId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(weekBoardProvider(weekId)).valueOrNull;
    ScheduleItemView? view;
    for (final items in board?.days.values ?? const <List<ScheduleItemView>>[]) {
      for (final v in items) {
        if (v.slot.itemId == itemId) view = v;
      }
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 24),
      child: view == null
          ? const SizedBox(height: 120)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textHint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      ChoreIcons.fromKey(view.chore.icon),
                      color: ChoreColors.fromHex(view.chore.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${view.chore.name} · ${DateFormat('EEE, MMM d').format(WeekId.dateOf(weekId, view.slot.day))}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (view.logs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No time logged yet.',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: view.logs
                          .map((log) => SessionRow(
                                log: log,
                                personName: board!.nameOf(log.personId) ?? '?',
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
    );
  }
}
