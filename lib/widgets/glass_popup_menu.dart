import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// ============================================================
/// True Glassmorphism Popup Menu
/// ============================================================
/// Unlike PopupMenuButton which draws on a solid black barrier,
/// this uses a full-screen BackdropFilter to blur the content
/// behind the menu, creating real glass-like transparency.

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
  final double blurSigma;
  final double menuOpacity;

  const GlassPopupMenu({
    super.key,
    required this.items,
    this.onSelected,
    required this.child,
    this.blurSigma = 20,
    this.menuOpacity = 0.65,
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
        blurSigma: blurSigma,
        menuOpacity: menuOpacity,
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
  final double blurSigma;
  final double menuOpacity;
  final ThemeData theme;
  final List<GlassMenuItem> items;
  final void Function(String value) onSelected;

  _GlassPopupRoute({
    required this.position,
    required this.blurSigma,
    required this.menuOpacity,
    required this.theme,
    required this.items,
    required this.onSelected,
  });

  @override
  Color? get barrierColor => Colors.black.withOpacity(0.05);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 200);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _GlassPopupContent(
      position: position,
      blurSigma: blurSigma,
      menuOpacity: menuOpacity,
      theme: theme,
      items: items,
      onSelected: onSelected,
      animation: animation,
    );
  }
}

class _GlassPopupContent extends StatelessWidget {
  final RelativeRect position;
  final double blurSigma;
  final double menuOpacity;
  final ThemeData theme;
  final List<GlassMenuItem> items;
  final void Function(String value) onSelected;
  final Animation<double> animation;

  const _GlassPopupContent({
    required this.position,
    required this.blurSigma,
    required this.menuOpacity,
    required this.theme,
    required this.items,
    required this.onSelected,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate menu position (top-right by default)
    final screenSize = MediaQuery.of(context).size;
    final menuWidth = 200.0;
    final menuHeight = items.length * 48.0 + 16;

    double left = position.left;
    double top = position.top;

    // Align to right edge of button if near right screen edge
    if (left + menuWidth > screenSize.width - 16) {
      left = screenSize.width - menuWidth - 16;
    }
    if (top + menuHeight > screenSize.height - 100) {
      top = screenSize.height - menuHeight - 100;
    }

    return Stack(
      children: [
        // Full-screen frosted glass backdrop
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: Container(
              color: theme.brightness == Brightness.dark
                  ? Colors.black.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        // Menu panel
        Positioned(
          left: left,
          top: top + 40, // below the button
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blurSigma * 0.5, sigmaY: blurSigma * 0.5),
                  child: Container(
                    width: menuWidth,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(menuOpacity),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.white.withOpacity(0.35),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          spreadRadius: 2,
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
                                        color: theme.colorScheme.outlineVariant.withOpacity(0.2),
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
