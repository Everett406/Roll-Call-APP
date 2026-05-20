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

  // AnimatedList key for unchecked members
  final GlobalKey<AnimatedListState> _uncheckedListKey = GlobalKey();

  // Track previous unchecked member list to detect removals
  List<Member> _prevUncheckedMembers = [];

  // Track which status groups are expanded
  final Set<String> _expandedGroups = {};

  // Animation controllers for each status group
  final Map<String, AnimationController> _groupControllers = {};
  final Map<String, Animation<double>> _groupAnimations = {};

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _groupControllers.values) {
      controller.dispose();
    }
    _groupControllers.clear();
    _groupAnimations.clear();
    super.dispose();
  }

  AnimationController _getGroupController(String tagId) {
    return _groupControllers.putIfAbsent(tagId, () {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      );
      _groupAnimations[tagId] = CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      );
      return controller;
    });
  }

  void _toggleGroup(String tagId) {
    setState(() {
      if (_expandedGroups.contains(tagId)) {
        _expandedGroups.remove(tagId);
        _getGroupController(tagId).reverse();
      } else {
        _expandedGroups.add(tagId);
        _getGroupController(tagId).forward();
      }
    });
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

    // Detect unchecked members that were removed (marked) and animate them out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animateUncheckedChanges(uncheckedMembers);
    });

    // Build status groups for checked members
    final statusGroups = _buildStatusGroups(state, checkedMembers);

    // Clean up controllers for groups that no longer exist
    _cleanupGroupControllers(statusGroups);

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
                // Reset unchecked tracking when filter changes
                _prevUncheckedMembers = List.from(uncheckedMembers);
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
                : _buildMemberList(
                    context,
                    theme,
                    state,
                    uncheckedMembers,
                    checkedMembers,
                    statusGroups,
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

  // ---------------------------------------------------------------
  // AnimatedList change detection for unchecked members
  // ---------------------------------------------------------------
  void _animateUncheckedChanges(List<Member> currentUnchecked) {
    final listState = _uncheckedListKey.currentState;
    if (listState == null) {
      _prevUncheckedMembers = List.from(currentUnchecked);
      return;
    }

    // Detect removed items (member was checked in)
    final currentIds = currentUnchecked.map((m) => m.id).toSet();
    final prevIds = _prevUncheckedMembers.map((m) => m.id).toSet();

    // Items that were in previous but not in current -> removed
    final removedIds = prevIds.difference(currentIds);

    for (final removedId in removedIds) {
      final removedIndex =
          _prevUncheckedMembers.indexWhere((m) => m.id == removedId);
      if (removedIndex != -1) {
        listState.removeItem(
          removedIndex,
          (context, animation) {
            return SizeTransition(
              sizeFactor: animation,
              axisAlignment: 0.0,
              child: FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset.zero,
                    end: const Offset(0, 0.3),
                  ).animate(animation),
                  child: SwipePersonCard(
                    member: _prevUncheckedMembers[removedIndex],
                    currentTag: null,
                    onSwipeRight: () {},
                    onSwipeLeft: () {},
                    onLongPress: () {},
                  ),
                ),
              ),
            );
          },
          duration: const Duration(milliseconds: 350),
        );
      }
    }

    // Detect added items (undo happened, member back to unchecked)
    final addedIds = currentIds.difference(prevIds);

    for (final addedId in addedIds) {
      final addedIndex =
          currentUnchecked.indexWhere((m) => m.id == addedId);
      if (addedIndex != -1) {
        listState.insertItem(addedIndex, duration: const Duration(milliseconds: 350));
      }
    }

    _prevUncheckedMembers = List.from(currentUnchecked);
  }

  // ---------------------------------------------------------------
  // Build status groups: Map<tagId, List<Member>>
  // ---------------------------------------------------------------
  List<MapEntry<String, List<Member>>> _buildStatusGroups(
    AppState state,
    List<Member> checkedMembers,
  ) {
    final groups = <String, List<Member>>{};
    for (final member in checkedMembers) {
      final checkIn = state.getActiveCheckIn(widget.sessionId, member.id);
      final statusId = checkIn?.statusId ?? 'unknown';
      groups.putIfAbsent(statusId, () => []).add(member);
    }

    // Sort groups by count descending
    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    return entries;
  }

  // ---------------------------------------------------------------
  // Clean up animation controllers for groups that no longer exist
  // ---------------------------------------------------------------
  void _cleanupGroupControllers(
    List<MapEntry<String, List<Member>>> statusGroups,
  ) {
    final activeTagIds = statusGroups.map((e) => e.key).toSet();
    final staleKeys =
        _groupControllers.keys.where((k) => !activeTagIds.contains(k)).toList();
    for (final key in staleKeys) {
      _groupControllers[key]?.dispose();
      _groupControllers.remove(key);
      _groupAnimations.remove(key);
      _expandedGroups.remove(key);
    }
  }

  // ---------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
  // Main member list builder
  // ---------------------------------------------------------------
  Widget _buildMemberList(
    BuildContext context,
    ThemeData theme,
    AppState state,
    List<Member> uncheckedMembers,
    List<Member> checkedMembers,
    List<MapEntry<String, List<Member>>> statusGroups,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // ---- Unchecked section header ----
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

        // ---- AnimatedList for unchecked members ----
        if (uncheckedMembers.isNotEmpty)
          SizedBox(
            height: uncheckedMembers.length * 72.0,
            child: AnimatedList(
              key: _uncheckedListKey,
              initialItemCount: uncheckedMembers.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index, animation) {
                final member = uncheckedMembers[index];
                return SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: 0.0,
                  child: FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.15),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: SwipePersonCard(
                        member: member,
                        currentTag: null,
                        onSwipeRight: () => _markAsArrived(state, member),
                        onSwipeLeft: () =>
                            _showStatusSheet(context, state, member),
                        onLongPress: () => _showMemberHistory(context, member),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // ---- Divider between unchecked and checked ----
        if (uncheckedMembers.isNotEmpty && checkedMembers.isNotEmpty)
          _buildDivider(theme, checkedMembers.length),

        // ---- Checked section header ----
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

        // ---- Status-grouped checked members ----
        if (checkedMembers.isNotEmpty)
          Container(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            child: Column(
              children: statusGroups.map((entry) {
                final tagId = entry.key;
                final groupMembers = entry.value;
                final tag = state.getTagById(tagId);
                return _buildStatusGroup(
                  theme,
                  state,
                  tagId,
                  tag,
                  groupMembers,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // Status group with expand / collapse animation
  // ---------------------------------------------------------------
  Widget _buildStatusGroup(
    ThemeData theme,
    AppState state,
    String tagId,
    StatusTag? tag,
    List<Member> groupMembers,
  ) {
    final tagColor = tag != null ? Color(tag.colorValue) : theme.colorScheme.outline;
    final tagName = tag?.name ?? '未知状态';
    final isExpanded = _expandedGroups.contains(tagId);
    final controller = _getGroupController(tagId);
    final animation = _groupAnimations[tagId]!;

    // Ensure animation state matches expansion state
    if (isExpanded && !controller.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.forward();
      });
    } else if (!isExpanded && !controller.isDismissed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.reverse();
      });
    }

    return Column(
      children: [
        // Group header - tappable
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleGroup(tagId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Status color dot
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: tagColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Status name
                  Text(
                    tagName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: tagColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Member count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: tagColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${groupMembers.length}人',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: tagColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Expand / collapse icon
                  RotationTransition(
                    turns: animation,
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Animated group content
        SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1.0,
          child: FadeTransition(
            opacity: animation,
            child: Column(
              children: groupMembers.map((member) {
                return SwipePersonCard(
                  member: member,
                  currentTag: tag,
                  onSwipeRight: () => _markAsArrived(state, member),
                  onSwipeLeft: () =>
                      _showStatusSheet(context, state, member),
                  onLongPress: () => _showMemberHistory(context, member),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // Divider between unchecked and checked sections
  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------
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
