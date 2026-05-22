import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/member.dart';

/// 生日数据模型
class _BirthdayItem {
  final Member member;
  final DateTime birthdayThisYear;
  final int daysUntil;
  final bool isThisWeek;

  _BirthdayItem({
    required this.member,
    required this.birthdayThisYear,
    required this.daysUntil,
    required this.isThisWeek,
  });
}

class BirthdayScreen extends ConsumerWidget {
  const BirthdayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final members = state.members.where((m) => m.birthday != null).toList();

    // 构建生日列表（最近一年）
    final birthdayItems = _buildBirthdayList(members);

    // 分离本周和其他的
    final thisWeekItems = birthdayItems.where((b) => b.isThisWeek).toList();
    final otherItems = birthdayItems.where((b) => !b.isThisWeek).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('生日提醒'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (state.members.any((m) => m.birthday == null))
            TextButton(
              onPressed: () => _showAutoParseDialog(context, ref),
              child: const Text('自动识别'),
            ),
        ],
      ),
      body: members.isEmpty
          ? _buildEmptyState(theme)
          : CustomScrollView(
              slivers: [
                // 本周生日（着重显示）
                if (thisWeekItems.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildThisWeekSection(theme, thisWeekItems),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
                // 时间轴列表
                SliverToBoxAdapter(
                  child: _buildTimeline(theme, otherItems),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  List<_BirthdayItem> _buildBirthdayList(List<Member> members) {
    final now = DateTime.now();
    final items = <_BirthdayItem>[];

    for (final member in members) {
      final birthday = member.birthday!;
      
      // 计算今年的生日
      var birthdayThisYear = DateTime(now.year, birthday.month, birthday.day);
      
      // 如果今年生日已过，算明年的
      if (birthdayThisYear.isBefore(DateTime(now.year, now.month, now.day))) {
        birthdayThisYear = DateTime(now.year + 1, birthday.month, birthday.day);
      }
      
      final daysUntil = birthdayThisYear.difference(DateTime(now.year, now.month, now.day)).inDays;
      
      // 只保留最近一年的
      if (daysUntil <= 365) {
        items.add(_BirthdayItem(
          member: member,
          birthdayThisYear: birthdayThisYear,
          daysUntil: daysUntil,
          isThisWeek: daysUntil <= 7,
        ));
      }
    }

    // 按天数排序
    items.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return items;
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cake_outlined,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无生日信息',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在人员管理中补充生日信息',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThisWeekSection(ThemeData theme, List<_BirthdayItem> items) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.6),
            theme.colorScheme.tertiaryContainer.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.celebration,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '本周生日',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}人',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => _buildThisWeekItem(theme, item)),
        ],
      ),
    );
  }

  Widget _buildThisWeekItem(ThemeData theme, _BirthdayItem item) {
    final isToday = item.daysUntil == 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isToday
            ? theme.colorScheme.primary.withOpacity(0.15)
            : theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: isToday
            ? Border.all(color: theme.colorScheme.primary.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isToday
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            child: Text(
              item.member.name.substring(0, 1),
              style: TextStyle(
                color: isToday
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.member.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item.birthdayThisYear.month}月${item.birthdayThisYear.day}日 · 满${_calculateAge(item.member.birthday!, item.birthdayThisYear)}岁',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isToday
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              isToday ? '今天!' : '${item.daysUntil}天后',
              style: TextStyle(
                color: isToday
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(ThemeData theme, List<_BirthdayItem> items) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // 按月份分组
    final grouped = <String, List<_BirthdayItem>>{};
    for (final item in items) {
      final key = '${item.birthdayThisYear.year}年${item.birthdayThisYear.month}月';
      grouped.putIfAbsent(key, () => []).add(item);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '未来一年',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...grouped.entries.map((entry) => _buildMonthGroup(theme, entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildMonthGroup(ThemeData theme, String monthLabel, List<_BirthdayItem> items) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 时间轴
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: items.length * 60.0,
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
            ),
          ],
        ),
        const SizedBox(width: 12),
        // 内容
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 月份标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  monthLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 成员列表
              ...items.map((item) => _buildTimelineItem(theme, item)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(ThemeData theme, _BirthdayItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Text(
              item.member.name.substring(0, 1),
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.member.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item.birthdayThisYear.day}日 · 满${_calculateAge(item.member.birthday!, item.birthdayThisYear)}岁',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.daysUntil}天',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _calculateAge(DateTime birthday, DateTime targetDate) {
    var age = targetDate.year - birthday.year;
    if (targetDate.month < birthday.month ||
        (targetDate.month == birthday.month && targetDate.day < birthday.day)) {
      age--;
    }
    return age;
  }

  /// 显示自动识别对话框
  void _showAutoParseDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.read(appStateProvider);
    final membersWithoutBirthday = state.members.where((m) => m.birthday == null).toList();

    int parsedCount = 0;
    for (final member in membersWithoutBirthday) {
      if (member.studentId != null) {
        final birthday = Member.parseBirthdayFromIdCard(member.studentId!);
        if (birthday != null) {
          state.updateMember(member.copyWith(birthday: birthday));
          parsedCount++;
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自动识别结果'),
        content: Text(
          parsedCount > 0
              ? '成功从学号/身份证中识别出 $parsedCount 人的生日信息'
              : '未能从学号/身份证中识别出生日信息\n\n请确保学号为18位或15位身份证号码',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
