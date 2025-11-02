import 'package:flutter/foundation.dart'; // Для debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';

/// Глобальный клиент Supabase.
/// Предполагается, что он инициализирован в main.dart
final supabase = Supabase.instance.client;

class AuthService {
  
  /// Возвращает поток изменений состояния аутентификации.
  /// (Вошел пользователь, вышел и т.д.)
  Stream<AuthState> get authStateChange => supabase.auth.onAuthStateChange;

  /// Возвращает текущую сессию, если она есть.
  Session? get currentSession => supabase.auth.currentSession;

  /// Регистрация нового пользователя.
  /// 
  /// [email]: Email пользователя.
  /// [password]: Пароль (минимум 6 символов).
  /// [fullName]: Полное имя, будет передано в 'data' для триггера.
  /// [phone]: Телефон, будет передан в 'data' для триггера.
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    try {
      // Выполняем запрос на регистрацию
      await supabase.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        // 'data' используется нашим SQL-триггером в Supabase
        // для автоматического создания профиля в таблице 'profiles'.
        data: {
          'full_name': fullName.trim(),
          'phone': phone.trim(),
        },
      );
    } on AuthException catch (e) {
      // Логируем ошибку и пробрасываем ее дальше,
      // чтобы UI мог ее поймать и показать пользователю.
      debugPrint('AuthService (SignUp) Error: ${e.message}');
      rethrow;
    }
  }

  /// Вход существующего пользователя.
  /// 
  /// [email]: Email пользователя.
  /// [password]: Пароль пользователя.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Выполняем запрос на вход
      await supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } on AuthException catch (e) {
      // Логируем и пробрасываем ошибку для UI
      debugPrint('AuthService (SignIn) Error: ${e.message}');
      rethrow;
    }
  }

  /// Выход из системы (завершение сессии).
  Future<void> signOut() async {
    try {
      // Выполняем запрос на выход
      await supabase.auth.signOut();
    } on AuthException catch (e) {
      // Логируем и пробрасываем ошибку
      debugPrint('AuthService (SignOut) Error: ${e.message}');
      rethrow;
    }
  }
}