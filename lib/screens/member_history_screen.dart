import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/session.dart';
import '../models/check_in.dart';
import '../models/status_tag.dart';

class MemberHistoryScreen extends ConsumerWidget {
  final String memberId;
  final String memberName;

  const MemberHistoryScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);

    // Get all check-ins for this member
    final allCheckIns = state.getMemberCheckIns(memberId);

    // Build history entries with session info
    final historyEntries = <_HistoryEntry>[];
    for (final ci in allCheckIns) {
      final session = state.getSessionById(ci.sessionId);
      if (session == null) continue;
      final tag = ci.statusId != null ? state.getTagById(ci.statusId!) : null;
      historyEntries.add(_HistoryEntry(
        session: session,
        checkIn: ci,
        tag: tag,
      ));
    }

    // Sort by date descending
    historyEntries.sort((a, b) =>
        b.session.createdAt.compareTo(a.session.createdAt));

    // Calculate statistics
    final statusCounts = state.getMemberStatusCounts(memberId);
    final attendanceRate = state.getMemberAttendanceRate(memberId);
    final totalSessions = allCheckIns.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(memberName),
      ),
      body: Column(
        children: [
          // Statistics summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '出勤统计',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatItem(
                      label: '总次数',
                      value: '$totalSessions',
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 24),
                    _StatItem(
                      label: '出勤率',
                      value: '${(attendanceRate * 100).toStringAsFixed(1)}%',
                      color: attendanceRate >= 0.8
                          ? const Color(0xFF4CAF50)
                          : attendanceRate >= 0.6
                              ? const Color(0xFFFF9800)
                              : const Color(0xFFF44336),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Status breakdown
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: state.tags.map((tag) {
                    final count = statusCounts[tag.id] ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color(tag.colorValue),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${tag.name}: $count',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // History list
          Expanded(
            child: historyEntries.isEmpty
                ? Center(
                    child: Text(
                      '暂无签到记录',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: historyEntries.length,
                    itemBuilder: (context, index) {
                      final entry = historyEntries[index];
                      final dateFormat = DateFormat('yyyy/MM/dd HH:mm');

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 8,
                            height: 40,
                            decoration: BoxDecoration(
                              color: entry.tag != null
                                  ? Color(entry.tag!.colorValue)
                                  : theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          title: Text(entry.session.title),
                          subtitle: Text(dateFormat.format(entry.session.createdAt)),
                          trailing: entry.tag != null
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(entry.tag!.colorValue),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    entry.tag!.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : Text(
                                  '未标记',
                                  style: TextStyle(
                                    color:
                                        theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntry {
  final Session session;
  final CheckIn checkIn;
  final StatusTag? tag;

  _HistoryEntry({
    required this.session,
    required this.checkIn,
    this.tag,
  });
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
