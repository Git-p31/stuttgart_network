// УБЕРІТЕ 'late' з першого рядка, якщо він є:
// late final supabase = Supabase.instance.client; // <-- Це має бути в іншому місці, наприклад, в SupabaseService

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
// --- Добавлен импорт foundation для kIsWeb ---
import 'package:flutter/foundation.dart';

// --- ИМПОРТЫ ДЛЯ ВАШИХ ВЛАСНИХ ФАЙЛІВ ---
// Замініть на шляхи до ваших файлів, якщо вони інші
import 'package:stuttgart_network/services/auth_service.dart';
import 'package:stuttgart_network/auth/auth_screen.dart';
import 'package:stuttgart_network/home/home_screen.dart';

// --- 1. ВИНЕСЕНО: Створення сервісу ініціалізації Supabase ---
class SupabaseService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    String supabaseUrl;
    String supabaseAnonKey;

    if (kIsWeb) {
      // ВАЖЛИВО: УБЕДІТЬСЯ, ЩО У ВАС НЕМАЄ ЛИШНІХ ПРОБІЛІВ У ЦИХ РЯДКАХ!
      supabaseUrl = 'https://vmckxdfrkvpduqbyugfo.supabase.co';
      supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZtY2t4ZGZya3ZwZHVxYnl1Z2ZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI0NjE1MDAsImV4cCI6MjA3ODAzNzUwMH0.ZrifSQNrf4CFvgY9tYLoc42GO0J1GavZvj-m35teoJI';
    } else {
      // ЗАВАНТАЖЕННЯ .env ПОТРІБНО ТІЛЬКИ ДЛЯ МОБІЛЬНИХ ПЛАТФОРМ
      await dotenv.load(fileName: "assets/.env");
      supabaseUrl = dotenv.env['SUPABASE_URL']!;
      supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    _isInitialized = true;
  }

  static SupabaseClient get client {
    if (!_isInitialized) {
      throw Exception('Supabase не ініціалізовано. Викличте SupabaseService.initialize()');
    }
    return Supabase.instance.client;
  }
}

// --- 2. ОСНОВНИЙ МЕТОД main ---
Future<void> main() async {
  // Обов'язково викликайте це першим для Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Завантаження .env (тільки для мобільних)
  if (!kIsWeb) {
    await dotenv.load(fileName: "assets/.env");
  }

  // ІНІЦІАЛІЗАЦІЯ ФОРМАТУ ДАТИ (можна залишити тут, якщо використовується відразу)
  await initializeDateFormatting('ru_RU', null);

  // ЗАПУСК ПРИКЛАДУ (ініціалізація Supabase відкладена)
  runApp(const MyApp());
}

// --- 3. КЛАС MyApp ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stuttgart Network',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const AuthGate(), // Переконайтесь, що AuthGate реалізований нижче
    );
  }
}

// --- 4. КЛАС AuthGate З ВІДКЛАДЕНОЮ ІНІЦІАЛІЗАЦІЄЮ ТА StreamBuilder ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Використовуємо FutureBuilder для ініціалізації Supabase
    return FutureBuilder(
      future: SupabaseService.initialize(), // Ініціалізація тут
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Помилка: ${snapshot.error}')),
          );
        }

        // Після успішної ініціалізації, починаємо прослуховувати стан аутентифікації
        return StreamBuilder<AuthState>(
          stream: AuthService().authStateChange, // Переконайтесь, що це існує в AuthService
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final session = authSnapshot.data?.session;
            if (session != null) {
              // ЗАМІНІТЬ НА СВІЙ HomeScreen
              return const HomeScreen(); // Переконайтесь, що HomeScreen імпортований і існує
            } else {
              // ЗАМІНІТЬ НА СВІЙ AuthScreen
              return const AuthScreen(); // Переконайтесь, що AuthScreen імпортований і існує
            }
          },
        );
      },
    );
  }
}

// --- 5. ГЛОБАЛЬНИЙ КЛІЄНТ (ОПЦІОНАЛЬНО, ЯКЩО ВИКОРИСТОВУЄТЕ В БАГАТЬОХ МІСЦЯХ) ---
// Якщо ви хочете мати доступ до клієнта через глобальну змінну, використовуйте SupabaseService.client
// late final supabase = SupabaseService.client; // <- Краще викликати SupabaseService.client безпосередньо