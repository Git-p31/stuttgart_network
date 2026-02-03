import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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
    
    // 2. Инициализация Firebase с твоими данными
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAjFDeVoyWujua_AFz-20TzKEFskDWuvtc",
        appId: "1:985778294896:web:ce37e77c270c28ca2b24b5",
        messagingSenderId: "985778294896",
        projectId: "kjmc-132af",
      ),
    );

    // 3. Инициализация Supabase
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );

    // 4. Настройка уведомлений (только для Web)
    if (kIsWeb) {
      _initWebPush();
    }
    
  } catch (e) {
    debugPrint('‼️ Ошибка запуска: $e');
  }

  runApp(const KJMCApp());
}

/// Инициализация Web Push
Future<void> _initWebPush() async {
  final messaging = FirebaseMessaging.instance;
  
  // Запрос разрешения у браузера
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    // Используем твой VAPID Key
    String? token = await messaging.getToken(
      vapidKey: "BKB1N4Yzuk_P9Sm9Qi1M2T_DL7N-PifdyuRnrYRn3SeLTOVoQIIixbTNqqHSTI10AWqmLupiCqaQy1YoBIXd-4Q", 
    );

    if (token != null) {
      debugPrint('🚀 Web Push Token: $token');
      _saveTokenToDatabase(token);
    }
  }
}

/// Сохранение токена в Supabase
Future<void> _saveTokenToDatabase(String token) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user != null) {
    try {
      await Supabase.instance.client.from('user_tokens').upsert({
        'user_id': user.id,
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ Токен сохранен в БД');
    } catch (e) {
      debugPrint('❌ Ошибка сохранения токена: $e');
    }
  }
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
        
        // Если зашли в систему, пробуем обновить токен (на случай если AuthGate сработал позже)
        if (session != null && kIsWeb) {
          FirebaseMessaging.instance.getToken(vapidKey: "BKB1N4Yzuk_P9Sm9Qi1M2T_DL7N-PifdyuRnrYRn3SeLTOVoQIIixbTNqqHSTI10AWqmLupiCqaQy1YoBIXd-4Q").then((token) {
            if (token != null) _saveTokenToDatabase(token);
          });
        }

        return session != null ? const HomeScreen() : const AuthScreen();
      },
    );
  }
}