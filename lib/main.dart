import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===== Edge-to-Edge Fullscreen =====
  // System UI overlays the app content (status bar + nav bar on top)
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );
  // Transparent status bar and navigation bar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await StorageService.init();
  runApp(const ProviderScope(child: RollCallApp()));
}

class RollCallApp extends ConsumerStatefulWidget {
  const RollCallApp({super.key});

  @override
  ConsumerState<RollCallApp> createState() => _RollCallAppState();
}

class _RollCallAppState extends ConsumerState<RollCallApp> {
  @override
  void initState() {
    super.initState();
    // 加载持久化的主题设置
    Future.microtask(() {
      ref.read(themeProvider).loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // 传递平台动态颜色给 ThemeState
        if (themeState.dynamicColorEnabled) {
          // 根据当前主题模式选择对应的动态颜色方案
          final brightness = View.of(context).platformDispatcher.platformBrightness;
          final dynamicScheme = brightness == Brightness.dark
              ? darkDynamic
              : lightDynamic;
          if (dynamicScheme != null) {
            // 使用 addPostFrameCallback 避免在 build 中调用 notifyListeners
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                themeState.setPlatformColorScheme(dynamicScheme);
              }
            });
          }
        }

        return MaterialApp(
          title: '点到为止',
          debugShowCheckedModeBanner: false,
          theme: themeState.lightTheme,
          darkTheme: themeState.darkTheme,
          themeMode: themeState.flutterThemeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
