import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Глобальный клиент, который мы инициализировали в main.dart
final supabase = Supabase.instance.client;

class DatabaseService {
  
  /// Приватный геттер для удобного получения ID текущего пользователя
  String? get _userId {
    return supabase.auth.currentUser?.id;
  }

  // --- 1. PROFILES & CRM ---

  /// Получает профиль текущего (вошедшего) пользователя.
  Future<Map<String, dynamic>> getMyProfile() async {
    if (_userId == null) throw Exception('Пользователь не авторизован');
    
    try {
      final data = await supabase
          .from('profiles')
          .select() // 'select *'
          .eq('id', _userId!)
          .single(); // .single() гарантирует, что мы получили 1 запись
      return data;
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getMyProfile) Error: ${e.message}');
      rethrow;
    }
  }

  /// Получает ВСЕ профили для экрана CRM.
  Future<List<Map<String, dynamic>>> getCrmProfiles() async {
    try {
      // RLS (Безопасность) позволяет нам читать все профили
      final data = await supabase
          .from('profiles')
          .select('id, full_name, email, phone, role')
          .order('full_name', ascending: true);
      return data;
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getCrmProfiles) Error: ${e.message}');
      rethrow;
    }
  }

  // --- 2. MINISTRIES (Служения) ---

  /// Получает ВСЕ служения ВМЕСТЕ с их участниками (JOIN).
  /// Это быстрый запрос, который решает проблему N+1.
  Future<List<Map<String, dynamic>>> getMinistries() async {
    try {
      final data = await supabase
          .from('ministries')
          .select('''
            id,
            name,
            description,
            ministry_members (
              user_id,
              role_in_ministry,
              profiles (
                full_name,
                phone
              )
            )
          ''')
          .order('name', ascending: true);
      return data;
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getMinistries) Error: ${e.message}');
      rethrow;
    }
  }

  /// Присоединиться к служению.
  Future<void> joinMinistry(String ministryId) async {
    if (_userId == null) throw Exception('Пользователь не авторизован');
    try {
      // Наша RLS-политика 'Allow user to join'
      // позволит эту вставку ТОЛЬКО если user_id == ID текущего пользователя.
      await supabase.from('ministry_members').insert({
        'ministry_id': ministryId,
        'user_id': _userId!,
        'role_in_ministry': 'member' // Роль по умолчанию
      });
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (joinMinistry) Error: ${e.message}');
      rethrow;
    }
  }

  /// Покинуть служение.
  Future<void> leaveMinistry(String ministryId) async {
    if (_userId == null) throw Exception('Пользователь не авторизован');
    try {
      // Наша RLS-политика 'Allow user to leave'
      // позволит удалить ТОЛЬКО свою запись.
      await supabase
          .from('ministry_members')
          .delete()
          .match({'ministry_id': ministryId, 'user_id': _userId!});
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (leaveMinistry) Error: ${e.message}');
      rethrow;
    }
  }

  // --- 3. WORKSHOPS (Воркшопы) ---

  /// Получает ВСЕ воркшопы ВМЕСТЕ с их участниками (JOIN).
  Future<List<Map<String, dynamic>>> getWorkshops() async {
    try {
      final data = await supabase
          .from('workshops')
          .select('''
            id,
            title,
            description,
            speaker,
            start_date,
            workshop_members (
              user_id
            )
          ''')
          .order('start_date', ascending: true);
      return data;
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getWorkshops) Error: ${e.message}');
      rethrow;
    }
  }
  
  /// Зарегистрироваться на воркшоп.
  Future<void> registerForWorkshop(String workshopId) async {
    if (_userId == null) throw Exception('Пользователь не авторизован');
    try {
      // RLS-политика 'Allow user to register'
      await supabase.from('workshop_members').insert({
        'workshop_id': workshopId,
        'user_id': _userId!,
      });
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (registerForWorkshop) Error: ${e.message}');
      rethrow;
    }
  }

  /// Отменить регистрацию на воркшоп.
  Future<void> unregisterFromWorkshop(String workshopId) async {
    if (_userId == null) throw Exception('Пользователь не авторизован');
    try {
      // RLS-политика 'Allow user to unregister'
      await supabase
          .from('workshop_members')
          .delete()
          .match({'workshop_id': workshopId, 'user_id': _userId!});
    } on PostgrestException catch (e) { // <-- Исправлено на правильное имя
      debugPrint('DatabaseService (unregisterFromWorkshop) Error: ${e.message}');
      rethrow;
    }
  }

  // --- 4. EVENTS (События) ---

  /// Получает все БУДУЩИЕ события.
  Future<List<Map<String, dynamic>>> getUpcomingEvents() async {
    try {
      final data = await supabase
          .from('events')
          .select()
          // 'gte' = 'больше или равно'
          .gte('starts_at', DateTime.now().toIso8601String())
          .order('starts_at', ascending: true);
      return data;
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getUpcomingEvents) Error: ${e.message}');
      rethrow;
    }
  }
}