import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chores/providers/providers.dart';
import 'package:chores/shared/format.dart';
import 'package:chores/features/schedule/state/week_board.dart';
import 'package:chores/features/schedule/state/week_providers.dart';

/// Total time on an item. Ticks every second only while a session runs.
class ElapsedText extends ConsumerWidget {
  final ScheduleItemView view;
  final TextStyle? style;

  const ElapsedText({super.key, required this.view, this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (view.isRunning) ref.watch(tickProvider);
    final now = ref.read(clockProvider)();
    return Text(
      DurationFormat.format(view.elapsedAt(now)),
      style: (style ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
