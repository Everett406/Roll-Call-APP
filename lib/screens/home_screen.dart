import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../models/session.dart';
import '../models/status_tag.dart';
import '../utils/constants.dart';
import 'session_screen.dart';
import 'new_session_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';

/// 页面过渡动画辅助
PageRouteBuilder<T> _zoomRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: Tween(begin: 0.9, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 250),
  );
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appStateProvider).loadData();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onNavItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('点到为止'),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildOngoingList(state, theme),
          _buildArchivedList(state, theme),
          const StatisticsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onNavItemTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radio_button_checked_outlined),
            selectedIcon: Icon(Icons.radio_button_checked),
            label: '进行中',
          ),
          NavigationDestination(
            icon: Icon(Icons.archive_outlined),
            selectedIcon: Icon(Icons.archive),
            label: '历史',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
      floatingActionButton: _currentIndex <= 1
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  _zoomRoute(const NewSessionScreen()),
                );
                if (result == true) {
                  ref.read(appStateProvider).loadData();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('新建点名'),
            )
          : null,
    );
  }

  Widget _buildOngoingList(AppState state, ThemeData theme) {
    final sessions = state.ongoingSessions;

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_rtl_outlined,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无进行中的点名',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角按钮新建点名',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate legend data from all ongoing sessions
    final legendData = _calculateLegendData(state, sessions);

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(appStateProvider).loadData();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: sessions.length + (legendData.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          // First item is the legend if there is data
          if (legendData.isNotEmpty && index == 0) {
            return _buildLegendBar(legendData, theme);
          }
          final sessionIndex = legendData.isNotEmpty ? index - 1 : index;
          return _SessionCard(session: sessions[sessionIndex]);
        },
      ),
    );
  }

  /// Calculate legend data from all ongoing sessions
  List<_LegendItem> _calculateLegendData(AppState state, List<Session> sessions) {
    final tagCounts = <String, int>{};
    int totalChecked = 0;

    for (final session in sessions) {
      final checkIns = state.getSessionCheckIns(session.id);
      totalChecked += checkIns.length;
      for (final ci in checkIns) {
        if (ci.statusId != null) {
          tagCounts[ci.statusId!] = (tagCounts[ci.statusId!] ?? 0) + 1;
        }
      }
    }

    if (totalChecked == 0) return [];

    final legendItems = <_LegendItem>[];
    tagCounts.forEach((tagId, count) {
      final tag = state.getTagById(tagId) ?? _getDefaultTag(tagId);
      legendItems.add(_LegendItem(
        tag: tag,
        count: count,
      ));
    });

    // Sort by count descending
    legendItems.sort((a, b) => b.count.compareTo(a.count));
    return legendItems;
  }

  StatusTag _getDefaultTag(String tagId) {
    return StatusTag(
      id: tagId,
      name: tagId == 'tag_arrived' ? '已到达' : tagId == 'tag_absent' ? '未到' : '其他',
      colorValue: tagId == 'tag_arrived' ? 0xFF4CAF50 : 0xFF9E9E9E,
      isBuiltIn: true,
    );
  }

  Widget _buildLegendBar(List<_LegendItem> items, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(item.tag.colorValue),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${item.tag.name} ${item.count}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
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

  Widget _buildArchivedList(AppState state, ThemeData theme) {
    final sessions = state.archivedSessions;

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无历史记录',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        return _SessionCard(
          session: sessions[index],
          isArchived: true,
        );
      },
    );
  }
}

/// Data class for legend items
class _LegendItem {
  final StatusTag tag;
  final int count;

  _LegendItem({required this.tag, required this.count});
}

/// Segmented progress bar item
class _ProgressSegment {
  final Color color;
  final int percentage;

  _ProgressSegment({required this.color, required this.percentage});
}

class _SessionCard extends ConsumerWidget {
  final Session session;
  final bool isArchived;

  const _SessionCard({required this.session, this.isArchived = false});

