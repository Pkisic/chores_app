import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chores/app/theme.dart';
import 'package:chores/models/models.dart';
import 'package:chores/providers/providers.dart';
import 'package:chores/shared/constants.dart';
import 'package:chores/shared/widgets.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(completedLogsProvider);
    final choresAsync = ref.watch(choresProvider);
    final membersAsync = ref.watch(membersProvider);

    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(title: 'History'),
          Expanded(
            child: logsAsync.when(
              data: (logs) => choresAsync.when(
                data: (chores) => membersAsync.when(
                  data: (members) =>
                      _buildHistory(context, logs, chores, members),
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
    );
  }

  Widget _buildHistory(
    BuildContext context,
    List<TimeLog> logs,
    List<Chore> chores,
    List<Member> members,
  ) {
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history,
                size: 64, color: AppColors.textHint.withAlpha(100)),
            const SizedBox(height: 16),
            const Text(
              'No completed chores yet.\nStart a timer to log your first!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final choreMap = {for (final c in chores) c.id: c};
    final memberMap = {for (final m in members) m.id: m};
    final dateFmt = DateFormat('EEEE, MMM d');
    final timeFmt = DateFormat('h:mm a');

    // Group logs by date
    final Map<String, List<TimeLog>> grouped = {};
    for (final log in logs) {
      final dateKey = dateFmt.format(log.startedAt.toDate());
      grouped.putIfAbsent(dateKey, () => []).add(log);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: grouped.length,
      itemBuilder: (_, i) {
        final dateKey = grouped.keys.elementAt(i);
        final dayLogs = grouped[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                dateKey,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ...dayLogs.map((log) {
              final chore = choreMap[log.choreId];
              final member = memberMap[log.personId];
              if (chore == null) return const SizedBox.shrink();
              final color = ChoreColors.fromHex(chore.color);

              return GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        ChoreIcons.fromKey(chore.icon),
                        color: color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chore.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (member != null) ...[
                                Icon(Icons.person_outline,
                                    size: 13,
                                    color: AppColors.textHint),
                                const SizedBox(width: 3),
                                Text(
                                  member.displayName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                              ],
                              Icon(Icons.access_time,
                                  size: 13, color: AppColors.textHint),
                              const SizedBox(width: 3),
                              Text(
                                timeFmt.format(log.startedAt.toDate()),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (log.durationSeconds != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _formatDuration(log.durationSeconds!),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}
