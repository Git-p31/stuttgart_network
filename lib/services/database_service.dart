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

  /// Получает все профили (для CRM)
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

  /// Загружает все события начиная с 1-го числа текущего месяца
  Future<List<Map<String, dynamic>>> getUpcomingEvents() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String();

      final data = await supabase
          .from('events')
          .select()
          .gte('starts_at', startOfMonth)
          .order('starts_at', ascending: true);

      return (data as List).cast<Map<String, dynamic>>();
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getUpcomingEvents) Error: ${e.message}');
      rethrow;
    }
  }

  /// Получает события для конкретного месяца
  Future<List<Map<String, dynamic>>> getEventsForMonth(DateTime month) async {
    try {
      final firstDay = DateTime(month.year, month.month, 1);
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
