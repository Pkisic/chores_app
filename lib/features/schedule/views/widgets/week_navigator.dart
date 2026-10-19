import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:chores/app/theme.dart';
import 'package:chores/shared/week.dart';

/// Prev / next week switcher with a "back to this week" shortcut.
class WeekNavigator extends StatelessWidget {
  final String weekId;
  final String currentWeekId;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const WeekNavigator({
    super.key,
    required this.weekId,
    required this.currentWeekId,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = weekId == currentWeekId;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
            tooltip: 'Previous week',
            onPressed: () {
              HapticFeedback.selectionClick();
              onPrevious();
            },
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  weekRangeLabel(weekId),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                isCurrent
                    ? const Text(
                        'This week',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : GestureDetector(
                        onTap: onToday,
                        child: const Text(
                          'Back to this week',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.accent,
                          ),
                        ),
                      ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
            tooltip: 'Next week',
            onPressed: () {
              HapticFeedback.selectionClick();
              onNext();
            },
          ),
        ],
      ),
    );
  }
}

/// e.g. `Week 43 · Oct 19 – 25` or `Week 1 · Dec 29 – Jan 4`.
String weekRangeLabel(String weekId) {
  final start = WeekId.startOf(weekId);
  final end = WeekId.dateOf(weekId, 7);
  final startFmt = DateFormat('MMM d').format(start);
  final endFmt = start.month == end.month
      ? DateFormat('d').format(end)
      : DateFormat('MMM d').format(end);
  return 'Week ${WeekId.number(weekId)} · $startFmt – $endFmt';
}
