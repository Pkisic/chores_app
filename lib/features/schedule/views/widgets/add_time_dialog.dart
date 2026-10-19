import 'package:flutter/material.dart';
import 'package:chores/app/theme.dart';
import 'package:chores/models/models.dart';
import 'package:chores/shared/duration_picker.dart';
import 'package:chores/shared/format.dart';

/// Result of [AddTimeDialog]: duration in seconds and who did the work.
typedef ManualTimeEntry = ({int seconds, String personId});

/// Dialog for logging manually entered time on an item.
class AddTimeDialog extends StatefulWidget {
  final Chore chore;
  final List<Member> members;
  final String? initialPersonId;

  const AddTimeDialog({
    super.key,
    required this.chore,
    required this.members,
    this.initialPersonId,
  });

  static Future<ManualTimeEntry?> show(
    BuildContext context, {
    required Chore chore,
    required List<Member> members,
    String? initialPersonId,
  }) {
    return showDialog<ManualTimeEntry>(
      context: context,
      builder: (_) => AddTimeDialog(
        chore: chore,
        members: members,
        initialPersonId: initialPersonId,
      ),
    );
  }

  @override
  State<AddTimeDialog> createState() => _AddTimeDialogState();
}

class _AddTimeDialogState extends State<AddTimeDialog> {
  static const _presets = [15 * 60, 30 * 60, 45 * 60, 60 * 60, 90 * 60];

  int _seconds = 15 * 60;
  String? _personId;

  @override
  void initState() {
    super.initState();
    final ids = widget.members.map((m) => m.id);
    _personId = ids.contains(widget.initialPersonId)
        ? widget.initialPersonId
        : (ids.isEmpty ? null : ids.first);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.alarm_add_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Add Time: ${widget.chore.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _presets.map((secs) {
                return ChoiceChip(
                  label: Text(DurationFormat.format(secs)),
                  selected: _seconds == secs,
                  selectedColor: AppColors.primary,
                  onSelected: (_) => setState(() => _seconds = secs),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            DurationPicker(
              seconds: _seconds,
              onChanged: (v) => setState(() => _seconds = v),
            ),
            const SizedBox(height: 16),
            const Text(
              'Done By:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _personId,
              items: widget.members
                  .map((m) =>
                      DropdownMenuItem(value: m.id, child: Text(m.displayName)))
                  .toList(),
              onChanged: (val) => setState(() => _personId = val),
            ),
            const SizedBox(height: 8),
            const Text(
              'Logging time marks this chore as done.',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _personId == null || _seconds <= 0
              ? null
              : () => Navigator.of(context)
                  .pop((seconds: _seconds, personId: _personId!)),
          child: Text('Add ${DurationFormat.format(_seconds)}'),
        ),
      ],
    );
  }
}
