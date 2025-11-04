import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
// --- Добавлен импорт foundation для kIsWeb ---
import 'package:flutter/foundation.dart';

// --- ИМПОРТЫ ---
import 'package:stuttgart_network/services/auth_service.dart';
import 'package:stuttgart_network/auth/auth_screen.dart';
import 'package:stuttgart_network/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String supabaseUrl;
  String supabaseAnonKey;

  if (kIsWeb) {
    // --- Настройки для веба ---
    // ВНИМАНИЕ: замените на свои реальные значения из Supabase Dashboard
    supabaseUrl = 'https://ylhanfsytvhpjqilolwe.supabase.co';
    supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlsaGFuZnN5dHZocGpxaWxvbHdlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE5MTk3NDEsImV4cCI6MjA3NzQ5NTc0MX0.0KsQsZ8kiad-RT7kjcj0ufX_gnkW3pF2zZ55nBIrPgw';
  } else {
    // --- Настройки для Android / iOS ---
    // Убедитесь, что файл .env находится в папке assets/ и прописан в pubspec.yaml
    await dotenv.load(fileName: "assets/.env");
    supabaseUrl = dotenv.env['SUPABASE_URL']!;
    supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
  }

  await initializeDateFormatting('ru_RU', null);

  // --- ИНИЦИАЛИЗАЦИЯ SUPABASE ---
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

// Глобальный клиент
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
        if (session != null) {
          return const HomeScreen();
        } else {
          return const AuthScreen();
        }
      },
    );
  }
}