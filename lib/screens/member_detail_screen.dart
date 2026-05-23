import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/member.dart';
import '../models/check_in.dart';
import '../models/session.dart';
import '../utils/expressive_theme.dart';
import '../services/storage_service.dart';

/// 成员详情页面
class MemberDetailScreen extends ConsumerWidget {
  final String memberId;

  const MemberDetailScreen({
    super.key,
    required this.memberId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final member = state.getMemberById(memberId);
    final theme = Theme.of(context);

    if (member == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('成员详情')),
        body: const Center(child: Text('成员不存在')),
      );
    }

    // 获取该成员的出勤记录
    final checkIns = StorageService.getCheckInsForMember(memberId);
    final sessions = StorageService.getAllSessions()
        .where((s) => s.status == 'archived')
        .toList();

    // 统计
    int arrivedCount = 0;
    int absentCount = 0;
    int sickCount = 0;
    int totalSessions = 0;

    for (final session in sessions) {
      if (!session.memberIds.contains(memberId)) continue;
      totalSessions++;

      final sessionCheckIns = checkIns
          .where((c) => c.sessionId == session.id && !c.isUndone)
          .toList();

      if (sessionCheckIns.isNotEmpty) {
        final statusId = sessionCheckIns.first.statusId;
        if (statusId == 'tag_arrived') arrivedCount++;
        else if (statusId == 'tag_absent') absentCount++;
        else if (statusId == 'tag_sick') sickCount++;
      }
    }

    final attendanceRate = totalSessions > 0
        ? (arrivedCount / totalSessions * 100).toStringAsFixed(1)
        : '0.0';

    return Scaffold(
      appBar: AppBar(
        title: Text(member.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '编辑信息',
            onPressed: () => _showEditDialog(context, ref, member),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 基本信息卡片
          _buildInfoCard(theme, member),
          const SizedBox(height: 16),
          // 统计卡片
          _buildStatsCard(
            theme,
            total: totalSessions,
            arrived: arrivedCount,
            absent: absentCount,
            sick: sickCount,
            rate: attendanceRate,
          ),
          const SizedBox(height: 16),
          // 出勤历史
          _buildHistoryList(context, state, checkIns, sessions),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, Member member) {
    return Card(
      elevation: 2,
      shape: ExpressiveShapes.cardMedium,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    member.name.substring(0, 1),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
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
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (member.studentId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '学号：${member.studentId}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (member.birthday != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.cake_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '生日：${member.birthday!.month}月${member.birthday!.day}日',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    _getAgeText(member.birthday!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(
    ThemeData theme, {
    required int total,
    required int arrived,
    required int absent,
    required int sick,
    required String rate,
  }) {
    return Card(
      elevation: 2,
      shape: ExpressiveShapes.cardMedium,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '出勤统计',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(theme, '参与', total, theme.colorScheme.primary),
                _buildStatItem(theme, '出勤', arrived, Colors.green),
                _buildStatItem(theme, '缺勤', absent, Colors.red),
                _buildStatItem(theme, '请假', sick, Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: total > 0 ? arrived / total : 0,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '出勤率：$rate%',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: theme.textTheme.titleLarge?.copyWith(
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

  Widget _buildHistoryList(
    BuildContext context,
    AppState state,
    List<CheckIn> checkIns,
    List<Session> sessions,
  ) {
    final theme = Theme.of(context);

    // 按时间倒序排列
    final sortedSessions = sessions
        .where((s) => s.memberIds.contains(memberId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (sortedSessions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '出勤历史',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...sortedSessions.take(20).map((session) {
          final sessionCheckIns = checkIns
              .where((c) => c.sessionId == session.id && !c.isUndone)
              .toList();

          String statusText = '未标记';
          Color statusColor = Colors.grey;

          if (sessionCheckIns.isNotEmpty) {
            final tag = state.getTagById(sessionCheckIns.first.statusId!);
            if (tag != null) {
              statusText = tag.name;
              statusColor = Color(tag.colorValue);
            }
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor.withOpacity(0.2),
                child: Text(
                  statusText.substring(0, 1),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(session.title),
              subtitle: Text(
                '${session.createdAt.month}月${session.createdAt.day}日',
                style: theme.textTheme.bodySmall,
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              onTap: () {
                // TODO: 跳转到点名详情
              },
            ),
          );
        }),
      ],
    );
  }

  String _getAgeText(DateTime birthday) {
    final now = DateTime.now();
    int age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return '$age岁';
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Member member,
  ) async {
    final nameController = TextEditingController(text: member.name);
    final studentIdController =
        TextEditingController(text: member.studentId ?? '');
    DateTime? selectedBirthday = member.birthday;

    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑成员信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '姓名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: studentIdController,
              decoration: const InputDecoration(
                labelText: '学号（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('生日'),
              subtitle: Text(
                selectedBirthday != null
                    ? '${selectedBirthday!.year}/${selectedBirthday!.month}/${selectedBirthday!.day}'
                    : '未设置',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedBirthday ?? DateTime(2000),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  selectedBirthday = picked;
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updated = member.copyWith(
        name: nameController.text.trim(),
        studentId: studentIdController.text.trim().isEmpty
            ? null
            : studentIdController.text.trim(),
        birthday: selectedBirthday,
      );
      await ref.read(appStateProvider.notifier).updateMember(updated);
    }

    nameController.dispose();
    studentIdController.dispose();
  }
}
