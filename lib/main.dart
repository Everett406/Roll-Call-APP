import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const ProviderScope(child: RollCallApp()));
}

class RollCallApp extends StatelessWidget {
  const RollCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '点名助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        fontFamily: 'NotoSansSC',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        fontFamily: 'NotoSansSC',
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
