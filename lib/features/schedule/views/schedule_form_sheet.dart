import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chores/app/theme.dart';
import 'package:chores/models/models.dart';
import 'package:chores/providers/providers.dart';
import 'package:chores/shared/constants.dart';

/// Bottom sheet for creating / editing a schedule entry.
class ScheduleFormSheet extends ConsumerStatefulWidget {
  final ChoreSchedule? schedule;

  const ScheduleFormSheet({super.key, this.schedule});

  @override
  ConsumerState<ScheduleFormSheet> createState() => _ScheduleFormSheetState();
}

class _ScheduleFormSheetState extends ConsumerState<ScheduleFormSheet> {
  String? _selectedChoreId;
  String? _selectedPersonId;
  Set<int> _selectedDays = {};
  bool _recurring = true;
  bool _saving = false;

  bool get _isEditing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _selectedChoreId = widget.schedule!.choreId;
      _selectedPersonId = widget.schedule!.personId;
      _selectedDays = widget.schedule!.days.toSet();
      _recurring = widget.schedule!.recurring;
    }
  }

  Future<void> _save() async {
    if (_selectedChoreId == null ||
        _selectedPersonId == null ||
        _selectedDays.isEmpty) {
      return;
    }

    setState(() {
      _saving = true;
    });
    final hid = ref.read(householdIdProvider);
    if (hid == null) return;

    final repo = ref.read(scheduleRepoProvider);
    final schedule = ChoreSchedule(
      id: widget.schedule?.id ?? '',
      choreId: _selectedChoreId!,
      personId: _selectedPersonId!,
      days: _selectedDays.toList()..sort(),
      recurring: _recurring,
    );

    if (_isEditing) {
      await repo.updateSchedule(hid, schedule);
    } else {
      await repo.addSchedule(hid, schedule);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final choresAsync = ref.watch(choresProvider);
    final membersAsync = ref.watch(membersProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
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
            Text(
              _isEditing ? 'Edit Schedule' : 'New Schedule Entry',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // ── Chore selector ─────────────────────────────
            const Text('Chore',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            choresAsync.when(
              data: (chores) {
                if (chores.isEmpty) {
                  return const Text(
                    'Add chores first!',
                    style: TextStyle(color: AppColors.textHint),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chores.map((chore) {
                    final selected = _selectedChoreId == chore.id;
                    final color = ChoreColors.fromHex(chore.color);
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(ChoreIcons.fromKey(chore.icon),
                              size: 16,
                              color: selected ? color : AppColors.textHint),
                          const SizedBox(width: 6),
                          Text(chore.name),
                        ],
                      ),
                      selected: selected,
                      selectedColor: color.withAlpha(40),
                      onSelected: (_) =>
                          setState(() => _selectedChoreId = chore.id),
                      side: selected
                          ? BorderSide(color: color, width: 1)
                          : BorderSide.none,
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text(e.toString()),
            ),
            const SizedBox(height: 20),

            // ── Person selector ────────────────────────────
            const Text('Person',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            membersAsync.when(
              data: (members) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: members.map((member) {
                  final selected = _selectedPersonId == member.id;
                  return ChoiceChip(
                    label: Text(member.displayName),
                    selected: selected,
                    selectedColor: AppColors.accent.withAlpha(40),
                    onSelected: (_) =>
                        setState(() => _selectedPersonId = member.id),
                    side: selected
                        ? const BorderSide(
                            color: AppColors.accent, width: 1)
                        : BorderSide.none,
                  );
                }).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text(e.toString()),
            ),
            const SizedBox(height: 20),

            // ── Day selector ───────────────────────────────
            const Text('Days',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = i + 1;
                final selected = _selectedDays.contains(day);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedDays.remove(day);
                      } else {
                        _selectedDays.add(day);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(
                              color: AppColors.primaryLight, width: 1.5)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        Weekdays.shortName(day).substring(0, 1),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : AppColors.textHint,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // ── Recurring toggle ───────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Recurring weekly',
                    style: TextStyle(color: AppColors.textPrimary)),
                subtitle: const Text('Repeats every week',
                    style:
                        TextStyle(color: AppColors.textHint, fontSize: 12)),
                value: _recurring,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _recurring = v),
              ),
            ),
            const SizedBox(height: 24),

            // ── Save button ────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_selectedChoreId != null &&
                        _selectedPersonId != null &&
                        _selectedDays.isNotEmpty &&
                        !_saving)
                    ? _save
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.surfaceLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Save Changes' : 'Add to Schedule',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
