import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart';

import 'package:stuttgart_network/services/auth_service.dart';
import 'package:stuttgart_network/auth/auth_screen.dart';
import 'package:stuttgart_network/home/home_screen.dart';

/// Сервис инициализации Supabase
class SupabaseService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    late final String supabaseUrl;
    late final String supabaseAnonKey;

    if (kIsWeb) {
      // Для Web используем встроенные ключи
      supabaseUrl = 'https://tgbvhlbcduwistqyfnwe.supabase.co';
      supabaseAnonKey =
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRnYnZobGJjZHV3aXN0cXlmbndlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUxMzkyMjUsImV4cCI6MjA4MDcxNTIyNX0.GO0dOuixqo2va6vwwGkieWyYuxHZhjRksY1HsmFlOYo';
    } else {
      // Для мобильных платформ используем .env
      await dotenv.load(fileName: "assets/.env");
      supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

      if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
        throw Exception('Ошибка: отсутствуют ключи Supabase в .env');
      }
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    _isInitialized = true;
  }

  static SupabaseClient get client {
    if (!_isInitialized) {
      throw Exception('Supabase не инициализирован. Вызовите SupabaseService.initialize()');
    }
    return Supabase.instance.client;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  await SupabaseService.initialize();
  runApp(const KJMCApp());
}

/// Главный виджет приложения
class KJMCApp extends StatelessWidget {
  const KJMCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KJMC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// Проверка авторизации пользователя
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthService().authStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;
        if (session != null) {
          return const HomeScreen();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}
