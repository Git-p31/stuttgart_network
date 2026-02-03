import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:stuttgart_network/auth/auth_screen.dart';
import 'package:stuttgart_network/home/home_screen.dart';

class SupabaseConfig {
  static const String url = 'https://tgbvhlbcduwistqyfnwe.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnYnZobGJjZHV3aXN0cXlmbndlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMzkyMjUsImV4cCI6MjA4MDcxNTIyNX0.GO0dOuixqo2va6vwwGkieWyYuxHZhjRksY1HsmFlOYo';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 1. Инициализация локализации
    await initializeDateFormatting('ru_RU', null);
    
    // 2. Инициализация Supabase (Firebase удален)
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
    
  } catch (e) {
    debugPrint('‼️ Ошибка запуска: $e');
  }

  runApp(const KJMCApp());
}

class KJMCApp extends StatelessWidget {
  const KJMCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KJMC Stuttgart',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final session = snapshot.data?.session;
        return session != null ? const HomeScreen() : const AuthScreen();
      },
    );
  }
}