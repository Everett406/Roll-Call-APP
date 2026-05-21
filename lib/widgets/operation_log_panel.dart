import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/expressive_theme.dart';
import '../models/operation_log.dart';

/// ============================================================
/// Operation Log Panel - Replaces UndoBar
/// ============================================================
/// Collapsible floating panel showing operation history.
/// - Collapsed: shows last action + expand button
/// - Expanded: full BottomSheet with all operations, tap to undo to that point
///
class OperationLogPanel extends ConsumerStatefulWidget {
  final String sessionId;

  const OperationLogPanel({super.key, required this.sessionId});

  @override
  ConsumerState<OperationLogPanel> createState() => _OperationLogPanelState();
}

class _OperationLogPanelState extends ConsumerState<OperationLogPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: ExpressiveCurves.quickSpring,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final logs = state.logs
        .where((l) => l.sessionId == widget.sessionId && l.type == 'check_in')
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final theme = Theme.of(context);

    if (logs.isEmpty) {
      _animationController.reverse();
      return const SizedBox.shrink();
    }

    // Show collapsed bar
    final lastLog = logs.first;
    final member = state.getMemberById(lastLog.targetMemberId);
    final tag = lastLog.newStatusId != null
        ? state.getTagById(lastLog.newStatusId!)
        : null;

    if (!_animationController.isCompleted && !_animationController.isAnimating) {
      _animationController.forward();
    }

    return FadeTransition(
      opacity: _animation,
      child: SizeTransition(
        sizeFactor: _animation,
        axisAlignment: -1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Card(
            elevation: 3,
            shadowColor: Colors.black.withOpacity(0.12),
            shape: ExpressiveShapes.cardSmall,
            color: theme.colorScheme.inverseSurface,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _showLogHistory(context, state, logs),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Status dot
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: tag != null
                              ? Color(tag.colorValue)
                              : theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Last action summary
                      Expanded(
                        child: Text(
                          '${member?.name ?? "未知"} → ${tag?.name ?? "未知"}',
                          style: TextStyle(
                            color: theme.colorScheme.onInverseSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Expand icon + count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${logs.length}',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.keyboard_arrow_up,
                        color: theme.colorScheme.onInverseSurface.withOpacity(0.6),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Show full operation history BottomSheet
  void _showLogHistory(
    BuildContext context,
    AppState state,
    List<OperationLog> logs,
  ) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        '操作记录',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${logs.length} 条记录',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Log list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final member = state.getMemberById(log.targetMemberId);
                      final tag = log.newStatusId != null
                          ? state.getTagById(log.newStatusId!)
                          : null;
                      final prevTag = log.prevStatusId != null
                          ? state.getTagById(log.prevStatusId!)
                          : null;

                      return ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: tag != null
                                ? Color(tag.colorValue).withOpacity(0.15)
                                : theme.colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${logs.length - index}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: tag != null
                                    ? Color(tag.colorValue)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          member?.name ?? '未知',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          prevTag != null
                              ? '${prevTag.name} → ${tag?.name ?? "未知"}'
                              : tag?.name ?? '未知',
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: index == 0
                            ? FilledButton.tonalIcon(
                                icon: const Icon(Icons.undo, size: 16),
                                label: const Text('撤销'),
                                style: FilledButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await state.undoLastAction(widget.sessionId);
                                },
                              )
                            : TextButton(
                                onPressed: () => _confirmRewind(context, state, log, index),
                                child: const Text('回溯'),
                              ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Confirm rewinding to a specific point in history
  Future<void> _confirmRewind(
    BuildContext context,
    AppState state,
    OperationLog targetLog,
    int stepsBack,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.history, size: 32),
        title: const Text('回溯确认'),
        content: Text('将撤销从第 ${stepsBack + 1} 步到最近的 ${stepsBack} 步操作，确定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              shape: ExpressiveShapes.pill,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('回溯'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Navigator.pop(context); // Close bottom sheet
      // Undo step by step
      for (int i = 0; i <= stepsBack; i++) {
        await state.undoLastAction(widget.sessionId);
      }
    }
  }
}
