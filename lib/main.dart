import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart';

import 'package:stuttgart_network/auth/auth_screen.dart';
import 'package:stuttgart_network/home/home_screen.dart';

// 1. Прописываем ключи прямо здесь. Это решит проблему с 404 навсегда.
class SupabaseConfig {
  static const String url = 'https://tgbvhlbcduwistqyfnwe.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnYnZobGJjZHV3aXN0cXlmbndlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMzkyMjUsImV4cCI6MjA4MDcxNTIyNX0.GO0dOuixqo2va6vwwGkieWyYuxHZhjRksY1HsmFlOYo';
}

class SupabaseService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Инициализация напрямую через константы без поиска файлов
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      
      _isInitialized = true;
      debugPrint('🚀 Supabase успешно запущен (Hardcoded Config)');
    } catch (e) {
      debugPrint('‼️ Ошибка инициализации Supabase: $e');
    }
  }

  static SupabaseClient get client {
    return Supabase.instance.client;
  }
}

Future<void> main() async {
  // Важно: Никаких dotenv.load() здесь быть не должно!
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await initializeDateFormatting('ru_RU', null);
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('⚠️ Ошибка при запуске: $e');
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
    // Безопасная проверка инициализации
    if (!SupabaseService._isInitialized) {
      return const Scaffold(
        body: Center(child: Text("Ошибка инициализации Supabase")),
      );
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final session = snapshot.data?.session;
        return session != null ? const HomeScreen() : const AuthScreen();
      },
    );
  }
}