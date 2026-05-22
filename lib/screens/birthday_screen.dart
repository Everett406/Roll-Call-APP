import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunar/lunar.dart';
import '../providers/app_state.dart';
import '../models/member.dart';

/// 生日数据模型
class _BirthdayItem {
  final Member member;
  final DateTime birthdayThisYear;
  final int daysUntil;
  final bool isThisWeek;
  final String lunarDate;

  _BirthdayItem({
    required this.member,
    required this.birthdayThisYear,
    required this.daysUntil,
    required this.isThisWeek,
    required this.lunarDate,
  });
}

/// 时间轴中的事件基类
sealed class _TimelineEvent {
  final DateTime date;
  _TimelineEvent(this.date);
}

/// 节日事件
class _FestivalEvent extends _TimelineEvent {
  final String name;
  final String? icon;
  _FestivalEvent(super.date, this.name, {this.icon});
}

/// 节气事件
class _JieQiEvent extends _TimelineEvent {
  final String name;
  _JieQiEvent(super.date, this.name);
}

/// 生日事件
class _BirthdayEvent extends _TimelineEvent {
  final _BirthdayItem item;
  _BirthdayEvent(super.date, this.item);
}

class BirthdayScreen extends ConsumerStatefulWidget {
  const BirthdayScreen({super.key});

  @override
  ConsumerState<BirthdayScreen> createState() => _BirthdayScreenState();
}

class _BirthdayScreenState extends ConsumerState<BirthdayScreen> {
  bool _isLunarMode = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final members = state.members.where((m) => m.birthday != null).toList();

    final birthdayItems = _buildBirthdayList(members);
    final thisWeekItems = birthdayItems.where((b) => b.isThisWeek).toList();
    final otherItems = birthdayItems.where((b) => !b.isThisWeek).toList();

    // 构建完整时间轴事件列表
    final timelineEvents = _buildTimelineEvents(otherItems);

