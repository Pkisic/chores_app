import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chores/app/theme.dart';
import 'package:chores/models/models.dart';
import 'package:chores/providers/providers.dart';
import 'package:chores/shared/constants.dart';

/// Bottom sheet form for creating / editing a chore.
class ChoreFormSheet extends ConsumerStatefulWidget {
  final Chore? chore; // null = create mode

  const ChoreFormSheet({super.key, this.chore});

  @override
  ConsumerState<ChoreFormSheet> createState() => _ChoreFormSheetState();
}

class _ChoreFormSheetState extends ConsumerState<ChoreFormSheet> {
  late final TextEditingController _nameController;
  late String _selectedColor;
  late String _selectedIcon;
  late int _durationEstimate;
  bool _saving = false;

  bool get _isEditing => widget.chore != null;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.chore?.name ?? '');
    _selectedColor =
        widget.chore?.color ?? ChoreColors.palette.first;
    _selectedIcon = widget.chore?.icon ?? 'clean';
    _durationEstimate = widget.chore?.durationEstimate ?? 15;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);

    final hid = ref.read(householdIdProvider);
    if (hid == null) return;
    final repo = ref.read(choreRepoProvider);

    final chore = Chore(
      id: widget.chore?.id ?? '',
      name: name,
      color: _selectedColor,
      icon: _selectedIcon,
      durationEstimate: _durationEstimate,
    );

    if (_isEditing) {
      await repo.updateChore(hid, chore);
    } else {
      await repo.addChore(hid, chore);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
            // ── Handle ─────────────────────────────────────
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
              _isEditing ? 'Edit Chore' : 'New Chore',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // ── Name ───────────────────────────────────────
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(hintText: 'Chore name'),
              style: const TextStyle(color: AppColors.textPrimary),
              textCapitalization: TextCapitalization.sentences,
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 20),

            // ── Duration ───────────────────────────────────
            const Text('Estimated duration',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _durationEstimate.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.surfaceLight,
                    onChanged: (v) =>
                        setState(() => _durationEstimate = v.round()),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_durationEstimate min',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Colour picker ──────────────────────────────
            const Text('Colour',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ChoreColors.palette.map((hex) {
                final selected = hex == _selectedColor;
                final color = ChoreColors.fromHex(hex);
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: Colors.white, width: 2.5)
                          : null,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: color.withAlpha(120),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Icon picker ────────────────────────────────
            const Text('Icon',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ChoreIcons.all.entries.map((entry) {
                final selected = entry.key == _selectedIcon;
                final accentColor = ChoreColors.fromHex(_selectedColor);
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedIcon = entry.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? accentColor.withAlpha(50)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: accentColor, width: 1.5)
                          : null,
                    ),
                    child: Icon(
                      entry.value,
                      size: 22,
                      color: selected
                          ? accentColor
                          : AppColors.textHint,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Save button ────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
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
                        _isEditing ? 'Save Changes' : 'Add Chore',
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
