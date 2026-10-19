import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chores/app/theme.dart';
import 'package:chores/models/models.dart';
import 'package:chores/providers/providers.dart';
import 'package:chores/shared/week.dart';
import 'package:chores/shared/widgets.dart';
import 'package:chores/features/schedule/state/week_board.dart';
import 'package:chores/features/schedule/state/week_providers.dart';
import 'package:chores/features/schedule/views/schedule_form_sheet.dart';
import 'package:chores/features/schedule/views/widgets/day_header.dart';
import 'package:chores/features/schedule/views/widgets/schedule_item_card.dart';
import 'package:chores/features/schedule/views/widgets/week_navigator.dart';

class SchedulePage extends ConsumerWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekId = ref.watch(selectedWeekIdProvider);
    final currentWeekId = ref.watch(currentWeekIdProvider);
    final weekNotifier = ref.read(selectedWeekIdProvider.notifier);
    final boardAsync = ref.watch(weekBoardProvider(weekId));

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'Weekly Schedule'),
          WeekNavigator(
            weekId: weekId,
            currentWeekId: currentWeekId,
            onPrevious: weekNotifier.previous,
            onNext: weekNotifier.next,
            onToday: weekNotifier.goToCurrent,
          ),
          Expanded(
            child: boardAsync.when(
              data: (board) => _WeekView(
                board: board,
                isCurrentWeek: weekId == currentWeekId,
              ),
              loading: () => const LoadingIndicator(),
              error: (e, _) => ErrorDisplay(message: e.toString()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_schedule',
        onPressed: () => openScheduleForm(context, weekId: weekId),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _WeekView extends ConsumerWidget {
  final WeekBoard board;
  final bool isCurrentWeek;

  const _WeekView({required this.board, required this.isCurrentWeek});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (board.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 64, color: AppColors.textHint.withAlpha(100)),
            const SizedBox(height: 16),
            const Text(
              'Nothing scheduled this week.\nTap + to assign a chore!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final today = ref.read(clockProvider)().weekday;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = index + 1;
        final items = board.days[day]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DayHeader(
              day: day,
              date: WeekId.dateOf(board.weekId, day),
              isToday: isCurrentWeek && day == today,
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 62, bottom: 8),
                child: Text(
                  'Nothing scheduled',
                  style: TextStyle(color: AppColors.textHint, fontSize: 13),
                ),
              )
            else
              ...items.map(
                (view) => ScheduleItemCard(
                  view: view,
                  board: board,
                  onEdit: () => openScheduleForm(
                    context,
                    weekId: board.weekId,
                    schedule: view.schedule,
                  ),
                  onDelete: () => _deleteSchedule(ref, view.schedule),
                ),
              ),
            const Divider(indent: 20, endIndent: 20),
          ],
        );
      },
    );
  }

  void _deleteSchedule(WidgetRef ref, ChoreSchedule schedule) {
    final hid = ref.read(householdIdProvider);
    if (hid != null) {
      ref.read(scheduleRepoProvider).deleteSchedule(hid, schedule.id);
    }
  }
}

void openScheduleForm(
  BuildContext context, {
  required String weekId,
  ChoreSchedule? schedule,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ScheduleFormSheet(schedule: schedule, initialWeekId: weekId),
  );
}
