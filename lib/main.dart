import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart';

import 'package:stuttgart_network/services/auth_service.dart';
import 'package:stuttgart_network/auth/auth_screen.dart';
import 'package:stuttgart_network/home/home_screen.dart';

class SupabaseService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Для Web версии самым надежным путем является "assets/.env"
    // если файл лежит в корне проекта и прописан в pubspec.yaml
    try {
      await dotenv.load(fileName: "assets/.env");
      debugPrint('✅ Конфигурация .env загружена');
    } catch (e) {
      debugPrint('⚠️ Ошибка загрузки assets/.env: $e');
      debugPrint('🔄 Попытка загрузки из корня...');
      try {
        await dotenv.load(fileName: ".env");
      } catch (e2) {
        throw Exception('❌ Критическая ошибка: Файл .env не найден. Проверьте pubspec.yaml');
      }
    }

    final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception('❌ Ошибка: Ключи SUPABASE_URL или SUPABASE_ANON_KEY пусты!');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    _isInitialized = true;
    debugPrint('🚀 Supabase успешно запущен!');
  }

  static SupabaseClient get client {
    if (!_isInitialized) throw Exception('Supabase не инициализирован.');
    return Supabase.instance.client;
  }
}

Future<void> main() async {
  // 1. Обязательная привязка виджетов
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 2. Локализация (русский язык)
    await initializeDateFormatting('ru_RU', null);
    
    // 3. Загрузка конфигов и старт Supabase
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('‼️ Ошибка при запуске приложения: $e');
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
      // Убедитесь, что в AuthService используется корректный клиент Supabase
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