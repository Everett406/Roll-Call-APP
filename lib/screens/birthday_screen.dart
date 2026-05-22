import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lunar/lunar.dart';
import '../providers/app_state.dart';
import '../models/member.dart';

/// 生日数据模型
class _BirthdayItem {
  final Member member;
  final DateTime birthdayThisYear; // 今年/明年的生日日期（公历）
  final int daysUntil;
  final bool isThisWeek;
  final String lunarDate; // 农历日期字符串（如"四月初六"）
  final int lunarMonth; // 农历月
  final int lunarDay; // 农历日

  _BirthdayItem({
    required this.member,
    required this.birthdayThisYear,
    required this.daysUntil,
    required this.isThisWeek,
    required this.lunarDate,
    required this.lunarMonth,
    required this.lunarDay,
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
                // 本周生日（着重显示）
                if (thisWeekItems.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildThisWeekSection(theme, thisWeekItems),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
                // 时间轴列表
                SliverToBoxAdapter(
                  child: _buildTimeline(theme, timelineEvents),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  /// 构建生日列表
  /// 公历模式：按公历日期排序
  /// 农历模式：按农历日期排序，计算今年/明年农历生日对应的公历日期
  List<_BirthdayItem> _buildBirthdayList(List<Member> members) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = <_BirthdayItem>[];

    for (final member in members) {
      try {
        final birthday = member.birthday!;
        
        // 获取出生日期的农历
        final birthLunar = Solar.fromYmd(birthday.year, birthday.month, birthday.day).getLunar();
        final lunarMonth = birthLunar.getMonth();
        final lunarDay = birthLunar.getDay();
        final lunarDateStr = '${birthLunar.getMonthInChinese()}月${birthLunar.getDayInChinese()}';

        DateTime birthdayThisYear;
        int daysUntil;
        
        if (_isLunarMode) {
          // 农历模式：找今年/明年的农历生日对应的公历日期
          try {
            // 今年农历生日
            var lunarThisYear = Lunar.fromYmd(now.year, lunarMonth, lunarDay);
            var solarThisYear = lunarThisYear.getSolar();
            var dateThisYear = DateTime(solarThisYear.getYear(), solarThisYear.getMonth(), solarThisYear.getDay());
            
            // 如果今年农历生日已过，用明年
            if (dateThisYear.isBefore(today)) {
              lunarThisYear = Lunar.fromYmd(now.year + 1, lunarMonth, lunarDay);
              solarThisYear = lunarThisYear.getSolar();
              birthdayThisYear = DateTime(solarThisYear.getYear(), solarThisYear.getMonth(), solarThisYear.getDay());
            } else {
              birthdayThisYear = dateThisYear;
            }
            daysUntil = birthdayThisYear.difference(today).inDays;
          } catch (e) {
            // 农历转换失败，回退到公历模式
            birthdayThisYear = DateTime(now.year, birthday.month, birthday.day);
            if (birthdayThisYear.isBefore(today)) {
              birthdayThisYear = DateTime(now.year + 1, birthday.month, birthday.day);
            }
            daysUntil = birthdayThisYear.difference(today).inDays;
          }
        } else {
          // 公历模式：直接用公历日期
          birthdayThisYear = DateTime(now.year, birthday.month, birthday.day);
          if (birthdayThisYear.isBefore(today)) {
            birthdayThisYear = DateTime(now.year + 1, birthday.month, birthday.day);
          }
          daysUntil = birthdayThisYear.difference(today).inDays;
        }

        // 只保留最近一年的
        if (daysUntil <= 365) {
          items.add(_BirthdayItem(
            member: member,
            birthdayThisYear: birthdayThisYear,
            daysUntil: daysUntil,
            isThisWeek: daysUntil <= 7,
            lunarDate: lunarDateStr,
            lunarMonth: lunarMonth,
            lunarDay: lunarDay,
          ));
        }
      } catch (e) {
        // 跳过转换失败的成员
        continue;
      }
    }

    // 排序
    if (items.isNotEmpty) {
      if (_isLunarMode) {
        // 农历模式：按农历月日排序
        items.sort((a, b) {
          final monthCompare = a.lunarMonth.compareTo(b.lunarMonth);
          if (monthCompare != 0) return monthCompare;
          return a.lunarDay.compareTo(b.lunarDay);
        });
        // 把已过的农历月份放到后面
        try {
          final currentLunar = Solar.fromYmd(now.year, now.month, now.day).getLunar();
          final currentLunarMonth = currentLunar.getMonth();
          items.sort((a, b) {
            final aPassed = a.lunarMonth < currentLunarMonth || 
                (a.lunarMonth == currentLunarMonth && a.daysUntil < 0);
            final bPassed = b.lunarMonth < currentLunarMonth || 
                (b.lunarMonth == currentLunarMonth && b.daysUntil < 0);
            if (aPassed && !bPassed) return 1;
            if (!aPassed && bPassed) return -1;
            return a.daysUntil.compareTo(b.daysUntil);
          });
        } catch (e) {
          // 如果获取当前农历失败，按天数排序
          items.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
        }
      } else {
        // 公历模式：按距离天数排序
        items.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
      }
    }

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
                  _isLunarMode
                      ? '农历${item.lunarDate} (${item.birthdayThisYear.month}/${item.birthdayThisYear.day})'
                      : '${item.birthdayThisYear.month}月${item.birthdayThisYear.day}日 · 农历${item.lunarDate}',
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

  /// 构建时间轴事件（生日 + 节日 + 节气）
  List<_TimelineEvent> _buildTimelineEvents(List<_BirthdayItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final events = <_TimelineEvent>[];

    if (items.isEmpty) return events;

    final minDate = today;
    final maxDate = items.map((i) => i.birthdayThisYear).reduce((a, b) => a.isAfter(b) ? a : b);

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

  String? _getFestivalIcon(String festival) {
    const icons = {
      '春节': '🧧',
      '元宵节': '🏮',
      '清明节': '🌿',
      '端午节': '🐉',
      '七夕节': '💕',
      '中秋节': '🌕',
      '重阳节': '🍂',
      '冬至': '❄️',
      '除夕': '🎆',
      '元旦': '🎉',
      '劳动节': '💪',
      '国庆节': '🇨🇳',
    };
    return icons[festival];
  }

  Widget _buildTimeline(ThemeData theme, List<_TimelineEvent> events) {
    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

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
          ...grouped.entries.map((entry) => _buildMonthGroup(theme, entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildMonthGroup(ThemeData theme, String monthLabel, List<_TimelineEvent> events) {
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
              height: events.length * 55.0,
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
              // 事件列表
              ...events.map((event) => _buildTimelineEventItem(theme, event)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineEventItem(ThemeData theme, _TimelineEvent event) {
    if (event is _FestivalEvent) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(event.icon ?? '🎊', style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              event.name,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
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

    if (event is _JieQiEvent) {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.eco, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              event.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
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

    if (event is _BirthdayEvent) {
      final item = event.item;
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
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
                        ? '农历${item.lunarDate} (${item.birthdayThisYear.month}/${item.birthdayThisYear.day})'
                        : '${item.birthdayThisYear.month}/${item.birthdayThisYear.day} · 农历${item.lunarDate}',
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

    return const SizedBox.shrink();
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
