import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const ProviderScope(child: RollCallApp()));
}

class RollCallApp extends ConsumerWidget {
  const RollCallApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    
    return MaterialApp(
      title: '点名诗韵',
      debugShowCheckedModeBanner: false,
      theme: themeState.lightTheme,
      darkTheme: themeState.darkTheme,
      themeMode: themeState.flutterThemeMode,
      home: const HomeScreen(),
    );
  }
}
