import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  AppThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  void setThemeMode(AppThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  void setSeedColor(Color color) {
    _seedColor = color;
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

  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    ),
    fontFamily: 'NotoSansSC',
  );

  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
    fontFamily: 'NotoSansSC',
  );
}

/// Provider
final themeProvider = ChangeNotifierProvider<ThemeState>((ref) {
  return ThemeState();
});
