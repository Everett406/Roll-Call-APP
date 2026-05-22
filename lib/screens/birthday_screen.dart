import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/member.dart';

/// 节假日数据
class Holiday {
  final String name;
  final int month;
  final int day;
  final bool isFixed; // 是否固定日期（农历节日为false）

  const Holiday({
    required this.name,
    required this.month,
    required this.day,
    this.isFixed = true,
  });
}

/// 内置节假日（公历）
const List<Holiday> _fixedHolidays = [
  Holiday(name: '元旦', month: 1, day: 1),
  Holiday(name: '情人节', month: 2, day: 14),
  Holiday(name: '妇女节', month: 3, day: 8),
  Holiday(name: '植树节', month: 3, day: 12),
  Holiday(name: '愚人节', month: 4, day: 1),
  Holiday(name: '劳动节', month: 5, day: 1),
  Holiday(name: '青年节', month: 5, day: 4),
  Holiday(name: '儿童节', month: 6, day: 1),
  Holiday(name: '建党节', month: 7, day: 1),
  Holiday(name: '建军节', month: 8, day: 1),
  Holiday(name: '教师节', month: 9, day: 10),
  Holiday(name: '国庆节', month: 10, day: 1),
  Holiday(name: '万圣节', month: 10, day: 31),
  Holiday(name: '平安夜', month: 12, day: 24),
  Holiday(name: '圣诞节', month: 12, day: 25),
];

/// 农历节日（简化处理，按公历大致日期）
const List<Holiday> _lunarHolidays = [
  Holiday(name: '春节', month: 2, day: 10, isFixed: false),
  Holiday(name: '元宵节', month: 2, day: 24, isFixed: false),
  Holiday(name: '清明节', month: 4, day: 4, isFixed: false),
  Holiday(name: '端午节', month: 6, day: 10, isFixed: false),
  Holiday(name: '七夕节', month: 8, day: 10, isFixed: false),
  Holiday(name: '中秋节', month: 9, day: 17, isFixed: false),
  Holiday(name: '重阳节', month: 10, day: 11, isFixed: false),
];

class BirthdayScreen extends ConsumerWidget {
  const BirthdayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final members = state.members;

    // 分离有生日和无生日的成员
    final membersWithBirthday = members.where((m) => m.birthday != null).toList();
    final membersWithoutBirthday = members.where((m) => m.birthday == null).toList();

    // 按生日排序（距离今天最近的在前）
    membersWithBirthday.sort((a, b) {
      final daysA = _daysUntilBirthday(a.birthday!);
      final daysB = _daysUntilBirthday(b.birthday!);
      return daysA.compareTo(daysB);
    });

    final now = DateTime.now();
    final currentMonth = now.month;

