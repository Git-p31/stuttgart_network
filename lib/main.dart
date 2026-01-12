import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart';

import 'package:stuttgart_network/auth/auth_screen.dart';
import 'package:stuttgart_network/home/home_screen.dart';

// Сервис для инициализации Supabase
class SupabaseService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Пытаемся загрузить файл конфигурации
    try {
      // В Flutter Web для dotenv самым стабильным является путь "assets/имя_файла"
      // так как физически в build/web файлы ложатся в папку assets
      await dotenv.load(fileName: "assets/env_config.txt");
      debugPrint('✅ Конфигурация успешно загружена из assets/env_config.txt');
    } catch (e) {
      debugPrint('⚠️ Не удалось загрузить через assets/, пробуем прямой путь...');
      try {
        // Резервный вариант для некоторых серверных конфигураций
        await dotenv.load(fileName: "env_config.txt");
        debugPrint('✅ Конфигурация загружена через env_config.txt');
      } catch (e2) {
        debugPrint('‼️ Ошибка: Файл конфигурации не найден в ассетах сборки.');
        // Мы не прерываем выполнение, чтобы не вызвать белый экран, 
        // но Supabase не инициализируется без ключей.
        return;
      }
    }

    final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      debugPrint('❌ Ошибка: Ключи в env_config.txt не найдены или пусты!');
      return;
    }

    // Инициализация Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );

    _isInitialized = true;
    debugPrint('🚀 Supabase успешно запущен!');
  }

  // Геттер для удобного доступа к клиенту из любой части приложения
  static SupabaseClient get client {
    if (!_isInitialized) throw Exception('Supabase еще не готов.');
    return Supabase.instance.client;
  }
}

Future<void> main() async {
  // 1. Привязка виджетов (обязательно для асинхронного main)
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // 2. Инициализация даты для Intl (русская локализация)
    await initializeDateFormatting('ru_RU', null);
    
    // 3. Запуск нашего сервиса Supabase
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('‼️ Критическая ошибка при старте: $e');
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
      // AuthGate сам решит, показать экран входа или главный экран
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Используем встроенный стрим Supabase для отслеживания сессии пользователя
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Пока ждем ответа от сервера (проверка токена)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // Если сессия существует — идем домой, если нет — на вход
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