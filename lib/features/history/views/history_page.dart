import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:chores/app/theme.dart';
import 'package:chores/models/models.dart';
import 'package:chores/providers/providers.dart';
import 'package:chores/shared/constants.dart';
import 'package:chores/shared/format.dart';
import 'package:chores/shared/widgets.dart';
import 'package:chores/features/history/state/history_groups.dart';
import 'package:chores/features/schedule/views/widgets/session_editing.dart';

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
                  data: (members) => _buildHistory(logs, chores, members),
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
    List<TimeLog> logs,
    List<Chore> chores,
    List<Member> members,
  ) {
    final days = groupHistory(logs);
    if (days.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: days.length,
      itemBuilder: (_, i) {
        final day = days[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                dateFmt.format(day.date),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ...day.entries.map((entry) {
              final chore = choreMap[entry.choreId];
              if (chore == null) return const SizedBox.shrink();
              return _HistoryEntryCard(
                entry: entry,
                chore: chore,
                memberMap: memberMap,
              );
            }),
          ],
        );
      },
    );
  }
}

/// One item with its total time; expands to show the individual sessions.
class _HistoryEntryCard extends StatefulWidget {
  final HistoryEntry entry;
  final Chore chore;
  final Map<String, Member> memberMap;

  const _HistoryEntryCard({
    required this.entry,
    required this.chore,
    required this.memberMap,
  });

  @override
  State<_HistoryEntryCard> createState() => _HistoryEntryCardState();
}

class _HistoryEntryCardState extends State<_HistoryEntryCard> {
  bool _expanded = false;

  String _name(String id) => widget.memberMap[id]?.displayName ?? '?';

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final color = ChoreColors.fromHex(widget.chore.color);
    final people = entry.secondsByPerson.keys.map(_name).join(', ');
    final sessionCount = entry.sessions.length;

    return GlassCard(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(ChoreIcons.fromKey(widget.chore.icon),
                    color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chore.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 13, color: AppColors.textHint),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            people,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          sessionCount == 1 ? '1 session' : '$sessionCount sessions',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _DurationPill(seconds: entry.totalSeconds),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: AppColors.textHint,
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8, left: 56),
                    child: Column(
                      children: entry.sessions
                          .map((log) =>
                              SessionRow(log: log, personName: _name(log.personId)))
                          .toList(),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _DurationPill extends StatelessWidget {
  final int seconds;

  const _DurationPill({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        DurationFormat.format(seconds),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          fontSize: 13,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
