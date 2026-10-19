import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chores/app/theme.dart';
import 'package:chores/shared/constants.dart';

/// Weekday header on the Schedule page, highlighted for today.
class DayHeader extends StatelessWidget {
  final int day; // 1=Mon … 7=Sun
  final DateTime date;
  final bool isToday;

  const DayHeader({
    super.key,
    required this.day,
    required this.date,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final color = isToday ? AppColors.primary : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isToday
                  ? AppColors.primary.withAlpha(40)
                  : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                Weekdays.shortName(day).substring(0, 1),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isToday ? AppColors.primary : AppColors.textSecondary,
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
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            DateFormat('MMM d').format(date),
            style: const TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    );
  }
}
