import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import '../providers/app_state.dart';
import '../models/member.dart';
import '../utils/constants.dart';
import '../models/session.dart';
import '../models/status_tag.dart';
import '../widgets/filter_chip_bar.dart';
import '../widgets/swipe_person_card.dart';
import '../widgets/status_bottom_sheet.dart';
import '../widgets/operation_log_panel.dart';
import '../widgets/confetti_overlay.dart';
import 'member_history_screen.dart';
import 'export_screen.dart';
import 'share_image_screen.dart';
import 'wechat_relay_screen.dart';
import '../utils/expressive_theme.dart';
import '../widgets/glass_popup_menu.dart';
import '../widgets/liquid_glass.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final String sessionId;

  const SessionScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  String? _selectedFilter;
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  bool _isGridView = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 构建标准AppBar（非搜索模式）— 整块液态玻璃区域
  PreferredSizeWidget _buildNormalAppBar(Session session, AppState state) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.25),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.0,
                ),
              ),
              gradient: LinearGradient(
                begin: const Alignment(-0.8, -1.0),
                end: const Alignment(0.5, 0.3),
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.03),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.25, 0.6],
              ),
            ),
          ),
        ),
      ),
      title: Hero(
        tag: 'sessionTitle_${session.id}',
        child: Material(
          type: MaterialType.transparency,
          child: Text(
            session.title,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      centerTitle: true,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Filter chip bar
            FilterChipBar(
                sessionId: widget.sessionId,
                selectedFilter: _selectedFilter,
                onFilterChanged: (filter) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
              ),
              // Info row
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '共 ${session.memberIds.length} 人，已标记 ${state.getSessionCheckedCount(widget.sessionId)} 人',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      actions: [
        // 归档按钮（仅 ongoing 状态显示）
        if (session.status == 'ongoing')
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: '结束并归档',
            onPressed: () => _archiveSession(state),
          ),
        // 更多菜单按钮 - 玻璃拟态弹出菜单
        GlassPopupMenu(
          onSelected: (value) {
            switch (value) {
              case 'search':
                setState(() {
                  _isSearchExpanded = true;
                });
                break;
              case 'markAll':
                _confirmMarkAllArrived(state);
                break;
              case 'export':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExportScreen(sessionId: widget.sessionId),
                  ),
                );
                break;
              case 'shareImage':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShareImageScreen(sessionId: widget.sessionId),
                  ),
                );
                break;
              case 'addTag':
                _showAddTagDialog(context, state, useDistinctColor: true);
                break;
              case 'toggleView':
                setState(() {
                  _isGridView = !_isGridView;
                });
                break;
              case 'wechatRelay':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WechatRelayScreen(sessionId: widget.sessionId),
                  ),
                );
                break;
            }
          },
          items: [
            GlassMenuItem(
              value: 'search',
              child: const Row(
                children: [
                  Icon(Icons.search, size: 20),
                  SizedBox(width: 12),
                  Text('搜索'),
                ],
              ),
            ),
            GlassMenuItem(
              value: 'markAll',
              child: Row(
                children: [
                  Icon(Icons.done_all, size: 20, color: AppColors.success),
                  const SizedBox(width: 12),
                  Text(
                    '全部标记已到',
                    style: TextStyle(color: AppColors.success),
                  ),
                ],
              ),
            ),
            GlassMenuItem(
              value: 'export',
              child: const Row(
                children: [
                  Icon(Icons.file_copy_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('导出文字摘要'),
                ],
              ),
            ),
            GlassMenuItem(
              value: 'shareImage',
              child: const Row(
                children: [
                  Icon(Icons.image_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('分享图片'),
                ],
              ),
            ),
            GlassMenuItem(
              value: 'addTag',
              child: const Row(
                children: [
                  Icon(Icons.label_outline, size: 20),
                  SizedBox(width: 12),
                  Text('添加新标签'),
                ],
              ),
            ),
            GlassMenuItem(
              value: 'toggleView',
              child: Row(
                children: [
                  Icon(_isGridView ? Icons.view_list : Icons.grid_view, size: 20),
                  const SizedBox(width: 12),
                  Text(_isGridView ? '列表视图' : '网格视图'),
                ],
              ),
            ),
            GlassMenuItem(
              value: 'wechatRelay',
              child: const Row(
                children: [
                  Icon(Icons.chat_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('微信接龙'),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.more_vert),
          ),
        ),
      ],
    );
  }

  /// 构建搜索模式AppBar
  PreferredSizeWidget _buildSearchAppBar(Session session) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.25),
              gradient: LinearGradient(
                begin: const Alignment(-0.8, -1.0),
                end: const Alignment(0.5, 0.3),
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.03),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.25, 0.6],
              ),
            ),
          ),
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearchExpanded = false;
              _searchController.clear();
              _searchQuery = '';
            });
          },
        ),
      ),
      title: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: '搜索姓名或学号...',
          border: InputBorder.none,
          hintStyle: TextStyle(fontSize: 16),
        ),
        style: const TextStyle(fontSize: 16),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        autofocus: true,
      ),
      actions: [
        if (_searchQuery.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
              });
            },
          ),
      ],
    );
  }

  /// 显示添加标签对话框
  void _showAddTagDialog(BuildContext context, AppState state, {bool useDistinctColor = false}) {
    final nameController = TextEditingController();
    int selectedColorValue = useDistinctColor ? state.generateDistinctColor() : Colors.blue.value;
    final colorOptions = [
      ('蓝色', Colors.blue),
      ('绿色', Colors.green),
      ('橙色', Colors.orange),
      ('红色', Colors.red),
      ('紫色', Colors.purple),
      ('青色', Colors.teal),
    ];

    showExpressiveDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加新标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '标签名称',
                  hintText: '例如：请假、迟到',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '选择颜色',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: colorOptions.map((option) {
                  final (colorName, color) = option;
                  final isSelected = selectedColorValue == color.value;
                  return InkWell(
                    onTap: () {
                      setDialogState(() {
                        selectedColorValue = color.value;
                      });
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Theme.of(context).colorScheme.onPrimary, width: 2)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
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
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final newTag = StatusTag(
                    name: name,
                    colorValue: selectedColorValue,
                  );
                  state.addTag(newTag);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('标签 "$name" 已添加')),
                  );
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final session = state.getSessionById(widget.sessionId);
    final theme = Theme.of(context);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('点名'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                color: theme.colorScheme.surface.withOpacity(0.25),
              ),
            ),
          ),
        ),
        body: const Center(child: Text('点名不存在')),
      );
    }

    final members = state.getSortedSessionMembers(
      widget.sessionId,
      filterStatusId: _selectedFilter,
      searchQuery: _isSearchExpanded ? _searchQuery : null,
    );

    // When showing all (no filter), display a single fixed list sorted by studentId.
    // Members stay in place after marking — they just change color + tag.
    // When filtering, only show matching members in sorted order.
    final isShowingAll = _selectedFilter == null;

    if (isShowingAll) {
      // Fixed list: all members in studentId order, no splitting
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _isSearchExpanded
            ? _buildSearchAppBar(session)
            : _buildNormalAppBar(session, state),
        body: Column(
          children: [
            // Spacer for AppBar + bottom area (FilterChip & InfoRow now in AppBar bottom)
            SizedBox(height: MediaQuery.of(context).viewPadding.top + kToolbarHeight + 80),
            // Member list - fixed order when showing all
            Expanded(
              child: members.isEmpty
                  ? _buildEmptyState(theme, _isSearchExpanded, _selectedFilter)
                  : _isGridView
                      ? _buildGridView(members, state)
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final member = members[index];
                            final checkIn =
                                state.getActiveCheckIn(widget.sessionId, member.id);
                            final tag = checkIn?.statusId != null
                                ? state.getTagById(checkIn!.statusId!)
                                : null;
                            return SwipePersonCard(
                              member: member,
                              currentTag: tag,
                              onSwipeRight: () => _markAsArrived(state, member),
                              onSwipeLeft: () =>
                                  _showStatusSheet(context, state, member),
                              onLongPress: () =>
                                  _showMemberHistory(context, member),
                            );
                          },
                        ),
            ),
            // Undo bar
            if (session.status == 'ongoing')
              SafeArea(
                top: false,
                child: OperationLogPanel(sessionId: widget.sessionId),
              ),
          ],
        ),
      );
    }

    // ---- Filtered view: show only matching members ----
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _isSearchExpanded
          ? _buildSearchAppBar(session)
          : _buildNormalAppBar(session, state),
      body: Column(
        children: [
          // Spacer for AppBar + bottom area (FilterChip now in AppBar bottom)
          SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight + 80),
          Expanded(
            child: members.isEmpty
                ? _buildEmptyState(theme, _isSearchExpanded, _selectedFilter)
                : _isGridView
                    ? _buildGridView(members, state)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final checkIn =
                              state.getActiveCheckIn(widget.sessionId, member.id);
                          final tag = checkIn?.statusId != null
                              ? state.getTagById(checkIn!.statusId!)
                              : null;
                          return SwipePersonCard(
                            member: member,
                            currentTag: tag,
                            onSwipeRight: () => _markAsArrived(state, member),
                            onSwipeLeft: () =>
                                _showStatusSheet(context, state, member),
                            onLongPress: () =>
                                _showMemberHistory(context, member),
                          );
                        },
                      ),
          ),
          if (session.status == 'ongoing')
            SafeArea(
              top: false,
              child: OperationLogPanel(sessionId: widget.sessionId),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    ThemeData theme,
    bool isSearchExpanded,
    String? selectedFilter,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSearchExpanded
                ? Icons.search_off
                : selectedFilter != null
                    ? Icons.filter_list_off
                    : Icons.people_outline,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            isSearchExpanded
                ? '没有找到匹配的人员'
                : selectedFilter != null
                    ? '没有符合筛选条件的人员'
                    : '暂无人员',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 获取学号后两位
  String _getShortStudentId(String? studentId) {
    if (studentId == null || studentId.isEmpty) return '';
    final digits = studentId.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 2) return digits.substring(digits.length - 2);
    return studentId.length >= 2 ? studentId.substring(studentId.length - 2) : studentId;
  }

  /// 获取网格格子背景色（暗色模式适配）
  Color _getGridCellColor(StatusTag? tag, ThemeData theme) {
    if (tag == null) {
      // 未标记：使用卡片背景色
      return theme.colorScheme.surfaceContainerHighest;
    }
    // 已标记：使用标签颜色的浅色版本
    final baseColor = Color(tag.colorValue);
    final isDark = theme.brightness == Brightness.dark;
    if (isDark) {
      // 暗色模式：降低饱和度
      return baseColor.withOpacity(0.3);
    } else {
      // 亮色模式：浅色背景
      return baseColor.withOpacity(0.15);
    }
  }

  /// 获取网格格子文字颜色（暗色模式适配）
  Color _getGridCellTextColor(StatusTag? tag, ThemeData theme) {
    if (tag == null) {
      return theme.colorScheme.onSurface;
    }
    final baseColor = Color(tag.colorValue);
    final isDark = theme.brightness == Brightness.dark;
    if (isDark) {
      // 暗色模式：使用较亮的颜色
      return baseColor.withOpacity(0.9);
    } else {
      // 亮色模式：使用原色
      return baseColor;
    }
  }

  /// 构建网格视图
  Widget _buildGridView(List<Member> members, AppState state) {
    final theme = Theme.of(context);
    
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisExtent: 60,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        final checkIn = state.getActiveCheckIn(widget.sessionId, member.id);
        final tag = checkIn?.statusId != null
            ? state.getTagById(checkIn!.statusId!)
            : null;

        final backgroundColor = _getGridCellColor(tag, theme);
        final textColor = _getGridCellTextColor(tag, theme);
        final shortId = _getShortStudentId(member.studentId);

        return GestureDetector(
          onTap: () => _showStatusSheet(context, state, member),
          onLongPress: () => _showMemberHistory(context, member),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 姓名（居中，粗体）
                Hero(
                  tag: 'memberName_${member.id}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      member.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                // 学号后两位
                if (shortId.isNotEmpty)
                  Hero(
                    tag: 'studentId_${member.id}',
                    child: Material(
                      type: MaterialType.transparency,
                      child: Text(
                        shortId,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _markAsArrived(AppState state, Member member) {
    state.checkIn(
      sessionId: widget.sessionId,
      memberId: member.id,
      statusId: 'tag_arrived',
    );
  }

  void _showStatusSheet(
    BuildContext context,
    AppState state,
    Member member,
  ) {
    StatusBottomSheet.show(
      context,
      tags: state.tags,
      onStatusSelected: (tag, note) {
        state.checkIn(
          sessionId: widget.sessionId,
          memberId: member.id,
          statusId: tag.id,
          note: note,
        );
      },
      onEditTag: (updatedTag) {
        state.updateTag(updatedTag);
      },
    );
  }

  void _showMemberHistory(BuildContext context, Member member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberHistoryScreen(
          memberId: member.id,
          memberName: member.name,
        ),
      ),
    );
  }

  Future<void> _archiveSession(AppState state) async {
    final isComplete = state.isSessionComplete(widget.sessionId);
    if (!isComplete) {
      final forceArchive = await showExpressiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('点名未完成'),
          content: const Text('还有人员未标记状态，确定要归档吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续标记'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('强制归档'),
            ),
          ],
        ),
      );
      if (forceArchive != true) return;
    } else {
      final confirmed = await showExpressiveDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('结束并归档'),
          content: const Text('确定要结束本次点名并归档吗？归档后仍可查看记录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定归档'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await state.archiveSession(widget.sessionId);
    if (mounted) {
      // Show confetti effect if enabled
      if (state.confettiEnabled) {
        await Navigator.push(
          context,
          PageRouteBuilder(
            opaque: false,
            barrierDismissible: false,
            pageBuilder: (context, _, __) => const _ArchiveConfettiPage(),
          ),
        );
      }
      Navigator.pop(context);
    }
  }

  Future<void> _confirmMarkAllArrived(AppState state) async {
    final session = state.getSessionById(widget.sessionId);
    if (session == null) return;

    // Count unchecked members
    final uncheckedCount = session.memberIds.where((id) {
      final ci = state.getActiveCheckIn(widget.sessionId, id);
      return ci == null || ci.statusId != 'tag_arrived';
    }).length;

    if (uncheckedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有人员已标记为已到')),
      );
      return;
    }

    final confirmed = await showExpressiveDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.done_all, color: AppColors.success, size: 32),
        title: const Text('全部标记已到'),
        content: Text('将 $uncheckedCount 位未标记人员全部设为"已到达"，确定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.done_all),
            label: const Text('确认标记'),
            style: FilledButton.styleFrom(
              shape: ExpressiveShapes.pill,
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final count = await state.markAllAsArrived(widget.sessionId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已标记 $count 人为已到达')),
        );
      }
    }
  }
}

/// Temporary full-screen confetti overlay shown after archiving a session
class _ArchiveConfettiPage extends StatefulWidget {
  const _ArchiveConfettiPage();

  @override
  State<_ArchiveConfettiPage> createState() => _ArchiveConfettiPageState();
}

class _ArchiveConfettiPageState extends State<_ArchiveConfettiPage> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 3));
    _controller.play();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ConfettiOverlay(
          controller: _controller,
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.celebration,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                '点名完成！',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}