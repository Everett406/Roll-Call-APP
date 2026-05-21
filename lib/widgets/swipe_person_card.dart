import 'package:flutter/material.dart';
import '../models/member.dart';
import '../models/status_tag.dart';
import '../utils/constants.dart';

class SwipePersonCard extends StatefulWidget {
  final Member member;
  final StatusTag? currentTag;
  final VoidCallback onSwipeRight; // Mark as arrived
  final VoidCallback onSwipeLeft; // Show status bottom sheet
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const SwipePersonCard({
    super.key,
    required this.member,
    this.currentTag,
    required this.onSwipeRight,
    required this.onSwipeLeft,
    this.onLongPress,
    this.onTap,
  });

  @override
  State<SwipePersonCard> createState() => _SwipePersonCardState();
}

class _SwipePersonCardState extends State<SwipePersonCard>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _swipedRight = false;
  bool _swipedLeft = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagColor = widget.currentTag != null
        ? Color(widget.currentTag!.colorValue)
        : theme.colorScheme.surfaceContainerHighest;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragOffset += details.delta.dx;
          _dragOffset = _dragOffset.clamp(-120.0, 120.0);
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset > 60) {
          // Swipe right - mark as arrived
          setState(() {
            _swipedRight = true;
            _dragOffset = 0;
          });
          widget.onSwipeRight();
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _swipedRight = false;
              });
            }
          });
        } else if (_dragOffset < -60) {
          // Swipe left - show status sheet
          setState(() {
            _swipedLeft = true;
            _dragOffset = 0;
          });
          widget.onSwipeLeft();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _swipedLeft = false;
              });
            }
          });
        } else {
          setState(() {
            _dragOffset = 0;
          });
        }
      },
      child: Stack(
        children: [
          // Background layers
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.transparent,
              ),
            ),
          ),
          // Right swipe background (green)
          if (_dragOffset > 0)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.success.withOpacity(
                      (_dragOffset / 120).clamp(0.0, 1.0)),
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 24),
                child: Opacity(
                  opacity: (_dragOffset / 60).clamp(0.0, 1.0),
                  child: const Icon(Icons.check, color: Colors.white, size: 32),
                ),
              ),
            ),
          // Left swipe background (action hint)
          if (_dragOffset < 0)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.primaryContainer.withOpacity(
                      (-_dragOffset / 120).clamp(0.0, 1.0)),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: Opacity(
                  opacity: (-_dragOffset / 60).clamp(0.0, 1.0),
                  child: Icon(
                    Icons.more_horiz,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 32,
                  ),
                ),
              ),
            ),
          // Flash overlay for right swipe
          if (_swipedRight)
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.success.withOpacity(0.3),
                ),
              ),
            ),
          // Main card content
          AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: Card(
              elevation: widget.currentTag != null ? 0 : 1,
              color: widget.currentTag != null
                  ? tagColor.withOpacity(0.15)
                  : theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: widget.currentTag != null
                    ? BorderSide(color: tagColor.withOpacity(0.5), width: 1.5)
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 40,
                        decoration: BoxDecoration(
                          color: tagColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag: 'memberName_${widget.member.id}',
                              child: Material(
                                type: MaterialType.transparency,
                                child: Text(
                                  widget.member.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: widget.currentTag != null
                                        ? tagColor
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                            if (widget.member.studentId != null &&
                                widget.member.studentId!.isNotEmpty)
                              Hero(
                                tag: 'studentId_${widget.member.id}',
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: Text(
                                    widget.member.studentId!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (widget.currentTag != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: tagColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.currentTag!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '未标记',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
