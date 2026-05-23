import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/time_period.dart';
import '../utils/constants.dart';
import '../utils/expressive_theme.dart';
import '../utils/chart_painter.dart';
import 'member_history_screen.dart';
import 'attendance_calendar_screen.dart';
import 'ai_chat_screen.dart';
import 'ai_conversations_screen.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  TimePeriod _selectedPeriod = TimePeriod.lastWeek;
  late TabController _tabController;
  int _selectedRankingTab = 0; // 0 = 缺勤榜, 1 = 出勤榜
  int _aiPlaceholderIndex = 0;
  Timer? _aiPlaceholderTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedRankingTab = _tabController.index;
      });
    });
    // 每3秒切换 AI 入口占位文字
    _aiPlaceholderTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _aiPlaceholderIndex = (_aiPlaceholderIndex + 1) % _aiPlaceholders.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aiPlaceholderTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);

    // ---- Core data ----
    final statusCounts = state.getStatusCountsForPeriod(_selectedPeriod);
    final totalCheckIns = statusCounts.values.fold(0, (a, b) => a + b);
    final attendedCount = statusCounts.entries
        .where((e) => state.attendanceTagIds.contains(e.key))
        .fold(0, (a, b) => a + b.value);
    final attendanceRate = totalCheckIns > 0 ? attendedCount / totalCheckIns : 0.0;

    // ---- Comparison (period-over-period) ----
    final comparison = state.getPeriodComparison(_selectedPeriod);
    final rateChange = comparison['rateChange'] as double;
    final countChange = comparison['countChange'] as int;

    // ---- Daily trend data ----
    final dailyRates = state.getDailyAttendanceRates(_selectedPeriod);
    final trendValues = dailyRates.map((e) => e.value).toList();

    // ---- Status segments for donut ----
    final donutData = state.tags
        .where((t) => (statusCounts[t.id] ?? 0) > 0)
        .map((t) => MapEntry(t.name, {
              'count': statusCounts[t.id] ?? 0,
              'color': Color(t.colorValue),
            }))
        .toList();

    // ---- Ranking data ----
    final ranking = state.getMemberAbsenteeismRanking(_selectedPeriod);
    final attendanceRanking = List<Map<String, dynamic>>.from(ranking)
      ..sort((a, b) {
        final aRate = (a['total'] as int) > 0
            ? 1.0 - (a['absentRate'] as double) : 0.0;
        final bRate = (b['total'] as int) > 0
            ? 1.0 - (b['absentRate'] as double) : 0.0;
        return bRate.compareTo(aRate);
      });

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ===== Header =====
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '统计概览',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Period selector chips
                  Row(
                    children: TimePeriod.values.map((period) {
                      final isSelected = _selectedPeriod == period;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: isSelected,
                          label: Text(_getPeriodLabel(period)),
                          onSelected: (_) {
                            setState(() => _selectedPeriod = period);
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // ===== Stat Cards (2x2 grid with change badges) =====
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                _buildStatCard(
                  title: '出勤率',
                  value: '${(attendanceRate * 100).toStringAsFixed(1)}%',
                  icon: Icons.check_circle_outline,
                  color: attendanceRate >= 0.8
                      ? AppColors.success
                      : attendanceRate >= 0.6 ? AppColors.warning : AppColors.error,
                  changeBadge: rateChange != 0
                      ? ChangeBadge(change: rateChange)
                      : null,
                ),
                _buildStatCard(
                  title: '签到人次',
                  value: '$totalCheckIns',
                  icon: Icons.people_outline,
                  color: theme.colorScheme.primary,
                  changeBadge: countChange != 0
                      ? ChangeBadge(
                          change: comparison['previousCount'] as int > 0
                              ? countChange / (comparison['previousCount'] as int)
                              : 0,
                          label: '$countChange',
                        )
                      : null,
                ),
                _buildStatCard(
                  title: '点名次数',
                  value: '${state.sessions.length}',
                  icon: Icons.event_note_outlined,
                  color: theme.colorScheme.secondary,
                ),
                _buildStatCard(
                  title: '成员数',
                  value: '${state.members.length}',
                  icon: Icons.group_outlined,
                  color: theme.colorScheme.tertiary,
                ),
              ],
            ),
          ),

          // ===== 今日提醒（生日+节假日）=====
          SliverToBoxAdapter(
            child: _buildTodayReminders(state, theme),
          ),

          // ===== AI 助手入口 =====
          SliverToBoxAdapter(
            child: _buildAiEntry(theme),
          ),

          // ===== Attendance Trend Line Chart =====
          SliverToBoxAdapter(
            child: ContainmentGroup(
              title: '出勤率趋势',
              titleIcon: Icons.show_chart,
              padding: const EdgeInsets.all(16),
              child: totalCheckIns == 0
                  ? _buildEmptyState(theme, '暂无趋势数据')
                  : Column(
                      children: [
                        LineChart(
                          values: trendValues,
                          lineColor: attendanceRate >= 0.8
                              ? AppColors.success
                              : attendanceRate >= 0.6
                                  ? AppColors.warning
                                  : theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 4),
                        // Date range label
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDateShort(dailyRates.first.key),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              _formatDateShort(dailyRates.last.key),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),

          // ===== Status Distribution (Donut Chart) =====
          SliverToBoxAdapter(
            child: ContainmentGroup(
              title: '状态分布',
              titleIcon: Icons.donut_large,
              padding: const EdgeInsets.all(16),
              child: donutData.isEmpty
                  ? _buildEmptyState(theme, '暂无状态数据')
                  : _buildDonutChart(donutData, totalCheckIns, theme),
            ),
          ),

          // ===== Weekly Heatmap =====
          SliverToBoxAdapter(
            child: ContainmentGroup(
              title: '本周出勤热力',
              titleIcon: Icons.calendar_view_week,
              padding: const EdgeInsets.all(16),
              child: _buildHeatmap(state, theme),
            ),
          ),

          // ===== Member Rankings (Dual Tabs) =====
          SliverToBoxAdapter(
            child: ContainmentGroup(
              title: '人员概况',
              titleIcon: Icons.format_list_numbered,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  // Tab bar
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: theme.colorScheme.primaryContainer,
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelColor: theme.colorScheme.onPrimaryContainer,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      tabs: const [
                        Tab(text: '缺勤关注'),
                        Tab(text: '出勤光荣'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: ranking.isEmpty ? 80 : 340,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Absentee ranking
                        _buildRankingList(
                          ranking: ranking,
                          theme: theme,
                          type: 'absent',
                          maxCount: state.rankingCount,
                        ),
                        // Attendance honor roll
                        _buildRankingList(
                          ranking: attendanceRanking,
                          theme: theme,
                          type: 'attendance',
                          maxCount: state.rankingCount,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // ===== Builders =====

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    Widget? changeBadge,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const Spacer(),
                if (changeBadge != null) changeBadge,
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
                fontSize: 22,
              ),
            ),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutChart(
    List<MapEntry<String, Map<String, dynamic>>> data,
    int total,
    ThemeData theme,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          height: 110,
          child: CustomPaint(
            painter: DonutChartPainter(
              segments: data.map((d) {
                final info = d.value as Map<String, dynamic>;
                return DonutSegment(
                  value: (info['count'] as int).toDouble(),
                  color: info['color'] as Color,
                  label: d.key,
                );
              }).toList(),
              strokeWidth: 20,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$total',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    '总签到',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.map((d) {
              final info = d.value as Map<String, dynamic>;
              final count = info['count'] as int;
              final color = info['color'] as Color;
              final percentage = total > 0 ? (count / total * 100).toStringAsFixed(1) : '0';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d.key,
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$count次',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$percentage%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRankingList({
    required List<Map<String, dynamic>> ranking,
    required ThemeData theme,
    required String type,
    required int maxCount,
  }) {
    if (ranking.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final showCount = math.min(ranking.length, maxCount);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: showCount,
      physics: const ClampingScrollPhysics(),
      itemBuilder: (context, index) {
        final stat = ranking[index];
        final member = stat['member'];
        final total = stat['total'] as int;
        final absent = stat['absent'] as int;
        final absentRate = stat['absentRate'] as double;
        final attendanceRate = total > 0 ? 1.0 - absentRate : 0.0;

        final isAbsentTab = type == 'absent';
        final displayRate = isAbsentTab ? absentRate : attendanceRate;
        final rateColor = isAbsentTab
            ? (absentRate >= 0.3
                ? AppColors.error
                : absentRate >= 0.15 ? AppColors.warning : AppColors.success)
            : (attendanceRate >= 0.9
                ? AppColors.success
                : attendanceRate >= 0.7 ? AppColors.warning : AppColors.error);

        final rankColors = isAbsentTab
            ? [const Color(0xFFE53935), const Color(0xFFFF9800), const Color(0xFFFFC107)]
            : [const Color(0xFF4CAF50), const Color(0xFF81C784), const Color(0xFFA5D6A7)];

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MemberHistoryScreen(
                    memberId: member.id,
                    memberName: member.name,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Rank badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: index < 3 ? rankColors[index] : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: index < 3 ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isAbsentTab
                              ? '缺勤 $absent / $total 次'
                              : '出勤 ${(attendanceRate * 100).toStringAsFixed(0)}% · $total 次',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Rate badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: rateColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(displayRate * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: rateColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _formatDateShort(DateTime date) {
    return DateFormat('M/d').format(date);
  }

  String _getPeriodLabel(TimePeriod period) {
    switch (period) {
      case TimePeriod.today:
        return '今天';
      case TimePeriod.lastWeek:
        return '近一周';
      case TimePeriod.lastMonth:
        return '近一月';
    }
  }

  Widget _buildHeatmap(AppState state, ThemeData theme) {
    final heatmapData = state.getWeeklyHeatmapData();
    final weekLabels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final now = DateTime.now();
    final todayWeekday = now.weekday;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: heatmapData.asMap().entries.map((entry) {
            final index = entry.key;
            final weekday = entry.value.key;
            final rate = entry.value.value;
            final isToday = weekday == todayWeekday;

            Color cellColor;
            String label;
            if (rate < 0) {
              cellColor = theme.colorScheme.surfaceContainerHighest;
              label = '—';
            } else if (rate >= 0.9) {
              cellColor = const Color(0xFF4CAF50);
              label = '${(rate * 100).toStringAsFixed(0)}%';
            } else if (rate >= 0.7) {
              cellColor = const Color(0xFF8BC34A);
              label = '${(rate * 100).toStringAsFixed(0)}%';
            } else if (rate >= 0.5) {
              cellColor = const Color(0xFFFFC107);
              label = '${(rate * 100).toStringAsFixed(0)}%';
            } else if (rate >= 0.3) {
              cellColor = const Color(0xFFFF9800);
              label = '${(rate * 100).toStringAsFixed(0)}%';
            } else {
              cellColor = const Color(0xFFE53935);
              label = '${(rate * 100).toStringAsFixed(0)}%';
            }

            return Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cellColor.withOpacity(rate < 0 ? 0.5 : 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: isToday
                        ? Border.all(
                            color: theme.colorScheme.primary,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Center(
                    child: rate < 0
                        ? Icon(
                            Icons.remove,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          )
                        : Text(
                            label,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  weekLabels[index],
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: isToday ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _HeatLegend(color: const Color(0xFF4CAF50), label: '优', theme: theme),
            _HeatLegend(color: const Color(0xFF8BC34A), label: '良', theme: theme),
            _HeatLegend(color: const Color(0xFFFFC107), label: '中', theme: theme),
            _HeatLegend(color: const Color(0xFFFF9800), label: '低', theme: theme),
            _HeatLegend(color: const Color(0xFFE53935), label: '差', theme: theme),
          ],
        ),
      ],
    );
  }

  /// 今日提醒（只显示生日）
  Widget _buildTodayReminders(AppState state, ThemeData theme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminders = <Widget>[];

    // 检查今天和明天过生日的人
    for (final member in state.members) {
      if (member.birthday == null) continue;
      
      // 今年的生日
      var birthdayThisYear = DateTime(now.year, member.birthday!.month, member.birthday!.day);
      if (birthdayThisYear.isBefore(today)) {
        birthdayThisYear = DateTime(now.year + 1, member.birthday!.month, member.birthday!.day);
      }
      
      final daysUntil = birthdayThisYear.difference(today).inDays;
      
      // 只显示今天和明天的生日
      if (daysUntil == 0 || daysUntil == 1) {
        final isToday = daysUntil == 0;
        reminders.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer.withOpacity(0.6),
                  theme.colorScheme.tertiaryContainer.withOpacity(0.4),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                const Text('🎂', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isToday ? '今天是 ${member.name} 的生日!' : '明天是 ${member.name} 的生日',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isToday ? '祝 ${member.name} 生日快乐 🎉' : '记得准备祝福哦 🎁',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // 关闭这个提醒
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('知道了'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(0, 0),
                  ),
                  child: const Text('知道了'),
                ),
              ],
            ),
          ),
        );
      }
    }

    if (reminders.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cake_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '生日提醒',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...reminders,
        ],
      ),
    );
  }

  /// AI 助手入口占位文字列表
  static const _aiPlaceholders = [
    '问问 AI 出勤情况...',
    '查询谁缺勤了...',
    '分析本周出勤率...',
    '问问 AI 任何问题...',
  ];

  /// AI 助手入口组件
  Widget _buildAiEntry(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Hero(
        tag: 'ai_input',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AiConversationsScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  // 左侧图标
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primaryContainer,
                          theme.colorScheme.tertiaryContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 动态占位文字
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      child: Text(
                        _aiPlaceholders[_aiPlaceholderIndex],
                        key: ValueKey<String>(_aiPlaceholders[_aiPlaceholderIndex]),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // 右侧发送按钮
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        size: 16,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatLegend extends StatelessWidget {
  final Color color;
  final String label;
  final ThemeData theme;

  const _HeatLegend({required this.color, required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color.withOpacity(0.85), borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 3),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}
