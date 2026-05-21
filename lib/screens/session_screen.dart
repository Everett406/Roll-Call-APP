import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/status_tag.dart';
import '../widgets/filter_chip_bar.dart';
import '../widgets/swipe_person_card.dart';
import '../widgets/status_bottom_sheet.dart';
import '../widgets/undo_bar.dart';
import 'member_history_screen.dart';

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

  /// 构建标准AppBar（非搜索模式）
  AppBar _buildNormalAppBar(Session session, AppState state) {
    final theme = Theme.of(context);
    return AppBar(
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
      actions: [
        // 归档按钮（仅 ongoing 状态显示）
        if (session.status == 'ongoing')
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: '结束并归档',
            onPressed: () => _archiveSession(state),
          ),
        // 更多菜单按钮
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            switch (value) {
              case 'search':
                setState(() {
                  _isSearchExpanded = true;
                });
                break;
              case 'export':
                _showExportDialog(context, state, session);
                break;
              case 'addTag':
                _showAddTagDialog(context, state, useDistinctColor: true);
                break;
              case 'toggleView':
                setState(() {
                  _isGridView = !_isGridView;
                });
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'search',
              child: Row(
                children: [
                  Icon(Icons.search),
                  SizedBox(width: 8),
                  Text('搜索'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.file_copy_outlined),
                  SizedBox(width: 8),
                  Text('导出文字摘要'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'addTag',
              child: Row(
                children: [
                  Icon(Icons.label_outline),
                  SizedBox(width: 8),
                  Text('添加新标签'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'toggleView',
              child: Row(
                children: [
                  Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  const SizedBox(width: 8),
                  Text(_isGridView ? '列表视图' : '网格视图'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建搜索模式AppBar
  AppBar _buildSearchAppBar(Session session) {
    final theme = Theme.of(context);
    return AppBar(
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

    showDialog(
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
                            ? Border.all(color: Colors.white, width: 2)
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
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
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
        appBar: AppBar(title: const Text('点名')),
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
        appBar: _isSearchExpanded
            ? _buildSearchAppBar(session)
            : _buildNormalAppBar(session, state),
        body: Column(
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
            if (!_isSearchExpanded)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                child: UndoBar(sessionId: widget.sessionId),
              ),
          ],
        ),
      );
    }

    // ---- Filtered view: show only matching members ----
    return Scaffold(
      appBar: _isSearchExpanded
          ? _buildSearchAppBar(session)
          : _buildNormalAppBar(session, state),
      body: Column(
        children: [
          FilterChipBar(
            sessionId: widget.sessionId,
            selectedFilter: _selectedFilter,
            onFilterChanged: (filter) {
              setState(() {
                _selectedFilter = filter;
              });
            },
          ),
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
              child: UndoBar(sessionId: widget.sessionId),
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
      final forceArchive = await showDialog<bool>(
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
      final confirmed = await showDialog<bool>(
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
    if (mounted) Navigator.pop(context);
  }

  /// 生成文字导出摘要
  String _generateExportText(AppState state, Session session, {bool includeArrived = true}) {
    final checkIns = state.getSessionCheckIns(widget.sessionId);
    final totalPeople = session.memberIds.length;

    // 按状态分组
    final statusGroups = <String, List<String>>{};
    for (final ci in checkIns) {
      if (ci.statusId == null) continue;
      // 如果不包含已到达，跳过
      if (!includeArrived && ci.statusId == 'tag_arrived') continue;
      final tag = state.getTagById(ci.statusId!);
      final tagName = tag?.name ?? '未知状态';
      // 获取成员名称
      final memberIdx = session.memberIds.indexOf(ci.memberId);
      String memberName;
      if (memberIdx >= 0 && memberIdx < session.memberNames.length) {
        memberName = session.memberNames[memberIdx];
      } else {
        final member = state.getMemberById(ci.memberId);
        memberName = member?.name ?? '未知';
      }
      statusGroups.putIfAbsent(tagName, () => []);
      statusGroups[tagName]!.add(memberName);
    }

    // 计算已到人数
    final arrivedCount = checkIns
        .where((c) => c.statusId == 'tag_arrived')
        .length;

    final buffer = StringBuffer();
    buffer.writeln(session.title);
    buffer.writeln('应到：$totalPeople人  实到：$arrivedCount人');
    buffer.writeln();

    // 按状态分组输出
    for (final entry in statusGroups.entries) {
      final names = entry.value;
      if (names.isEmpty) continue;
      buffer.writeln('${entry.key}（${names.length}）：');
      buffer.writeln(names.join('\u3001'));
      buffer.writeln();
    }

    return buffer.toString().trimRight();
  }

  /// 显示导出对话框
  void _showExportDialog(BuildContext context, AppState state, Session session) {
    bool includeArrived = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final exportText = _generateExportText(state, session, includeArrived: includeArrived);
            final theme = Theme.of(context);

            return AlertDialog(
              title: const Text('导出点名摘要'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 开关：是否包含已到达
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('包含已到达人员'),
                    subtitle: const Text('关闭后只显示未到和其他状态'),
                    value: includeArrived,
                    onChanged: (val) {
                      setDialogState(() {
                        includeArrived = val;
                      });
                    },
                    dense: true,
                  ),
                  const SizedBox(height: 8),
                  // 导出内容预览
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    width: double.maxFinite,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        exportText,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: exportText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已复制到剪贴板'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('复制'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
