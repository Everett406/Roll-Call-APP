import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// ============================================================
/// Liquid Glass Container — True glassmorphism with specular highlight
/// ============================================================
/// Inspired by iOS 26 Liquid Glass and liquid-glass.ybouane.com
///
/// Key visual elements:
/// 1. BackdropFilter blur — blurs content behind
/// 2. Semi-transparent tint — base glass color
/// 3. Specular highlight gradient — diagonal white sheen for 3D glass feel
/// 4. Edge highlight border — white glow on edges
/// 5. Inner shadow — subtle depth

class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double opacity;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const LiquidGlass({
    super.key,
    required this.child,
    this.blurSigma = 40,
    this.opacity = 0.35,
    this.width,
    this.height,
    this.borderRadius,
    this.border,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final br = borderRadius ?? BorderRadius.circular(24);

    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          width: width,
          height: height,
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            // Base glass tint
            color: theme.colorScheme.surface.withOpacity(opacity),
            borderRadius: br,
            // Edge highlight — stronger in light mode
            border: border ?? Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.45),
              width: 1.0,
            ),
            // Subtle shadow for depth
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.08),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Specular highlight gradient — diagonal white sheen
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: br,
                    gradient: LinearGradient(
                      begin: const Alignment(-0.8, -1.0),
                      end: const Alignment(0.5, 0.8),
                      colors: [
                        Colors.white.withOpacity(isDark ? 0.15 : 0.35),
                        Colors.white.withOpacity(isDark ? 0.03 : 0.08),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.35, 0.7, 1.0],
                    ),
                  ),
                ),
              ),
              // Secondary subtle highlight from opposite angle
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: br,
                    gradient: LinearGradient(
                      begin: const Alignment(0.8, 0.2),
                      end: const Alignment(-0.3, 0.6),
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(isDark ? 0.02 : 0.06),
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// Liquid Glass AppBar — True liquid glass navigation bar
/// ============================================================
class LiquidGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final Widget? bottom;
  final double? bottomHeight;
  final double blurSigma;
  final double opacity;

  const LiquidGlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.bottomHeight,
    this.blurSigma = 40,
    this.opacity = 0.35,
  });

  @override
  Size get preferredSize {
    final bottomH = bottom != null ? (bottomHeight ?? 48.0) : 0.0;
    return Size.fromHeight(kToolbarHeight + bottomH);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(opacity),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : Colors.white.withOpacity(0.40),
                width: 1.0,
              ),
            ),
          ),
          child: Stack(
            children: [
              // Specular highlight
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-0.8, -1.0),
                      end: const Alignment(0.5, 0.3),
                      colors: [
                        Colors.white.withOpacity(isDark ? 0.12 : 0.30),
                        Colors.white.withOpacity(isDark ? 0.02 : 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.6],
                    ),
                  ),
                ),
              ),
              // AppBar content
              SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: kToolbarHeight,
                      child: NavigationToolbar(
                        leading: leading ?? const SizedBox.shrink(),
                        middle: title,
                        trailing: actions != null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: actions!,
                              )
                            : null,
                      ),
                    ),
                    if (bottom != null)
                      SizedBox(
                        height: bottomHeight ?? 48,
                        child: bottom!,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// Liquid Glass Bottom Navigation — True liquid glass nav bar
/// ============================================================
class LiquidGlassBottomNav extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double opacity;

  const LiquidGlassBottomNav({
    super.key,
    required this.child,
    this.blurSigma = 40,
    this.opacity = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(opacity),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.10)
                    : Colors.white.withOpacity(0.40),
                width: 1.0,
              ),
            ),
          ),
          child: Stack(
            children: [
              // Specular highlight
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-0.8, -1.0),
                      end: const Alignment(0.5, 0.5),
                      colors: [
                        Colors.white.withOpacity(isDark ? 0.12 : 0.30),
                        Colors.white.withOpacity(isDark ? 0.02 : 0.06),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.6],
                    ),
                  ),
                ),
              ),
              // Content
              SafeArea(top: false, child: child),
            ],
          ),
        ),
      ),
    );
  }
}
