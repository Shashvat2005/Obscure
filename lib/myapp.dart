import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:obscura/home.dart';

/// Top-level notifier so the app (and other widgets) can switch theme at runtime.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

/// Convenience setter that persists the choice and notifies listeners.
Future<void> setDarkModeEnabled(bool enabled) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setBool('dark_mode', enabled);
  themeNotifier.value = enabled ? ThemeMode.dark : ThemeMode.light;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // load stored preference at startup
  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final sp = await SharedPreferences.getInstance();
    final enabled = sp.getBool('dark_mode') ?? false;
    themeNotifier.value = enabled ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4DB6AC),
        brightness: Brightness.light,
        primary: const Color(0xFF4DB6AC),
        secondary: const Color(0xFF80CBC4),
        surface: const Color(0xFFE0F2F1),
        tertiary: const Color.fromARGB(255, 244, 255, 254),
        background: const Color(0xFFF5FDFC),
      ),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF4DB6AC),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: const Color(0xFF00796B),
        unselectedLabelColor: Colors.grey,
        indicator: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFF00796B),
              width: 2.0,
            ),
          ),
        ),
      ),
    );

    final darkTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4DB6AC),
        tertiary:  const Color.fromARGB(255, 82, 82, 82),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.teal[200],
        unselectedLabelColor: Colors.grey[400],
        indicator: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.teal[200]!,
              width: 2.0,
            ),
          ),
        ),
      ),
      scaffoldBackgroundColor: Colors.grey[900],
    );

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Obscura Gallery',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: mode,
          home: const HomePage(),
        );
      },
    );
  }
}
