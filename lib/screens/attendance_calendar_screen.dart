import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/session.dart';
import '../utils/expressive_theme.dart';
import 'session_screen.dart';

/// Calendar view showing attendance history by month.
/// Days with sessions are highlighted with color-coded dots.
class AttendanceCalendarScreen extends ConsumerStatefulWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  ConsumerState<AttendanceCalendarScreen> createState() => _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends ConsumerState<AttendanceCalendarScreen> {
  DateTime _currentMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);

    // Get sessions for the current month
    final monthSessions = _getMonthSessions(state.sessions, _currentMonth);
    final daysWithSessions = <int, List<Session>>{};
    for (final s in monthSessions) {
      final day = s.createdAt.day;
      daysWithSessions.putIfAbsent(day, () => []);
      daysWithSessions[day]!.add(s);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('点名日历'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Month navigator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month - 1,
                      );
                    });
                  },
                ),
                const SizedBox(width: 16),
                Text(
                  DateFormat('yyyy年M月').format(_currentMonth),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(
                        _currentMonth.year,
                        _currentMonth.month + 1,
                      );
                    });
                  },
                ),
              ],
            ),
          ),

          // Weekday headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['日', '一', '二', '三', '四', '五', '六'].map((d) {
                return SizedBox(
                  width: 40,
                  child: Text(
                    d,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Calendar grid
          Expanded(
            child: _buildCalendarGrid(
              context,
              theme,
              daysWithSessions,
              state,
            ),
          ),

          // Summary
          if (monthSessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: ExpressiveShapes.cardMedium,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_available,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${monthSessions.length} 次点名',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '本月共 ${daysWithSessions.keys.length} 天进行了点名',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    ThemeData theme,
    Map<int, List<Session>> daysWithSessions,
    AppState state,
  ) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 0=Sunday
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final today = DateTime.now();

    // Build 6 rows x 7 columns
    final rows = <Widget>[];
    var day = 1 - firstWeekday;

    for (int row = 0; row < 6; row++) {
      final cells = <Widget>[];
      for (int col = 0; col < 7; col++) {
        if (day < 1 || day > daysInMonth) {
          cells.add(const SizedBox(width: 44, height: 52));
        } else {
          final sessions = daysWithSessions[day];
          final hasSession = sessions != null && sessions.isNotEmpty;
          final isToday = day == today.day &&
              _currentMonth.month == today.month &&
              _currentMonth.year == today.year;

          cells.add(
            InkWell(
              onTap: hasSession
                  ? () => _showDaySessions(context, theme, day, sessions!, state)
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 44,
                height: 52,
                decoration: BoxDecoration(
                  color: isToday
                      ? theme.colorScheme.primaryContainer
                      : hasSession
                          ? theme.colorScheme.primary.withOpacity(0.08)
                          : null,
                  borderRadius: BorderRadius.circular(12),
                  border: isToday
                      ? Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isToday || hasSession ? FontWeight.w700 : FontWeight.w400,
                        color: hasSession
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (hasSession) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: sessions!.take(3).map((s) {
                          return Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: s.isArchived
                                  ? theme.colorScheme.tertiary
                                  : theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        day++;
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: cells,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  void _showDaySessions(
    BuildContext context,
    ThemeData theme,
    int day,
    List<Session> sessions,
    AppState state,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                '${_currentMonth.month}月${day}日',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${sessions.length} 次点名',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ...sessions.map((s) {
                final checkIns = state.getSessionCheckIns(s.id);
                final total = s.memberIds.length;
                final checked = checkIns.where((c) => c.statusId == 'tag_arrived').length;
                final rate = total > 0 ? (checked / total * 100).toStringAsFixed(0) : '0';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.title),
                  subtitle: Text('出勤率 $rate% ($checked/$total)'),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionScreen(sessionId: s.id),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  List<Session> _getMonthSessions(List<Session> sessions, DateTime month) {
    return sessions.where((s) {
      return s.createdAt.year == month.year && s.createdAt.month == month.month;
    }).toList();
  }
}
