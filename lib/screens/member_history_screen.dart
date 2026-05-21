import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/session.dart';
import '../models/check_in.dart';
import '../models/status_tag.dart';
import '../utils/constants.dart';

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
    final member = state.getMemberById(memberId);

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
        title: Column(
          children: [
            Hero(
              tag: 'memberName_$memberId',
              child: Material(
                type: MaterialType.transparency,
                child: Text(
                  memberName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (member?.studentId != null)
              Hero(
                tag: 'studentId_$memberId',
                child: Material(
                  type: MaterialType.transparency,
                  child: Text(
                    member!.studentId!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          // Header
          if (member != null)
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: theme.colorScheme.primary,
                          child: Text(
                            member.name.isNotEmpty ? member.name[0] : '?',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.name,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              if (member.studentId != null)
                                Text(
                                  member.studentId!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme
                                        .colorScheme.onPrimaryContainer
                                        .withOpacity(0.8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _StatItem(
                          label: '总次数',
                          value: '$totalSessions',
                          color: theme.colorScheme.onPrimaryContainer,
                          theme: theme,
                        ),
                        const SizedBox(width: 24),
                        _StatItem(
                          label: '出勤率',
                          value: '${(attendanceRate * 100).toStringAsFixed(1)}%',
                          color: attendanceRate >= 0.8
                              ? AppColors.success
                              : attendanceRate >= 0.6
                                  ? AppColors.warning
                                  : AppColors.error,
                          theme: theme,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Status breakdown
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: state.tags.map((tag) {
                        final count = statusCounts[tag.id] ?? 0;
                        if (count == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(tag.colorValue).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Color(tag.colorValue),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Color(tag.colorValue),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${tag.name}: $count',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Color(tag.colorValue),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

          // History list
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '历史记录',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (historyEntries.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    '暂无签到记录',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.separated(
                itemCount: historyEntries.length,
                itemBuilder: (context, index) {
                  final entry = historyEntries[index];
                  final dateFormat = DateFormat('yyyy年MM月dd日 HH:mm');
                  final tagColor = entry.tag != null
                      ? Color(entry.tag!.colorValue)
                      : theme.colorScheme.onSurfaceVariant;

                  return _TimelineItem(
                    isFirst: index == 0,
                    isLast: index == historyEntries.length - 1,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.session.title,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dateFormat.format(
                                          entry.session.createdAt,
                                        ),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  theme.colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (entry.tag != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: tagColor,
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
                                  ),
                              ],
                            ),
                            if (entry.checkIn.note != null &&
                                entry.checkIn.note!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.note_outlined,
                                        size: 16,
                                        color: theme
                                            .colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          entry.checkIn.note!,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 8),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
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
  final ThemeData theme;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
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

class _TimelineItem extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final Widget child;

  const _TimelineItem({
    required this.isFirst,
    required this.isLast,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
