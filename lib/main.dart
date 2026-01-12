import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart'; // Для kIsWeb и debugPrint

import 'package:stuttgart_network/services/auth_service.dart';
import 'package:stuttgart_network/auth/auth_screen.dart';
import 'package:stuttgart_network/home/home_screen.dart';

class SupabaseService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    bool isLoaded = false;
    
    // ПУТИ ДЛЯ ПОИСКА:
    // 1. "assets/assets/.env" — путь с вашего скриншота (из-за вложенности папок)
    // 2. "assets/.env" — стандартный путь Flutter
    // 3. ".env" — корень ассетов в Web
    final List<String> pathsToTry = [
      "assets/assets/.env",
      "assets/config.env", 
      "assets/.env", 
      ".env"
    ];

    for (String path in pathsToTry) {
      try {
        await dotenv.load(fileName: path);
        isLoaded = true;
        debugPrint('✅ Конфигурация успешно загружена по пути: $path');
        break; 
      } catch (e) {
        debugPrint('ℹ️ Поиск в $path не удался, пробуем дальше...');
      }
    }

    if (!isLoaded) {
      throw Exception('❌ Ошибка: Файл .env не найден. Проверьте папку build/web/assets/');
    }

    final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception('❌ Ошибка: Ключи Supabase не найдены внутри загруженного файла');
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    _isInitialized = true;
    debugPrint('🚀 Supabase инициализирован успешно!');
  }

  static SupabaseClient get client {
    if (!_isInitialized) throw Exception('Supabase не инициализирован.');
    return Supabase.instance.client;
  }
}

Future<void> main() async {
  // Инициализация движка Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Настройка локализации
    await initializeDateFormatting('ru_RU', null);
    
    // Запуск Supabase
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
        return session != null ? const HomeScreen() : const AuthScreen();
      },
    );
  }
}