  /// 显示删除确认对话框，返回是否确认删除
  Future<bool> _showDeleteConfirmDialog(BuildContext context, AppState state) async {
    // First confirmation dialog
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除点名'),
        content: const Text('确定要删除这个点名记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !context.mounted) return false;

    // Second confirmation dialog
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('二次确认'),
        content: const Text('此操作不可恢复，您确定要继续删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (secondConfirm == true) {
      await state.deleteSession(session.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除点名记录')),
        );
      }
      return true;
    }
    return false;
  }

  Future<void> _deleteSession(BuildContext context, AppState state) async {
    await _showDeleteConfirmDialog(context, state);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);
    final arrivedCount = state.getSessionArrivedCount(session.id);
    final totalCount = session.memberIds.length;
    final dateFormat = DateFormat('MM/dd HH:mm');

    // Get status counts for segmented progress bar
    final statusCounts = state.getSessionStatusCounts(session.id);
    final segments = _buildSegments(state, statusCounts, totalCount);

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmDialog(context, state);
      },
      child: GestureDetector(
        onLongPress: isArchived
            ? () => _deleteSession(context, state)
            : null,
        child: Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                _zoomRoute(SessionScreen(sessionId: session.id)),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          session.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isArchived)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '已归档',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (isArchived)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: theme.colorScheme.error,
                          onPressed: () => _deleteSession(context, state),
                          tooltip: '删除',
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time,
                          size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        dateFormat.format(session.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '实到 $arrivedCount / 应到 $totalCount',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: arrivedCount == totalCount
                              ? AppColors.success
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Segmented progress bar
                  _buildSegmentedProgressBar(segments, theme),
                  const SizedBox(height: 8),
                  // Legend for segments (only shown if there are segments)
                  if (segments.isNotEmpty)
                    _buildSegmentLegend(segments, theme, ref),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_ProgressSegment> _buildSegments(
      AppState state, Map<String, int> statusCounts, int totalCount) {
    if (totalCount == 0) return [];

    final segments = <_ProgressSegment>[];

    // Calculate total checked count
    final totalChecked = statusCounts.values.fold(0, (a, b) => a + b);

    // If no one is checked, show gray for unchecked
    if (totalChecked == 0) {
      return [
        _ProgressSegment(
          color: Colors.grey.shade300,
          percentage: 100,
        ),
      ];
    }

    // Add segments for each status
    statusCounts.forEach((tagId, count) {
      if (count > 0) {
        final tag = state.getTagById(tagId) ?? _getDefaultTag(tagId);
        final percentage = ((count / totalCount) * 100).round();
        if (percentage > 0) {
          segments.add(_ProgressSegment(
            color: Color(tag.colorValue),
            percentage: percentage,
          ));
        }
      }
    });

    // If there are unchecked members, add them as gray
    final uncheckedCount = totalCount - totalChecked;
    if (uncheckedCount > 0) {
      final percentage = ((uncheckedCount / totalCount) * 100).round();
      if (percentage > 0) {
        segments.add(_ProgressSegment(
          color: Colors.grey.shade300,
          percentage: percentage,
        ));
      }
    }

    return segments;
  }

  StatusTag _getDefaultTag(String tagId) {
    return StatusTag(
      id: tagId,
      name: tagId == 'tag_arrived' ? '已到达' : tagId == 'tag_absent' ? '未到' : '其他',
      colorValue: tagId == 'tag_arrived' ? 0xFF4CAF50 : 0xFF9E9E9E,
      isBuiltIn: true,
    );
  }

  Widget _buildSegmentedProgressBar(
      List<_ProgressSegment> segments, ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: segments.map((seg) {
            return Expanded(
              flex: seg.percentage,
              child: Container(color: seg.color),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSegmentLegend(List<_ProgressSegment> segments, ThemeData theme, WidgetRef ref) {
    // Build legend from session status counts
    final state = ref.read(appStateProvider);
    final statusCounts = state.getSessionStatusCounts(session.id);

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: segments.map((seg) {
        // Find the tag name for this segment's color
        String tagName = '未标记';
        for (final entry in statusCounts.entries) {
          final tag = state.getTagById(entry.key) ?? _getDefaultTag(entry.key);
          if (Color(tag.colorValue) == seg.color) {
            tagName = tag.name;
            break;
          }
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: seg.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$tagName ${seg.percentage}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
