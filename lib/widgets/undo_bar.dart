import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/operation_log.dart';
import '../utils/expressive_theme.dart';
import '../providers/app_state.dart';
import '../utils/expressive_theme.dart';

class UndoBar extends ConsumerStatefulWidget {
  final String sessionId;

  const UndoBar({
    super.key,
    required this.sessionId,
  });

  @override
  ConsumerState<UndoBar> createState() => _UndoBarState();
}

class _UndoBarState extends ConsumerState<UndoBar>
    with SingleTickerProviderStateMixin {
  Timer? _hideTimer;
  late AnimationController _animationController;
  late Animation<double> _animation;
  String? _lastDisplayedLogId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _resetTimer() {
    _hideTimer?.cancel();
    _animationController.forward(from: 0);
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final lastLog = state.getLastUndoableLog(widget.sessionId);

    if (lastLog == null) {
      _animationController.reverse();
      _lastDisplayedLogId = null;
      return const SizedBox.shrink();
    }

    // Only reset timer when a new undoable action occurs
    // This prevents the bar from flickering/resetting on every rebuild
    if (_lastDisplayedLogId != lastLog.id) {
      _lastDisplayedLogId = lastLog.id;
      _resetTimer();
    }

    final member = state.getMemberById(lastLog.targetMemberId);
    final tag = lastLog.newStatusId != null
        ? state.getTagById(lastLog.newStatusId!)
        : null;
    final memberName = member?.name ?? '未知';
    final tagName = tag?.name ?? '未知';
    final theme = Theme.of(context);

    return SafeArea(
      child: FadeTransition(
        opacity: _animation,
        child: SizeTransition(
          sizeFactor: _animation,
          axisAlignment: -1,
          child: GestureDetector(
            onTap: () {
              _resetTimer();
            },
            child: Container(
              margin: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 16,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.inversePrimary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.undo_outlined,
                      color: theme.colorScheme.inversePrimary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '已标记 $memberName 为 $tagName',
                      style: TextStyle(
                        color: theme.colorScheme.onInverseSurface,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        _hideTimer?.cancel();
                        await state.undoLastAction(widget.sessionId);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          '撤销',
                          style: TextStyle(
                            color: theme.colorScheme.inversePrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
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
}
