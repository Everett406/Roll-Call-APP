import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/app_state.dart';
import '../providers/theme_provider.dart';
import '../models/session.dart';
import '../models/status_tag.dart';
import '../utils/constants.dart';
import '../utils/expressive_theme.dart';
import '../widgets/liquid_glass.dart';
import '../services/update_service.dart';
import 'session_screen.dart';
import 'new_session_screen.dart';
import 'statistics_screen.dart';
import 'settings_screen.dart';
import 'random_picker_screen.dart';
import 'attendance_calendar_screen.dart';
import 'birthday_screen.dart';

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
  int _archivedFilterDays = 7; // Default: show last 7 days

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appStateProvider).loadData();
      _checkForUpdate();
      _checkSessionTimeouts();
    });
  }

  /// 启动时自动检查更新
  Future<void> _checkForUpdate() async {
    // 从 ThemeState 读取自动检查更新设置
    final themeState = ref.read(themeProvider);
    if (!themeState.autoCheckUpdate) return;

    final release = await UpdateService.checkUpdate();
    if (release != null && mounted) {
      _showUpdateDialog(release);
    }
  }

  /// 检查超时的进行中点名并处理
  Future<void> _checkSessionTimeouts() async {
    final state = ref.read(appStateProvider);
    final result = state.checkSessionTimeouts();

    // 自动归档超过24小时的
    for (final session in result.toArchive) {
      await state.archiveSession(session.id);
    }

    // 提醒12-24小时的
    if (result.toRemind.isNotEmpty && mounted) {
      for (final session in result.toRemind) {
        final elapsed = DateTime.now().difference(session.createdAt);
        final hours = elapsed.inHours;
        final minutes = elapsed.inMinutes % 60;

        if (!mounted) return;
        final action = await showExpressiveDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('点名超时提醒'),
            content: Text('「${session.title}」已创建 ${hours}小时${minutes}分钟，是否需要处理？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'keep'),
                child: const Text('继续保留'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'archive'),
                child: const Text('归档'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(context, 'delete'),
                child: const Text('删除'),
              ),
            ],
          ),
        );

        if (action == 'archive') {
          await state.archiveSession(session.id);
        } else if (action == 'delete') {
          await state.deleteSession(session.id);
        }
      }
    }
  }

  /// 显示更新提示对话框
  void _showUpdateDialog(ReleaseInfo release) {
    final theme = Theme.of(context);

    showExpressiveDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.system_update, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text('发现新版本'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '最新版本: ${release.version}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '更新说明:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(
                  release.body.isNotEmpty ? release.body : '暂无更新说明',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('稍后更新'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (release.downloadUrl != null) {
                UpdateService.downloadAndInstall(release.downloadUrl!);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('正在后台下载，请查看通知栏'),
                    duration: Duration(seconds: 3),
                  ),
                );
              } else {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('未找到下载链接')),
                );
              }
            },
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
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

  /// 显示更多功能菜单
  void _showMoreMenu(BuildContext context) {
    final theme = Theme.of(context);
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.left - 100,
        position.top + 40,
        position.right,
        position.bottom,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surface,
      items: [
        PopupMenuItem(
          value: 'random',
          child: Row(
            children: [
              Icon(Icons.casino_outlined, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              const Text('随机点名'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'birthday',
          child: Row(
            children: [
              Icon(Icons.cake_outlined, size: 20, color: theme.colorScheme.tertiary),
              const SizedBox(width: 12),
              const Text('生日提醒'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'random') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RandomPickerScreen()),
        );
      } else if (value == 'birthday') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BirthdayScreen()),
        );
      }
    });
  }

  /// 显示帮助面板
  void _showHelpPanel(BuildContext context) {
    Navigator.of(context).push(_HelpPanelRoute());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        title: Text(
          '点到为止',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface.withOpacity(0.85),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            tooltip: '更多功能',
            onPressed: () => _showMoreMenu(context),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpPanel(context),
          ),
        ],
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const BouncingScrollPhysics(),
          children: [
            const StatisticsScreen(),
            _buildOngoingList(state, theme),
            _buildArchivedList(state, theme),
            const SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.25),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.0,
                ),
              ),
              gradient: LinearGradient(
                begin: const Alignment(-0.8, -1.0),
                end: const Alignment(0.5, 0.5),
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.03),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.25, 0.6],
              ),
            ),
            child: SafeArea(
              top: false,
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                selectedIndex: _currentIndex,
                onDestinationSelected: _onNavItemTapped,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: '统计',
                  ),
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
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: '设置',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: (_currentIndex == 1 || _currentIndex == 2)
          ? Hero(
              tag: 'createButton',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: FloatingActionButton.extended(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        _zoomRoute(const NewSessionScreen()),
                      );
                      if (result == true) {
                        ref.read(appStateProvider).loadData();
                      }
                    },
                    shape: ExpressiveShapes.fab,
                    elevation: 0,
                    backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.65),
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    icon: const Icon(Icons.add),
                    label: const Text(
                      '新建点名',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
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

    // 计算进行中数量用于 Hero 动画
    final ongoingCount = sessions.length;

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
          return _SessionCard(
            session: sessions[sessionIndex],
            heroTag: sessionIndex == 0 ? 'sessionTitle_${sessions[sessionIndex].id}' : null,
          );
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
    final now = DateTime.now();

    // Filter sessions based on _archivedFilterDays
    final sessions = _archivedFilterDays == 0
        ? state.archivedSessions.toList()
        : state.archivedSessions.where((s) {
            final endedAt = s.endedAt;
            if (endedAt == null) return false;
            return endedAt.isAfter(now.subtract(Duration(days: _archivedFilterDays)));
          }).toList();

    return Column(
      children: [
        // Calendar + Filter header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                tooltip: '点名日历',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AttendanceCalendarScreen(),
                    ),
                  );
                },
              ),
              const Spacer(),
            ],
          ),
        ),
        // Filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7天')),
                    ButtonSegment(value: 30, label: Text('30天')),
                    ButtonSegment(value: 0, label: Text('全部')),
                  ],
                  selected: <int>{_archivedFilterDays},
                  onSelectionChanged: (Set<int> newSelection) {
                    setState(() {
                      _archivedFilterDays = newSelection.first;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        // Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '共 ${sessions.length} 条记录',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: sessions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _archivedFilterDays == 0
                            ? '暂无历史记录'
                            : '该时间段暂无记录',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    return _SessionCard(
                      session: sessions[index],
                      isArchived: true,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// 帮助面板路由 - 亚克力质感的弹出面板
class _HelpPanelRoute extends PopupRoute<void> {
  @override
  Color? get barrierColor => Colors.black54;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => '关闭';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _HelpPanelContent();
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: child,
      ),
    );
  }
}

class _HelpPanelContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题栏
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.help_outline,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '帮助',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // 内容（可滚动）
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      children: [
                        // 新人必读
                        _buildHelpSection(
                          theme,
                          icon: Icons.school_outlined,
                          title: '新人必读',
                          children: [
                            _buildHelpItem(theme, number: '1', title: '如何创建点名？', content: '点击右下角"新建点名"按钮'),
                            _buildHelpItem(theme, number: '2', title: '如何标记状态？', content: '左滑已到，右滑选择状态'),
                            _buildHelpItem(theme, number: '3', title: '如何导出结果？', content: '右上角菜单→导出文字摘要'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 功能说明
                        _buildHelpSection(
                          theme,
                          icon: Icons.widgets_outlined,
                          title: '功能说明',
                          children: [
                            _buildFeatureItem(theme, icon: Icons.grid_view, title: '网格/列表视图', content: '右上角菜单切换'),
                            _buildFeatureItem(theme, icon: Icons.swipe, title: '滑动删除', content: '人员管理页面左滑删除'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // 注意事项
                        _buildHelpSection(
                          theme,
                          icon: Icons.warning_amber_outlined,
                          title: '注意事项',
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.backup_outlined, color: theme.colorScheme.error, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '请定期在设置中导出备份数据',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onErrorContainer,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildHelpSection(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildHelpItem(
    ThemeData theme, {
    required String number,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  content,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                Text(
                  content,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
  final int count;
  final String label;

  _ProgressSegment({
    required this.color,
    required this.percentage,
    this.count = 0,
    this.label = '',
  });
}

class _SessionCard extends ConsumerWidget {
  final Session session;
  final bool isArchived;
  final String? heroTag;

  const _SessionCard({required this.session, this.isArchived = false, this.heroTag});

  /// 显示删除确认对话框，返回是否确认删除
  Future<bool> _showDeleteConfirmDialog(BuildContext context, AppState state) async {
    // First confirmation dialog
    final firstConfirm = await showExpressiveDialog<bool>(
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
    final secondConfirm = await showExpressiveDialog<bool>(
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
    final segments = _buildSegments(state, statusCounts, totalCount, theme);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: ExpressiveShapes.cardMedium,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            _zoomRoute(SessionScreen(sessionId: session.id)),
          );
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: heroTag != null
                        ? Hero(
                            tag: heroTag!,
                            child: Material(
                              type: MaterialType.transparency,
                              child: Text(
                                session.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        : Text(
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
                  // 删除按钮：归档和历史记录都显示
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
    );
  }

  List<_ProgressSegment> _buildSegments(
      AppState state, Map<String, int> statusCounts, int totalCount, ThemeData theme) {
    if (totalCount == 0) return [];

    final segments = <_ProgressSegment>[];

    // Calculate total checked count
    final totalChecked = statusCounts.values.fold(0, (a, b) => a + b);

    // If no one is checked, show gray for unchecked
    if (totalChecked == 0) {
      return [
        _ProgressSegment(
          color: theme.colorScheme.surfaceContainerHighest,
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
            count: count,
            label: tag.name,
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
          color: theme.colorScheme.surfaceContainerHighest,
          percentage: percentage,
          count: uncheckedCount,
          label: '未标记',
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
    final state = ref.watch(appStateProvider);
    final showPercentage = state.showPercentageOnCards;

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: segments.map((seg) {
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
              showPercentage
                  ? '${seg.label} ${seg.percentage}%'
                  : '${seg.label} ${seg.count}人',
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
