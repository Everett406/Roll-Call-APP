import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'dart:ui';

/// 主题模式
enum AppThemeMode {
  system,  // 跟随系统
  light,   // 亮色
  dark,    // 暗色
}

/// 主题颜色选项
class ThemeColor {
  final String name;
  final Color color;

  const ThemeColor(this.name, this.color);
}

/// 预设主题颜色
const List<ThemeColor> themeColors = [
  ThemeColor('靛蓝', Colors.indigo),
  ThemeColor('蓝色', Colors.blue),
  ThemeColor('青色', Colors.teal),
  ThemeColor('绿色', Colors.green),
  ThemeColor('橙色', Colors.orange),
  ThemeColor('粉色', Colors.pink),
  ThemeColor('紫色', Colors.purple),
  ThemeColor('红色', Colors.red),
];

/// 主题状态
class ThemeState extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.system;
  Color _seedColor = Colors.indigo;
  bool _dynamicColorEnabled = false;
  ColorScheme? _platformColorScheme;

  AppThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  bool get dynamicColorEnabled => _dynamicColorEnabled;

  /// 设置平台动态颜色方案（在 main.dart 中调用）
  void setPlatformColorScheme(ColorScheme? scheme) {
    _platformColorScheme = scheme;
    notifyListeners();
  }

  void setThemeMode(AppThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setSeedColor(Color color) {
    _seedColor = color;
    notifyListeners();
  }

  void setDynamicColorEnabled(bool value) {
    _dynamicColorEnabled = value;
    notifyListeners();
  }

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// 生成高饱和度的种子颜色
  Color get _vibrantSeedColor {
    final hsl = HSLColor.fromColor(_seedColor);
    return hsl.withSaturation(hsl.saturation.clamp(0.8, 1.0)).withLightness(
      hsl.lightness.clamp(0.35, 0.55),
    ).toColor();
  }

  ThemeData get lightTheme {
    // 动态取色优先使用平台颜色
    if (_dynamicColorEnabled && _platformColorScheme != null) {
      return ThemeData(
        useMaterial3: true,
        colorScheme: _platformColorScheme!.copyWith(brightness: Brightness.light),
        fontFamily: 'NotoSansSC',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          },
        ),
      );
    }
    final seed = _dynamicColorEnabled ? _vibrantSeedColor : _seedColor;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
      ),
      fontFamily: 'NotoSansSC',
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }

  ThemeData get darkTheme {
    if (_dynamicColorEnabled && _platformColorScheme != null) {
      return ThemeData(
        useMaterial3: true,
        colorScheme: _platformColorScheme!.copyWith(brightness: Brightness.dark),
        fontFamily: 'NotoSansSC',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: <TargetPlatform, PageTransitionsBuilder>{
            TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          },
        ),
      );
    }
    final seed = _dynamicColorEnabled ? _vibrantSeedColor : _seedColor;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ),
      fontFamily: 'NotoSansSC',
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Provider
final themeProvider = ChangeNotifierProvider<ThemeState>((ref) {
  return ThemeState();
});
