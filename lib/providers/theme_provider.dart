import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'dart:ui';
import 'package:hive_flutter/hive_flutter.dart';

/// 主题模式
enum AppThemeMode {
  system,  // 跟随系统
  light,   // 亮色
  dark,    // 暗色
}

/// Icon 风格
enum AppIconStyle {
  defaultStyle,  // 默认 Material Icons
  rounded,       // 圆角图标
  outlined,      // 线条图标
  sharp,         // 尖角图标
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

/// 扩展预设颜色（用于网格选择器）
const List<ThemeColor> extendedPresetColors = [
  ThemeColor('紫色', Color(0xFF6750A4)),     // 紫色（默认）
  ThemeColor('蓝色', Color(0xFF1976D2)),     // 蓝色
  ThemeColor('绿色', Color(0xFF388E3C)),     // 绿色
  ThemeColor('橙色', Color(0xFFF57C00)),     // 橙色
  ThemeColor('红色', Color(0xFFD32F2F)),     // 红色
  ThemeColor('深紫', Color(0xFF7B1FA2)),     // 深紫
  ThemeColor('青色', Color(0xFF00796B)),     // 青色
  ThemeColor('棕色', Color(0xFF5D4037)),     // 棕色
  ThemeColor('粉红', Color(0xFFC2185B)),     // 粉红
  ThemeColor('靛蓝', Color(0xFF303F9F)),     // 靛蓝
];

/// 主题状态
class ThemeState extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.system;
  Color _seedColor = Colors.indigo;
  bool _dynamicColorEnabled = false;
  ColorScheme? _platformColorScheme;
  AppIconStyle _iconStyle = AppIconStyle.defaultStyle;
  bool _autoCheckUpdate = true;

  AppThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;
  bool get dynamicColorEnabled => _dynamicColorEnabled;
  AppIconStyle get iconStyle => _iconStyle;
  bool get autoCheckUpdate => _autoCheckUpdate;

  /// 设置平台动态颜色方案（在 main.dart 中调用）
  void setPlatformColorScheme(ColorScheme? scheme) {
    _platformColorScheme = scheme;
    notifyListeners();
  }

  void setThemeMode(AppThemeMode mode) {
    _themeMode = mode;
    _saveSettings();
    notifyListeners();
  }

  void setSeedColor(Color color) {
    _seedColor = color;
    _saveSettings();
    notifyListeners();
  }

  void setDynamicColorEnabled(bool value) {
    _dynamicColorEnabled = value;
    _saveSettings();
    notifyListeners();
  }

  void setIconStyle(AppIconStyle style) {
    _iconStyle = style;
    _saveSettings();
    notifyListeners();
  }

  void setAutoCheckUpdate(bool value) {
    _autoCheckUpdate = value;
    _saveSettings();
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
    );
  }

  ThemeData get darkTheme {
    if (_dynamicColorEnabled && _platformColorScheme != null) {
      return ThemeData(
        useMaterial3: true,
        colorScheme: _platformColorScheme!.copyWith(brightness: Brightness.dark),
        fontFamily: 'NotoSansSC',
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
    );
  }

  /// 从 Hive 加载持久化设置
  Future<void> loadSettings() async {
    try {
      final box = await Hive.openBox('settings');
      // 主题模式
      final themeModeIndex = box.get('themeMode', defaultValue: 0) as int;
      if (themeModeIndex >= 0 && themeModeIndex < AppThemeMode.values.length) {
        _themeMode = AppThemeMode.values[themeModeIndex];
      }
      // 种子颜色
      final seedColorValue = box.get('seedColor') as int?;
      if (seedColorValue != null) {
        _seedColor = Color(seedColorValue);
      }
      // 动态取色
      _dynamicColorEnabled = box.get('dynamicColorEnabled', defaultValue: false) as bool;
      // Icon 风格
      final iconStyleIndex = box.get('iconStyle', defaultValue: 0) as int;
      if (iconStyleIndex >= 0 && iconStyleIndex < AppIconStyle.values.length) {
        _iconStyle = AppIconStyle.values[iconStyleIndex];
      }
      // 自动检查更新
      _autoCheckUpdate = box.get('autoCheckUpdate', defaultValue: true) as bool;
      notifyListeners();
    } catch (e) {
      // 加载失败时使用默认值
    }
  }

  /// 保存设置到 Hive
  Future<void> _saveSettings() async {
    try {
      final box = await Hive.openBox('settings');
      await box.put('themeMode', _themeMode.index);
      await box.put('seedColor', _seedColor.value);
      await box.put('dynamicColorEnabled', _dynamicColorEnabled);
      await box.put('iconStyle', _iconStyle.index);
      await box.put('autoCheckUpdate', _autoCheckUpdate);
    } catch (e) {
      // 保存失败时静默处理
    }
  }
}

/// Provider
final themeProvider = ChangeNotifierProvider<ThemeState>((ref) {
  return ThemeState();
});
