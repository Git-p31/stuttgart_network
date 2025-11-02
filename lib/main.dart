// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

// --- ИСПРАВЛЕННЫЕ ИМПОРТЫ (убрал /screens/) ---
import 'package:stuttgart_network/services/auth_service.dart';
import 'package:stuttgart_network/auth/auth_screen.dart';
import 'package:stuttgart_network/home/home_screen.dart';

Future<void> main() async {
  // 1. Инициализация Flutter
  WidgetsFlutterBinding.ensureInitialized();


 // 2. Загрузка ключей из .env
  await dotenv.load(fileName: "lib/assets/.env"); // <--- УКАЖИТЕ ПРАВИЛЬНЫЙ ПУТЬ


// ✅ 3. ДОБАВЬТЕ ЭТУ СТРОКУ (для инициализации русской локали)
  await initializeDateFormatting('ru_RU', null);

  // 3. Инициализация Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

// Глобальный клиент (удобно)
final supabase = Supabase.instance.client;

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
      // 4. AuthGate - наш "диспетчер"
      home: const AuthGate(),
    );
  }
}

/// AuthGate (Диспетчер)
/// Слушает состояние аутентификации и показывает нужный экран.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // 5. Используем StreamBuilder для прослушки потока authStateChange
    return StreamBuilder<AuthState>(
      // Берем поток из нашего AuthService
      stream: AuthService().authStateChange,
      builder: (context, snapshot) {
        // 6. Показываем индикатор загрузки, пока ждем
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        // 7. Если сессия ЕСТЬ (пользователь вошел) -> HomeScreen
        if (session != null) {
          return const HomeScreen();
        }
        // 8. Если сессии НЕТ (пользователь не вошел) -> AuthScreen
        else {
          return const AuthScreen();
        }
      },
    );
  }
}