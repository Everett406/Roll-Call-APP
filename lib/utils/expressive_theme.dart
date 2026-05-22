import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// ============================================================
/// Material 3 Expressive Theme Configuration
/// ============================================================
///
/// M3 Expressive design principles applied:
/// - Larger, more rounded shapes (28dp cards, pill buttons)
/// - Spring physics animations (elastic curves)
/// - Enhanced typography (bolder, larger titles)
/// - Containment: explicit surface wrapping
/// - Full-width bottom action buttons
/// - Stronger color contrast
///
class ExpressiveShapes {
  // Card shapes - large rounded corners (M3 Expressive: 20-28dp)
  static RoundedRectangleBorder cardLarge =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));

  static RoundedRectangleBorder cardMedium =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(24));

  static RoundedRectangleBorder cardSmall =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));

  // Button shapes - pill / stadium for expressive feel
  static StadiumBorder pill = const StadiumBorder();

  static RoundedRectangleBorder buttonRounded =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));

  // Input / Dialog shapes
  static RoundedRectangleBorder dialog =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));

  static OutlineInputBorder inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(20),
    borderSide: BorderSide.none,
  );

  static OutlineInputBorder inputBorderFocused = OutlineInputBorder(
    borderRadius: BorderRadius.circular(20),
    borderSide: const BorderSide(width: 2),
  );

  // Chip shapes
  static StadiumBorder chip = const StadiumBorder();

  // FAB shape - large rounded
  static RoundedRectangleBorder fab =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));

  // Bottom sheet
  static RoundedRectangleBorder bottomSheet =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));
}

/// ============================================================
/// Spring Physics Animation Curves (M3 Expressive motion)
/// ============================================================
class ExpressiveCurves {
  /// Spring-like overshoot for entrances
  static const elasticOut = ElasticOutCurve(0.8);

  /// Gentle spring for standard transitions
  static const spring = Curves.elasticOut;

  /// Decelerate with slight overshoot
  static const decelerateSpring = Curves.decelerate;

  /// Standard M3 Expressive easing
  static const standard = Curves.easeOutCubic;

  /// Emphasized easing (M3 Expressive standard)
  static const emphasized = Curves.easeOutExpo;

  /// Quick spring for micro-interactions
  static const quickSpring = Curves.easeOutBack;
}

/// ============================================================
/// Expressive Durations
/// ============================================================
class ExpressiveDurations {
  static const micro = Duration(milliseconds: 150);
  static const quick = Duration(milliseconds: 250);
  static const standard = Duration(milliseconds: 400);
  static const emphasized = Duration(milliseconds: 500);
  static const slow = Duration(milliseconds: 700);
}

/// ============================================================
/// Enhanced Typography for M3 Expressive
/// ============================================================
class ExpressiveTypography {
  /// Build expressive text theme on top of base typography.
  /// Uses colorScheme.onSurface for all text to ensure proper dark mode support.
  static TextTheme buildTextTheme(TextTheme base, ColorScheme colors) {
    final onSurface = colors.onSurface;
    final onSurfaceVariant = colors.onSurfaceVariant;
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w800, letterSpacing: -0.5, color: onSurface,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontWeight: FontWeight.w700, letterSpacing: -0.3, color: onSurface,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w700, color: onSurface,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700, letterSpacing: -0.3, color: onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700, letterSpacing: -0.2, color: onSurface,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600, color: onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600, letterSpacing: 0.1, color: onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600, color: onSurface,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600, color: onSurfaceVariant,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontWeight: FontWeight.w400, height: 1.5, color: onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontWeight: FontWeight.w400, height: 1.4, color: onSurface,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontWeight: FontWeight.w400, color: onSurfaceVariant,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600, letterSpacing: 0.5, color: onSurface,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w600, color: onSurfaceVariant,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w500, color: onSurfaceVariant,
      ),
    );
  }
}

