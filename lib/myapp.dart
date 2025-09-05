import 'package:flutter/material.dart';
import 'package:obscura/home.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Obscura Gallery',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4DB6AC),
          primary: const Color(0xFF4DB6AC),
          secondary: const Color(0xFF80CBC4),
          surface: const Color(0xFFE0F2F1),
          background: const Color(0xFFF5FDFC),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF4DB6AC),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        tabBarTheme: const TabBarTheme(
          labelColor: Color(0xFF00796B),
          unselectedLabelColor: Colors.grey,
          indicator: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Color(0xFF00796B),
                width: 2.0,
              ),
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}