    // 统计信息
    final nextBirthday = birthdayItems.isNotEmpty ? birthdayItems.first : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('生日提醒'),
        centerTitle: true,
        elevation: 0,
        actions: [
          // 公历/农历切换
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('公历')),
                ButtonSegment(value: true, label: Text('农历')),
              ],
              selected: {_isLunarMode},
              onSelectionChanged: (selected) {
                setState(() => _isLunarMode = selected.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  theme.textTheme.labelSmall,
                ),
              ),
            ),
          ),
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
                // 顶部介绍卡片
                SliverToBoxAdapter(
                  child: _buildHeaderCard(theme, nextBirthday, members.length),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                // 本周生日
                if (thisWeekItems.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildThisWeekSection(theme, thisWeekItems),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
                // 时间轴
                SliverToBoxAdapter(
                  child: _buildTimeline(theme, timelineEvents),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 48)),
              ],
            ),
    );
  }

  // ==================== 数据构建 ====================

  List<_BirthdayItem> _buildBirthdayList(List<Member> members) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = <_BirthdayItem>[];

    for (final member in members) {
      final birthday = member.birthday!;
      var birthdayThisYear = DateTime(now.year, birthday.month, birthday.day);

      if (birthdayThisYear.isBefore(today)) {
        birthdayThisYear = DateTime(now.year + 1, birthday.month, birthday.day);
      }

      final daysUntil = birthdayThisYear.difference(today).inDays;

      if (daysUntil <= 365) {
        // 获取农历日期
        final solar = Solar.fromYmd(
          birthdayThisYear.year,
          birthdayThisYear.month,
          birthdayThisYear.day,
        );
        final lunar = solar.getLunar();
        final lunarDate =
            '${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';

        items.add(_BirthdayItem(
          member: member,
          birthdayThisYear: birthdayThisYear,
          daysUntil: daysUntil,
          isThisWeek: daysUntil <= 7,
          lunarDate: lunarDate,
        ));
      }
    }

    items.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return items;
  }

  /// 构建时间轴事件（生日 + 节日 + 节气）
  List<_TimelineEvent> _buildTimelineEvents(List<_BirthdayItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final events = <_TimelineEvent>[];

    // 收集所有需要检查的日期范围
    if (items.isEmpty) return events;

    final minDate = today;
    final maxDate = items.last.birthdayThisYear;

    // 遍历每一天，查找节日和节气
    for (int i = 0; i <= maxDate.difference(minDate).inDays; i++) {
      final date = minDate.add(Duration(days: i));
      final solar = Solar.fromYmd(date.year, date.month, date.day);
      final lunar = solar.getLunar();

      // 检查传统节日（农历节日）
      final lunarFestivals = lunar.getFestivals();
      for (final f in lunarFestivals) {
        events.add(_FestivalEvent(date, f, icon: _getFestivalIcon(f)));
      }

      // 检查公历节日
      final solarFestivals = solar.getFestivals();
      for (final f in solarFestivals) {
        events.add(_FestivalEvent(date, f));
      }

      // 检查节气 - 只添加有节气的日期
      final jieQi = lunar.getJieQi();
      if (jieQi != null && jieQi.isNotEmpty) {
        events.add(_JieQiEvent(date, jieQi));
      }
    }

    // 添加生日事件
    for (final item in items) {
      events.add(_BirthdayEvent(item.birthdayThisYear, item));
    }

    // 按日期排序
    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  String? _getFestivalIcon(String festivalName) {
    const icons = {
      '春节': '🧨',
      '元宵节': '🏮',
      '清明节': '🌿',
      '端午节': '🐉',
      '七夕节': '💕',
      '中秋节': '🌕',
      '重阳节': '🏔',
      '冬至': '❄️',
      '元旦': '🎉',
    };
    return icons[festivalName];
  }

  // ==================== UI 构建 ====================

  Widget _buildHeaderCard(
    ThemeData theme,
    _BirthdayItem? nextBirthday,
    int totalMembers,
  ) {
    final daysText = nextBirthday != null
        ? nextBirthday.daysUntil == 0
            ? '今天就是生日!'
            : '距离下一个生日还有 ${nextBirthday.daysUntil} 天'
        : '暂无即将到来的生日';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '🎂',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(width: 12),
              Text(
                '生日日历',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Text(
                daysText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.people,
                size: 16,
                color: theme.colorScheme.onPrimaryContainer.withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Text(
                '共 $totalMembers 位同学的生日',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8),
                ),
              ),
            ],
          ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  _isLunarMode
                      ? '${item.lunarDate} (${item.birthdayThisYear.month}/${item.birthdayThisYear.day}) · 满${_calculateAge(item.member.birthday!, item.birthdayThisYear)}岁'
                      : '${item.birthdayThisYear.month}月${item.birthdayThisYear.day}日 · ${item.lunarDate} · 满${_calculateAge(item.member.birthday!, item.birthdayThisYear)}岁',
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

  // ==================== 时间轴 ====================

  Widget _buildTimeline(ThemeData theme, List<_TimelineEvent> events) {
    if (events.isEmpty) return const SizedBox.shrink();

    // 按月份分组
    final grouped = <String, List<_TimelineEvent>>{};
    for (final event in events) {
      final key = '${event.date.year}年${event.date.month}月';
      grouped.putIfAbsent(key, () => []).add(event);
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
          ...grouped.entries.map((entry) =>
              _buildMonthGroup(theme, entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildMonthGroup(
    ThemeData theme,
    String monthLabel,
    List<_TimelineEvent> events,
  ) {
    // 计算时间轴高度：每个事件约 40px
    final lineHeight = events.length * 44.0;

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
              height: lineHeight,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
              // 事件列表
              ...events.map((event) => _buildEventItem(theme, event)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEventItem(ThemeData theme, _TimelineEvent event) {
    return switch (event) {
      _FestivalEvent() => _buildFestivalItem(theme, event),
      _JieQiEvent() => _buildJieQiItem(theme, event),
      _BirthdayEvent() => _buildTimelineBirthdayItem(theme, event.item),
    };
  }

  Widget _buildFestivalItem(ThemeData theme, _FestivalEvent event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            event.icon ?? '🎊',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withOpacity(0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              event.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${event.date.month}/${event.date.day}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJieQiItem(ThemeData theme, _JieQiEvent event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            Icons.eco,
            size: 14,
            color: theme.colorScheme.primary.withOpacity(0.7),
          ),
          const SizedBox(width: 6),
          Text(
            '节气',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              event.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${event.date.month}/${event.date.day}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineBirthdayItem(ThemeData theme, _BirthdayItem item) {
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
                  _isLunarMode
                      ? '${item.lunarDate} (${item.birthdayThisYear.month}/${item.birthdayThisYear.day}) · 满${_calculateAge(item.member.birthday!, item.birthdayThisYear)}岁'
                      : '${item.birthdayThisYear.day}日 · ${item.lunarDate} · 满${_calculateAge(item.member.birthday!, item.birthdayThisYear)}岁',
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

  // ==================== 工具方法 ====================

  int _calculateAge(DateTime birthday, DateTime targetDate) {
    var age = targetDate.year - birthday.year;
    if (targetDate.month < birthday.month ||
        (targetDate.month == birthday.month && targetDate.day < birthday.day)) {
      age--;
    }
    return age;
  }

  void _showAutoParseDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.read(appStateProvider);
    final membersWithoutBirthday =
        state.members.where((m) => m.birthday == null).toList();

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
