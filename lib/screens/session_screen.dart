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
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      appBar: AppBar(
        title: _isSearchExpanded
            ? TextField(
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
              )
            : Text(session.title),
        actions: [
          if (_isSearchExpanded)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearchExpanded = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearchExpanded = true;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.file_copy_outlined),
            tooltip: '导出文字摘要',
            onPressed: () => _showExportDialog(context, state, session),
          ),
          if (session.status == 'ongoing')
            TextButton.icon(
              onPressed: () => _archiveSession(state),
              icon: const Icon(Icons.archive_outlined, size: 18),
              label: const Text('结束并归档'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
        ],
      ),
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
      appBar: AppBar(
        title: _isSearchExpanded
            ? TextField(
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
              )
            : Text(session.title),
        actions: [
          if (_isSearchExpanded)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSearchExpanded = false;
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                setState(() {
                  _isSearchExpanded = true;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.file_copy_outlined),
            tooltip: '导出文字摘要',
            onPressed: () => _showExportDialog(context, state, session),
          ),
          if (session.status == 'ongoing')
            TextButton.icon(
              onPressed: () => _archiveSession(state),
              icon: const Icon(Icons.archive_outlined, size: 18),
              label: const Text('结束并归档'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
        ],
      ),
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
  String _generateExportText(AppState state, Session session) {
    final checkIns = state.getSessionCheckIns(widget.sessionId);
    final totalPeople = session.memberIds.length;

    // 按状态分组
    final statusGroups = <String, List<String>>{};
    for (final ci in checkIns) {
      if (ci.statusId == null) continue;
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
    final exportText = _generateExportText(state, session);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导出点名摘要'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                exportText,
                style: Theme.of(context).textTheme.bodyMedium,
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
      ),
    );
  }
}