    return Scaffold(
      appBar: AppBar(
        title: const Text('生日提醒'),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (membersWithoutBirthday.isNotEmpty)
            TextButton(
              onPressed: () => _showAutoParseDialog(context, ref, membersWithoutBirthday),
              child: const Text('自动识别'),
            ),
        ],
      ),
      body: members.isEmpty
          ? _buildEmptyState(theme)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 本月概览
                _buildMonthOverview(theme, membersWithBirthday, currentMonth),
                const SizedBox(height: 16),
                // 即将到来的生日
                if (membersWithBirthday.isNotEmpty) ...[
                  _buildSectionTitle(theme, '即将到来的生日'),
                  const SizedBox(height: 8),
                  ...membersWithBirthday.take(10).map((m) => _buildBirthdayCard(theme, m)),
                  const SizedBox(height: 16),
                ],
                // 节假日
                _buildSectionTitle(theme, '节假日'),
                const SizedBox(height: 8),
                _buildHolidaysCard(theme),
                const SizedBox(height: 16),
                // 无生日信息的成员
                if (membersWithoutBirthday.isNotEmpty) ...[
                  _buildSectionTitle(theme, '待补全生日 (${membersWithoutBirthday.length})'),
                  const SizedBox(height: 8),
                  _buildIncompleteList(theme, ref, membersWithoutBirthday),
                ],
              ],
            ),
    );
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
            '暂无成员',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthOverview(ThemeData theme, List<Member> members, int currentMonth) {
    final thisMonthBirthdays = members.where((m) {
      if (m.birthday == null) return false;
      return m.birthday!.month == currentMonth;
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '$currentMonth月生日',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${thisMonthBirthdays.length}人',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (thisMonthBirthdays.isEmpty)
              Text(
                '本月没有人生日',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: thisMonthBirthdays.map((m) {
                  final days = _daysUntilBirthday(m.birthday!);
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary,
                      child: Text(
                        m.name.substring(0, 1),
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    label: Text('${m.name} ${m.birthday!.day}日'),
                    backgroundColor: days == 0
                        ? theme.colorScheme.primaryContainer.withOpacity(0.5)
                        : null,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildBirthdayCard(ThemeData theme, Member member) {
    final days = _daysUntilBirthday(member.birthday!);
    final age = _calculateAge(member.birthday!);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: days == 0
              ? theme.colorScheme.primary
              : theme.colorScheme.primaryContainer,
          child: Text(
            member.name.substring(0, 1),
            style: TextStyle(
              color: days == 0
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(member.name),
        subtitle: Text(
          '${member.birthday!.month}月${member.birthday!.day}日 · 满$age岁',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: days == 0
                ? theme.colorScheme.primary
                : theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            days == 0 ? '今天!' : '还有$days天',
            style: theme.textTheme.bodySmall?.copyWith(
              color: days == 0
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHolidaysCard(ThemeData theme) {
    final now = DateTime.now();
    final allHolidays = [..._fixedHolidays, ..._lunarHolidays];

    // 按距离今天最近排序
    allHolidays.sort((a, b) {
      final daysA = _daysUntilDate(a.month, a.day);
      final daysB = _daysUntilDate(b.month, b.day);
      return daysA.compareTo(daysB);
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allHolidays.take(8).map((h) {
            final days = _daysUntilDate(h.month, h.day);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: days == 0
                    ? theme.colorScheme.tertiaryContainer
                    : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: days == 0
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.outlineVariant.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    h.name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    days == 0 ? '今天' : '$days天',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildIncompleteList(ThemeData theme, WidgetRef ref, List<Member> members) {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: members.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final member = members[index];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Text(
                member.name.substring(0, 1),
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            title: Text(
              member.name,
              style: theme.textTheme.bodyMedium,
            ),
            subtitle: member.studentId != null
                ? Text(
                    '学号: ${member.studentId}',
                    style: theme.textTheme.bodySmall,
                  )
                : null,
            trailing: TextButton(
              onPressed: () => _showEditBirthdayDialog(context, ref, member),
              child: const Text('补全'),
            ),
          );
        },
      ),
    );
  }

  /// 计算距离生日的天数
  int _daysUntilBirthday(DateTime birthday) {
    return _daysUntilDate(birthday.month, birthday.day);
  }

  /// 计算距离某月某日的天数
  int _daysUntilDate(int month, int day) {
    final now = DateTime.now();
    var target = DateTime(now.year, month, day);

    if (target.isBefore(now) && !target.isAtSameMomentAs(now)) {
      target = DateTime(now.year + 1, month, day);
    }

    return target.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  /// 计算年龄
  int _calculateAge(DateTime birthday) {
    final now = DateTime.now();
    var age = now.year - birthday.year;
    if (now.month < birthday.month ||
        (now.month == birthday.month && now.day < birthday.day)) {
      age--;
    }
    return age + 1; // 即将满的年龄
  }

  /// 显示自动识别对话框
  void _showAutoParseDialog(BuildContext context, WidgetRef ref, List<Member> members) {
    final theme = Theme.of(context);
    final state = ref.read(appStateProvider);

    // 尝试从学号解析生日
    int parsedCount = 0;
    for (final member in members) {
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

  /// 显示编辑生日对话框
  void _showEditBirthdayDialog(BuildContext context, WidgetRef ref, Member member) {
    final theme = Theme.of(context);
    DateTime? selectedDate = member.birthday;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置 ${member.name} 的生日'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (member.studentId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '学号/身份证: ${member.studentId}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(
                selectedDate != null
                    ? '${selectedDate!.year}年${selectedDate!.month}月${selectedDate!.day}日'
                    : '选择日期',
              ),
              trailing: selectedDate != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        selectedDate = null;
                        Navigator.pop(context);
                        _showEditBirthdayDialog(context, ref, member);
                      },
                    )
                  : null,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? DateTime(2000, 1, 1),
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  selectedDate = date;
                  Navigator.pop(context);
                  _showEditBirthdayDialog(context, ref, member);
                }
              },
            ),
            if (member.studentId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () {
                    final birthday = Member.parseBirthdayFromIdCard(member.studentId!);
                    if (birthday != null) {
                      selectedDate = birthday;
                      Navigator.pop(context);
                      _showEditBirthdayDialog(context, ref, member);
                    }
                  },
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('从学号自动识别'),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (selectedDate != null) {
                final state = ref.read(appStateProvider);
                state.updateMember(member.copyWith(birthday: selectedDate));
              }
              Navigator.pop(context);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
