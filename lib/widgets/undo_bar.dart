import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/expressive_theme.dart';
import '../providers/app_state.dart';

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
  Timer? _progressTimer;
  late AnimationController _animationController;
  late Animation<double> _animation;
  String? _lastDisplayedLogId;
  double _progress = 1.0;

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
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _resetTimer() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _progress = 1.0;

    _animationController.forward(from: 0);

    // Progress countdown
    const totalDuration = 6; // seconds
    var elapsed = 0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      elapsed += 100;
      setState(() {
        _progress = 1.0 - (elapsed / (totalDuration * 1000));
      });
      if (elapsed >= totalDuration * 1000) {
        timer.cancel();
      }
    });

    _hideTimer = Timer(const Duration(seconds: totalDuration), () {
      if (mounted) {
        _animationController.reverse();
      }
    });
  }

  void _undo() async {
    final state = ref.read(appStateProvider);
    _hideTimer?.cancel();
    _progressTimer?.cancel();

    // Spring out animation
    await _animationController.reverse();

    if (mounted) {
      await state.undoLastAction(widget.sessionId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final lastLog = state.getLastUndoableLog(widget.sessionId);

    if (lastLog == null) {
      _animationController.reverse();
      _lastDisplayedLogId = null;
      _progress = 1.0;
      return const SizedBox.shrink();
    }

    // Only reset timer when a new undoable action occurs
    if (_lastDisplayedLogId != lastLog.id) {
      _lastDisplayedLogId = lastLog.id;
      _resetTimer();
    }

    final member = state.getMemberById(lastLog.targetMemberId);
    final tag = lastLog.newStatusId != null
        ? state.getTagById(lastLog.newStatusId!)
        : null;
    final prevTag = lastLog.prevStatusId != null
        ? state.getTagById(lastLog.prevStatusId!)
        : null;
    final memberName = member?.name ?? '未知';
    final tagName = tag?.name ?? '未知';
    final prevTagName = prevTag?.name;
    final theme = Theme.of(context);
    final tagColor = tag != null ? Color(tag.colorValue) : theme.colorScheme.primary;

    return SafeArea(
      child: FadeTransition(
        opacity: _animation,
        child: SizeTransition(
          sizeFactor: _animation,
          axisAlignment: -1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Card(
              elevation: 3,
              shadowColor: Colors.black.withOpacity(0.15),
              shape: ExpressiveShapes.cardSmall,
              color: theme.colorScheme.inverseSurface,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main content
                    InkWell(
                      onTap: _resetTimer,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                        child: Row(
                          children: [
                            // Status icon with color
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: tagColor.withOpacity(0.25),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.check_circle_outline,
                                  color: tagColor,
                                  size: 22,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '已标记',
                                    style: TextStyle(
                                      color: theme.colorScheme.onInverseSurface
                                          .withOpacity(0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$memberName → $tagName',
                                    style: TextStyle(
                                      color: theme.colorScheme.onInverseSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (prevTagName != null)
                                    Text(
                                      '原状态: $prevTagName',
                                      style: TextStyle(
                                        color: theme.colorScheme.onInverseSurface
                                            .withOpacity(0.5),
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Undo button - pill shape, prominent
                            FilledButton.icon(
                              onPressed: _undo,
                              icon: const Icon(Icons.undo_rounded, size: 16),
                              label: const Text('撤销'),
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Progress bar countdown
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      height: 3,
                      width: double.infinity,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                tagColor,
                                tagColor.withOpacity(0.5),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(2),
                              bottomRight: Radius.circular(2),
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
      ),
    );
  }
}
