import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../models/member.dart';
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

class _SessionScreenState extends ConsumerState<SessionScreen>
    with TickerProviderStateMixin {
  String? _selectedFilter;
  String _searchQuery = '';
  bool _isSearchExpanded = false;
  final _searchController = TextEditingController();
  
  // 动画相关
  final GlobalKey<AnimatedListState> _uncheckedListKey = GlobalKey();
  final GlobalKey<AnimatedListState> _checkedListKey = GlobalKey();
  List<String> _previousUncheckedIds = [];
  List<String> _previousCheckedIds = [];

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

    // Split members into checked and unchecked
    final uncheckedMembers = members.where((m) {
      final checkIn = state.getActiveCheckIn(widget.sessionId, m.id);
      return checkIn == null;
    }).toList();
    final checkedMembers = members.where((m) {
      final checkIn = state.getActiveCheckIn(widget.sessionId, m.id);
      return checkIn != null;
    }).toList();

    // 检测变化并触发动画
    final currentUncheckedIds = uncheckedMembers.map((m) => m.id).toList();
    final currentCheckedIds = checkedMembers.map((m) => m.id).toList();
    
    // 更新之前的列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previousUncheckedIds = currentUncheckedIds;
      _previousCheckedIds = currentCheckedIds;
    });

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
          // Info row when not searching
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
                    '共 ${session.memberIds.length} 人，已标记 ${checkedMembers.length} 人',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          // Member list
          Expanded(
            child: members.isEmpty
                ? _buildEmptyState(theme, _isSearchExpanded, _selectedFilter)
                : _buildAnimatedList(
                    context,
                    theme,
                    state,
                    uncheckedMembers,
                    checkedMembers,
                  ),
          ),
          // Undo bar at bottom
          if (session.status == 'ongoing')
            SafeArea(
              top: false,
              child: UndoBar(sessionId: widget.sessionId),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isSearchExpanded, String? selectedFilter) {
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

  Widget _buildAnimatedList(
    BuildContext context,
    ThemeData theme,
    AppState state,
    List<Member> uncheckedMembers,
    List<Member> checkedMembers,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // 未标记区域标题
        if (uncheckedMembers.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '待标记',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${uncheckedMembers.length}人',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

        // 未标记成员列表
        ...uncheckedMembers.map((member) => TweenAnimationBuilder<double>(
          key: ValueKey('unchecked-${member.id}'),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, (1 - value) * 20),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: SwipePersonCard(
            member: member,
            currentTag: null,
            onSwipeRight: () => _markAsArrived(state, member),
            onSwipeLeft: () => _showStatusSheet(context, state, member),
            onLongPress: () => _showMemberHistory(context, member),
          ),
        )),

        // 分隔线
        if (uncheckedMembers.isNotEmpty && checkedMembers.isNotEmpty)
          _buildDivider(theme, checkedMembers.length),

        // 已标记区域标题
        if (checkedMembers.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '已标记',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${checkedMembers.length}人',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

        // 已标记成员列表（带背景色区分）
        if (checkedMembers.isNotEmpty)
          Container(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Column(
              children: checkedMembers.map((member) {
                final checkIn = state.getActiveCheckIn(widget.sessionId, member.id);
                final tag = checkIn?.statusId != null
                    ? state.getTagById(checkIn!.statusId!)
                    : null;

                return TweenAnimationBuilder<double>(
                  key: ValueKey('checked-${member.id}'),
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, (1 - value) * -30),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: SwipePersonCard(
                    member: member,
                    currentTag: tag,
                    onSwipeRight: () => _markAsArrived(state, member),
                    onSwipeLeft: () => _showStatusSheet(context, state, member),
                    onLongPress: () => _showMemberHistory(context, member),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildDivider(ThemeData theme, int checkedCount) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    theme.colorScheme.outlineVariant,
                    theme.colorScheme.outlineVariant,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  '已标记 $checkedCount 人',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    theme.colorScheme.outlineVariant,
                    theme.colorScheme.outlineVariant,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.2, 0.8, 1.0],
                ),
              ),
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

      if (forceArchive != true) {
        return;
      }
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

      if (confirmed != true) {
        return;
      }
    }

    await state.archiveSession(widget.sessionId);
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