/// ============================================================
/// Expressive Theme Builder
/// ============================================================
class ExpressiveTheme {
  /// Build a complete Material 3 Expressive ThemeData
  static ThemeData buildTheme({
    required ColorScheme colorScheme,
    bool useExpressiveShapes = true,
  }) {
    final baseTextTheme =
        Typography.material2021(platform: TargetPlatform.android).black;

    final textTheme = ExpressiveTypography.buildTextTheme(
      baseTextTheme,
      colorScheme,
    );

    var theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      // ==========================================================
      // Card Theme - large rounded corners
      // ==========================================================
      cardTheme: CardTheme(
        elevation: 0.5,
        shape: useExpressiveShapes ? ExpressiveShapes.cardLarge : null,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      // ==========================================================
      // Button Themes - pill shapes, taller
      // ==========================================================
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: useExpressiveShapes ? ExpressiveShapes.pill : null,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: useExpressiveShapes ? ExpressiveShapes.pill : null,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: useExpressiveShapes ? ExpressiveShapes.pill : null,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: useExpressiveShapes
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))
              : null,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // ==========================================================
      // FAB Theme
      // ==========================================================
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: useExpressiveShapes ? ExpressiveShapes.fab : null,
        elevation: 2,
        extendedPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      // ==========================================================
      // Input Decoration - large rounded, filled
      // ==========================================================
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.6),
        border: useExpressiveShapes ? ExpressiveShapes.inputBorder : null,
        enabledBorder: useExpressiveShapes ? ExpressiveShapes.inputBorder : null,
        focusedBorder: useExpressiveShapes
            ? ExpressiveShapes.inputBorderFocused.copyWith(
                borderSide: BorderSide(color: colorScheme.primary, width: 2))
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: TextStyle(
          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
        ),
      ),
      // ==========================================================
      // Chip Theme - pill shape
      // ==========================================================
      chipTheme: ChipThemeData(
        shape: useExpressiveShapes ? ExpressiveShapes.chip : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        side: BorderSide.none,
      ),
      // ==========================================================
      // Dialog Theme
      // ==========================================================
      dialogTheme: DialogTheme(
        shape: useExpressiveShapes ? ExpressiveShapes.dialog : null,
        elevation: 2,
      ),
      // ==========================================================
      // Bottom Sheet
      // ==========================================================
      bottomSheetTheme: BottomSheetThemeData(
        shape: useExpressiveShapes ? ExpressiveShapes.bottomSheet : null,
        clipBehavior: Clip.antiAlias,
      ),
      // ==========================================================
      // List Tile
      // ==========================================================
      listTileTheme: ListTileThemeData(
        shape: useExpressiveShapes
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      // ==========================================================
      // App Bar - taller, expressive
      // ==========================================================
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 8,
        surfaceTintColor: colorScheme.surfaceTint,
        backgroundColor: colorScheme.surface.withOpacity(0.85),
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      // ==========================================================
      // Navigation Bar - frosted glass effect
      // ==========================================================
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: colorScheme.surface.withOpacity(0.7),
        indicatorShape: useExpressiveShapes
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
            : null,
        indicatorColor: colorScheme.secondaryContainer.withOpacity(0.7),
      ),
      bottomAppBarTheme: BottomAppBarTheme(
        elevation: 0,
        color: colorScheme.surface.withOpacity(0.7),
      ),
      // ==========================================================
      // Divider
      // ==========================================================
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withOpacity(0.4),
        thickness: 0.5,
      ),
      // ==========================================================
      // Snack Bar
      // ==========================================================
      snackBarTheme: SnackBarThemeData(
        shape: useExpressiveShapes
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
            : null,
        behavior: SnackBarBehavior.floating,
      ),
      // ==========================================================
      // Switch
      // ==========================================================
      switchTheme: SwitchThemeData(
        trackOutlineWidth: const WidgetStatePropertyAll(0),
        thumbIcon: WidgetStateProperty.all(null),
      ),
      // ==========================================================
      // Page transitions - keep default Material transitions
      // ==========================================================
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      // ==========================================================
      // Animation defaults
      // ==========================================================
      splashFactory: InkSparkle.splashFactory,
    );

    return theme;
  }
}

/// ============================================================
/// Expressive Animation Helpers
/// ============================================================
class ExpressiveAnimations {
  /// Spring entrance animation for widgets
  static Widget springEntrance({
    required Widget child,
    required Animation<double> animation,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: ExpressiveCurves.quickSpring,
        );
        return Transform.scale(
          scale: curved.value.clamp(0.8, 1.0),
          child: Opacity(
            opacity: curved.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Staggered list animation
  static Widget staggeredItem({
    required Widget child,
    required int index,
    required Animation<double> animation,
  }) {
    final delay = index * 0.05;
    final delayedAnimation = CurvedAnimation(
      parent: animation,
      curve: Interval(
        delay.clamp(0.0, 0.7),
        (delay + 0.4).clamp(0.0, 1.0),
        curve: ExpressiveCurves.quickSpring,
      ),
    );
    return AnimatedBuilder(
      animation: delayedAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - delayedAnimation.value) * 30),
          child: Opacity(
            opacity: delayedAnimation.value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// ============================================================
/// Frosted Glass Dialog Helpers
/// ============================================================

/// Show a dialog with frosted glass background blur.
/// Replaces [showDialog] to add automatic BackdropFilter.
Future<T?> showExpressiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  Color? barrierColor,
}) {
  final theme = Theme.of(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor ?? (theme.brightness == Brightness.dark
        ? Colors.black.withOpacity(0.45)
        : Colors.black.withOpacity(0.25)),
    useRootNavigator: useRootNavigator,
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: builder(context),
    ),
  );
}

/// Show a bottom sheet with frosted glass background blur.
/// Replaces [showModalBottomSheet] to add automatic BackdropFilter.
Future<T?> showExpressiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  bool useRootNavigator = false,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  final theme = Theme.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    barrierColor: theme.brightness == Brightness.dark
        ? Colors.black.withOpacity(0.4)
        : Colors.black.withOpacity(0.2),
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: builder(context),
      ),
    ),
  );
}

/// ============================================================
/// Expressive Container Widgets (Containment pattern)
/// ============================================================

/// A contained surface group with title - M3 Expressive containment pattern
class ContainmentGroup extends StatelessWidget {
  final String? title;
  final IconData? titleIcon;
  final List<Widget>? children;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const ContainmentGroup({
    super.key,
    this.title,
    this.titleIcon,
    this.children,
    this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  }) : assert(children != null || child != null,
           'Either children or child must be provided');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: margin,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (titleIcon != null) ...[
                    Icon(
                      titleIcon,
                      color: theme.colorScheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (child != null) child! else ...children!,
          ],
        ),
      ),
    );
  }
}

/// Expressive full-width bottom action button
class ExpressiveBottomButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool elevated;

  const ExpressiveBottomButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 56,
          width: double.infinity,
          child: elevated
              ? FilledButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(label),
                  style: FilledButton.styleFrom(
                    shape: ExpressiveShapes.pill,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: Icon(icon),
                  label: Text(label),
                  style: ElevatedButton.styleFrom(
                    shape: ExpressiveShapes.pill,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Expressive stat card for data display
class ExpressiveStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const ExpressiveStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const Spacer(),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
