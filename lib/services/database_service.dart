import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Глобальный клиент, который мы инициализировали в main.dart
final supabase = Supabase.instance.client;

class DatabaseService {
  /// Приватный геттер для ID текущего пользователя
  String? get _userId => supabase.auth.currentUser?.id;

  // ---------------- PROFILES ----------------

  /// Получает профиль текущего пользователя
  Future<Map<String, dynamic>> getMyProfile() async {
    if (_userId == null) throw Exception('Пользователь не авторизован');

    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', _userId!)
          .single();
      return data;
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getMyProfile) Error: ${e.message}');
      rethrow;
    }
  }

  /// Получает все профили (для CRM и выбора Лидера)
  Future<List<Map<String, dynamic>>> getCrmProfiles() async {
    try {
      final data = await supabase
          .from('profiles')
          .select('id, full_name, email, phone, role')
          .order('full_name', ascending: true);
      return (data as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getCrmProfiles) Error: ${e.message}');
      rethrow;
    }
  }

  // ---------------- MINISTRIES ----------------

  /// ✅ ОБНОВЛЕНО: Добавлен 'image_url'
  Future<List<Map<String, dynamic>>> getMinistries() async {
    try {
      final data = await supabase
          .from('ministries')
          .select('''
            id,
            name,
            description,
            image_url, 
            ministry_members (
              user_id,
              role_in_ministry,
              profiles (
                id, 
                full_name,
                phone
              )
            )
          ''')
          .order('name', ascending: true);
      return (data as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getMinistries) Error: ${e.message}');
      rethrow;
    }
  }

  Future<void> joinMinistry(String ministryId) async {
    if (_userId == null) throw Exception('Пользователь не авторизован');
    try {
      await supabase.from('ministry_members').insert({
        'ministry_id': ministryId,
        'user_id': _userId!,
        'role_in_ministry': 'member'
      });
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (joinMinistry) Error: ${e.message}');
      rethrow;
    }
  }

  Future<void> leaveMinistry(String ministryId) async {
    if (_userId == null) throw Exception('Пользователь не авторизован');
    try {
      await supabase
          .from('ministry_members')
          .delete()
          .match({'ministry_id': ministryId, 'user_id': _userId!});
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (leaveMinistry) Error: ${e.message}');
      rethrow;
    }
  }

  // ---------------- WORKSHOPS ----------------
  
  /// ✅ ОБНОВЛЕНО: Загружает все новые поля (лидер, фото, теги, даты)
  Future<List<Map<String, dynamic>>> getWorkshops() async {
    try {
      final data = await supabase
          .from('workshops')
          .select('''
            id,
            title,
            description,
            start_date,
            end_date,
            max_participants,
            image_url, 
            tags,
            workshop_members (
              user_id
            ),
            leader:leader_id (
              id,
              full_name
            )
          ''')
          .order('start_date', ascending: true);
      return (data as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getWorkshops) Error: ${e.message}');
      rethrow;
    }
  }

  Future<void> registerForWorkshop(String workshopId) async {
    if (_userId == null) throw Exception('Пользователь не авторизован');
    try {
      await supabase.from('workshop_members').insert({
        'workshop_id': workshopId,
        'user_id': _userId!,
      });
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (registerForWorkshop) Error: ${e.message}');
      rethrow;
    }
  }

  Future<void> unregisterFromWorkshop(String workshopId) async {
    if (_userId == null) throw Exception('Пользователь не авторизован');
    try {
      await supabase
          .from('workshop_members')
          .delete()
          .match({'workshop_id': workshopId, 'user_id': _userId!});
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (unregisterFromWorkshop) Error: ${e.message}');
      rethrow;
    }
  }

  // ---------------- EVENTS ----------------

  // 🛑 'getUpcomingEvents()' УДАЛЕНА, так как она была с багом и не используется.

  /// ✅ Эта функция используется экраном Календаря
  Future<List<Map<String, dynamic>>> getEventsForMonth(DateTime month) async {
    try {
      // 1-е число месяца (00:00)
      final firstDay = DateTime(month.year, month.month, 1);
      // Последний день месяца (23:59:59)
      final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

      final data = await supabase
          .from('events')
          .select()
          .gte('starts_at', firstDay.toIso8601String())
          .lte('starts_at', lastDay.toIso8601String())
          .order('starts_at', ascending: true);

      return (data as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getEventsForMonth) Error: ${e.message}');
      rethrow;
    }
  }
}

