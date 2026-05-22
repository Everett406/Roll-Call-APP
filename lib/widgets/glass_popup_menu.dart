import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// ============================================================
/// Glassmorphism Popup Menu — UI itself blurs what's behind it
/// ============================================================
/// No full-screen blur. The menu panel itself uses BackdropFilter
/// to blur content behind it. Very transparent for true glass feel.

class GlassMenuItem {
  final String value;
  final Widget child;
  final VoidCallback? onTap;

  const GlassMenuItem({
    required this.value,
    required this.child,
    this.onTap,
  });
}

class GlassPopupMenu extends StatelessWidget {
  final List<GlassMenuItem> items;
  final void Function(String value)? onSelected;
  final Widget child;

  const GlassPopupMenu({
    super.key,
    required this.items,
    this.onSelected,
    required this.child,
  });

  void _show(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final theme = Theme.of(context);

    Navigator.of(context).push(
      _GlassPopupRoute(
        position: position,
        theme: theme,
        items: items,
        onSelected: (value) {
          Navigator.of(context).pop();
          onSelected?.call(value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _show(context),
      borderRadius: BorderRadius.circular(12),
      child: child,
    );
  }
}

class _GlassPopupRoute extends PopupRoute<String> {
  final RelativeRect position;
  final ThemeData theme;
  final List<GlassMenuItem> items;
  final void Function(String value) onSelected;

  _GlassPopupRoute({
    required this.position,
    required this.theme,
    required this.items,
    required this.onSelected,
  });

  @override
  Color? get barrierColor => null; // No barrier — see through

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _GlassPopupContent(
      position: position,
      theme: theme,
      items: items,
      onSelected: onSelected,
      animation: animation,
    );
  }
}

class _GlassPopupContent extends StatelessWidget {
  final RelativeRect position;
  final ThemeData theme;
  final List<GlassMenuItem> items;
  final void Function(String value) onSelected;
  final Animation<double> animation;

  const _GlassPopupContent({
    required this.position,
    required this.theme,
    required this.items,
    required this.onSelected,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const menuWidth = 200.0;
    final menuHeight = items.length * 48.0 + 16;

    double left = position.left;
    double top = position.top;

    if (left + menuWidth > screenSize.width - 16) {
      left = screenSize.width - menuWidth - 16;
    }
    if (top + menuHeight > screenSize.height - 100) {
      top = screenSize.height - menuHeight - 100;
    }

    return Stack(
      children: [
        // Dismissible transparent overlay (no blur — just catch taps)
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),
        ),
        // Menu panel — glassmorphism: the panel itself blurs what's behind it
        Positioned(
          left: left,
          top: top + 40,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: FadeTransition(
              opacity: animation,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: menuWidth,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.25),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isLast = index == items.length - 1;
                        return InkWell(
                          onTap: () {
                            item.onTap?.call();
                            onSelected(item.value);
                          },
                          borderRadius: BorderRadius.vertical(
                            top: index == 0 ? const Radius.circular(20) : Radius.zero,
                            bottom: isLast ? const Radius.circular(20) : Radius.zero,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: !isLast
                                ? BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: theme.colorScheme.outlineVariant.withOpacity(0.15),
                                        width: 0.5,
                                      ),
                                    ),
                                  )
                                : null,
                            child: DefaultTextStyle(
                              style: theme.textTheme.bodyMedium!,
                              child: item.child,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
