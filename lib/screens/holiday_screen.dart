import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 法定节假日数据模型
class _Holiday {
  final String name;
  final String icon;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final List<DateTime> workDays;

  const _Holiday({
    required this.name,
    required this.icon,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    this.workDays = const [],
  });

  /// 判断今天是否在假期内
  bool isCurrentlyOnHoliday(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !today.isBefore(start) && !today.isAfter(end);
  }

  /// 判断假期是否已结束
  bool isFinished(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return today.isAfter(end);
  }

  /// 距离放假还有多少天
  int daysUntilStart(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    return start.difference(today).inDays;
  }
}

class HolidayScreen extends ConsumerWidget {
  const HolidayScreen({super.key});

  static final List<_Holiday> _holidays = [
    _Holiday(
      name: '元旦',
      icon: '🎉',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 3),
      totalDays: 3,
      workDays: [DateTime(2026, 1, 4)],
    ),
    _Holiday(
      name: '春节',
      icon: '🧧',
      startDate: DateTime(2026, 2, 15),
      endDate: DateTime(2026, 2, 23),
      totalDays: 9,
      workDays: [DateTime(2026, 2, 14), DateTime(2026, 2, 28)],
    ),
    _Holiday(
      name: '清明节',
      icon: '🌿',
      startDate: DateTime(2026, 4, 4),
      endDate: DateTime(2026, 4, 6),
      totalDays: 3,
    ),
    _Holiday(
      name: '劳动节',
      icon: '💪',
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 5),
      totalDays: 5,
      workDays: [DateTime(2026, 5, 9)],
    ),
    _Holiday(
      name: '端午节',
      icon: '🐉',
      startDate: DateTime(2026, 6, 19),
      endDate: DateTime(2026, 6, 21),
      totalDays: 3,
    ),
    _Holiday(
      name: '中秋节',
      icon: '🌕',
      startDate: DateTime(2026, 9, 25),
      endDate: DateTime(2026, 9, 27),
      totalDays: 3,
    ),
    _Holiday(
      name: '国庆节',
      icon: '🇨🇳',
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 7),
      totalDays: 7,
      workDays: [DateTime(2026, 9, 20), DateTime(2026, 10, 10)],
    ),
  ];

  static const int _totalHolidayDays = 33;

  String _formatDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  String _formatDateWithWeekday(DateTime date) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.month}月${date.day}日($weekday)';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(
        title: const Text('法定节假日'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _holidays.length,
              itemBuilder: (context, index) {
                final holiday = _holidays[index];
                final isFinished = holiday.isFinished(now);
                final isCurrent = holiday.isCurrentlyOnHoliday(now);
                final isUpcoming = !isFinished && !isCurrent;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildHolidayCard(
                    context: context,
                    holiday: holiday,
                    isFinished: isFinished,
                    isCurrent: isCurrent,
                    isUpcoming: isUpcoming,
                    now: now,
                    today: today,
                    colorScheme: colorScheme,
                    theme: theme,
                  ),
                );
              },
            ),
          ),
          _buildSummaryFooter(colorScheme, theme),
        ],
      ),
    );
  }

  Widget _buildHolidayCard({
    required BuildContext context,
    required _Holiday holiday,
    required bool isFinished,
    required bool isCurrent,
    required bool isUpcoming,
    required DateTime now,
    required DateTime today,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    final daysUntil = holiday.daysUntilStart(now);

    // 倒计时文本
    String countdownText;
    Color countdownColor;
    if (isCurrent) {
      countdownText = '正在放假';
      countdownColor = Colors.green;
    } else if (isFinished) {
      countdownText = '已结束';
      countdownColor = colorScheme.outline;
    } else {
      countdownText = '距离放假还有 $daysUntil 天';
      countdownColor = colorScheme.primary;
    }

    // 卡片背景色
    Color cardColor;
    Color cardBorder;
    if (isCurrent) {
      cardColor = colorScheme.primaryContainer.withOpacity(0.3);
      cardBorder = colorScheme.primary;
    } else if (isFinished) {
      cardColor = colorScheme.surfaceContainerHighest.withOpacity(0.3);
      cardBorder = colorScheme.outlineVariant;
    } else {
      cardColor = colorScheme.surface;
      cardBorder = colorScheme.primary.withOpacity(0.3);
    }

    // 调休上班日文本
    String workDayText = '';
    if (holiday.workDays.isNotEmpty) {
      final formatted = holiday.workDays.map(_formatDateWithWeekday).join('、');
      workDayText = '调休上班：$formatted';
    }

    // 放假日期范围文本
    final dateRange = '${_formatDate(holiday.startDate)} - ${_formatDate(holiday.endDate)}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(color: cardBorder, width: 1.5)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：图标、名称、倒计时
            Row(
              children: [
                Text(
                  holiday.icon,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    holiday.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isFinished
                          ? colorScheme.outline
                          : colorScheme.onSurface,
                    ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '放假中',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // 第二行：日期范围和天数
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: isFinished ? colorScheme.outline : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  dateRange,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isFinished ? colorScheme.outline : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isFinished
                        ? colorScheme.outlineVariant.withOpacity(0.5)
                        : colorScheme.secondaryContainer.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '共${holiday.totalDays}天',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isFinished
                          ? colorScheme.outline
                          : colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 第三行：倒计时
            Row(
              children: [
                Icon(
                  isCurrent
                      ? Icons.beach_access
                      : isFinished
                          ? Icons.check_circle_outline
                          : Icons.timer_outlined,
                  size: 16,
                  color: countdownColor,
                ),
                const SizedBox(width: 6),
                Text(
                  countdownText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: countdownColor,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),

            // 第四行：调休上班日
            if (workDayText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 16,
                    color: isFinished ? colorScheme.outline : colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      workDayText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isFinished ? colorScheme.outline : colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // 正在放假时显示进度条
            if (isCurrent) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _calculateProgress(holiday, today),
                  backgroundColor: colorScheme.primaryContainer,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '第 ${today.difference(DateTime(holiday.startDate.year, holiday.startDate.month, holiday.startDate.day)).inDays + 1} / ${holiday.totalDays} 天',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _calculateProgress(_Holiday holiday, DateTime today) {
    final start = DateTime(holiday.startDate.year, holiday.startDate.month, holiday.startDate.day);
    final end = DateTime(holiday.endDate.year, holiday.endDate.month, holiday.endDate.day);
    final total = end.difference(start).inDays + 1;
    final elapsed = today.difference(start).inDays + 1;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Widget _buildSummaryFooter(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '2026年全年法定节假日共 $_totalHolidayDays 天',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
