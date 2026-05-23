import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/session.dart';
import '../models/check_in.dart';
import '../models/member.dart';
import '../models/status_tag.dart';
import '../utils/expressive_theme.dart';

/// 点名详情页面
class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;

  const SessionDetailScreen({
    super.key,
    required this.sessionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final session = state.getSessionById(sessionId);
    final theme = Theme.of(context);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('点名详情')),
        body: const Center(child: Text('点名记录不存在')),
      );
    }

    final checkIns = state.getSessionCheckIns(sessionId);
    final members = session.memberIds
        .map((id) => state.getMemberById(id))
        .where((m) => m != null)
        .cast<Member>()
        .toList();

    // 统计
    final arrivedCount = checkIns.where((c) => c.statusId == 'tag_arrived' && !c.isUndone).length;
    final absentCount = checkIns.where((c) => c.statusId == 'tag_absent' && !c.isUndone).length;
    final sickCount = checkIns.where((c) => c.statusId == 'tag_sick' && !c.isUndone).length;
    final uncheckedCount = members.length - arrivedCount - absentCount - sickCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(session.title),
        actions: [
          if (session.status == 'archived')
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: '恢复点名',
              onPressed: () => _showRestoreDialog(context, ref, session),
            ),
        ],
      ),
      body: Column(
        children: [
          // 统计卡片
          _buildStatsCard(
            theme,
            total: members.length,
            arrived: arrivedCount,
            absent: absentCount,
            sick: sickCount,
            unchecked: uncheckedCount,
          ),
          // 时间信息
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Text(
                  '开始：${_formatDateTime(session.createdAt)}',
                  style: theme.textTheme.bodySmall,
                ),
                if (session.endedAt != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.done_all, size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 8),
                  Text(
                    '结束：${_formatDateTime(session.endedAt!)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          // 成员列表
          Expanded(
            child: _buildMemberList(context, state, members, checkIns),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(
    ThemeData theme, {
    required int total,
    required int arrived,
    required int absent,
    required int sick,
    required int unchecked,
  }) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: ExpressiveShapes.cardMedium,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(theme, '总人数', total, theme.colorScheme.primary),
                _buildStatItem(theme, '出勤', arrived, Colors.green),
                _buildStatItem(theme, '缺勤', absent, Colors.red),
                _buildStatItem(theme, '请假', sick, Colors.orange),
                _buildStatItem(theme, '未标记', unchecked, Colors.grey),
              ],
            ),
            const SizedBox(height: 12),
            // 出勤率
            LinearProgressIndicator(
              value: total > 0 ? arrived / total : 0,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '出勤率：${total > 0 ? (arrived / total * 100).toStringAsFixed(1) : 0}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(ThemeData theme, String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMemberList(
    BuildContext context,
    AppState state,
    List<Member> members,
    List<CheckIn> checkIns,
  ) {
    final theme = Theme.of(context);

    // 按状态分组
    final memberStatus = <Member, StatusTag?>{for (var m in members) m: null};
    for (final checkIn in checkIns) {
      if (checkIn.isUndone) continue;
      final member = state.getMemberById(checkIn.memberId);
      if (member != null) {
        memberStatus[member] = state.getTagById(checkIn.statusId);
      }
    }

    // 排序：未标记在前，然后按状态
    final sortedMembers = members.toList()
      ..sort((a, b) {
        final statusA = memberStatus[a];
        final statusB = memberStatus[b];
        if (statusA == null && statusB != null) return -1;
        if (statusA != null && statusB == null) return 1;
        return a.name.compareTo(b.name);
      });

    return ListView.builder(
      itemCount: sortedMembers.length,
      itemBuilder: (context, index) {
        final member = sortedMembers[index];
        final tag = memberStatus[member];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: tag != null
                ? Color(tag.colorValue).withOpacity(0.2)
                : theme.colorScheme.surfaceContainerHighest,
            child: Text(
              member.name.substring(0, 1),
              style: TextStyle(
                color: tag != null ? Color(tag.colorValue) : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(member.name),
          subtitle: member.studentId != null ? Text(member.studentId!) : null,
          trailing: tag != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(tag.colorValue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(tag.colorValue)),
                  ),
                  child: Text(
                    tag.name,
                    style: TextStyle(
                      color: Color(tag.colorValue),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Text(
                  '未标记',
                  style: TextStyle(
                    color: theme.colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showRestoreDialog(
    BuildContext context,
    WidgetRef ref,
    Session session,
  ) async {
    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复点名'),
        content: const Text('将此点名恢复为进行中状态？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(appStateProvider.notifier).restoreSession(session.id);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}
