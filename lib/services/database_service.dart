import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Глобальный клиент Supabase, инициализированный в main.dart
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

      return List<Map<String, dynamic>>.from(data);
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getCrmProfiles) Error: ${e.message}');
      rethrow;
    }
  }

  // ---------------- MINISTRIES ----------------

  /// ✅ Получает список служений с участниками и фото
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

      return List<Map<String, dynamic>>.from(data);
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
  
  /// ✅ Загружает список воркшопов с лидером, фото, тегами и участниками
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

      return List<Map<String, dynamic>>.from(data);
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

  /// ✅ Получает все события за указанный месяц
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

      return List<Map<String, dynamic>>.from(data);
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getEventsForMonth) Error: ${e.message}');
      rethrow;
    }
  }

  // ---------------- MARKETPLACE ----------------

  /// ✅ Получает все товары и услуги
  Future<List<Map<String, dynamic>>> getMarketplaceItems() async {
    try {
      final data = await supabase
          .from('marketplace')
          .select('''
            id,
            user_id,
            title,
            description,
            contact_info,
            price,
            image_url,
            is_service,
            created_at,
            profiles (
              full_name
            )
          ''')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getMarketplaceItems) Error: ${e.message}');
      rethrow;
    }
  }

  /// ✅ Добавляет новый товар или услугу в маркетплейс
  Future<String?> addMarketplaceItem({
    required String title,
    required String contactInfo,
    required bool isService,
    String? description,
    double? price,
    String? imagePath,
  }) async {
    if (_userId == null) throw Exception('Пользователь не авторизован');

    String? imageUrl;

    if (imagePath != null) {
      try {
        final file = File(imagePath);
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';

        // upload() возвращает путь как строку
        final uploadPath = await supabase.storage
            .from('marketplace_images')
            .upload(fileName, file);

        // Получаем публичную ссылку
        imageUrl = supabase.storage
            .from('marketplace_images')
            .getPublicUrl(uploadPath);
      } catch (storageError) {
        debugPrint('DatabaseService (addMarketplaceItem) Storage Error: $storageError');
        imageUrl = null; // Продолжаем без фото
      }
    }

    try {
      final itemData = {
        'user_id': _userId!,
        'title': title,
        'contact_info': contactInfo,
        'is_service': isService,
        if (description != null) 'description': description,
        if (price != null) 'price': price,
        if (imageUrl != null) 'image_url': imageUrl,
      };

      final result = await supabase
          .from('marketplace')
          .insert(itemData)
          .select('id')
          .single();

      return result['id'] as String?;
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (addMarketplaceItem) Error: ${e.message}');
      rethrow;
    }
  }

  /// ✅ Удаляет товар или услугу по ID
  Future<void> deleteMarketplaceItem(String itemId) async {
    try {
      await supabase.from('marketplace').delete().eq('id', itemId);
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (deleteMarketplaceItem) Error: ${e.message}');
      rethrow;
    }
  }

  /// ✅ Получает товары и услуги текущего пользователя
  Future<List<Map<String, dynamic>>> getMyMarketplaceItems() async {
    if (_userId == null) throw Exception('Пользователь не авторизован');

    try {
      final data = await supabase
          .from('marketplace')
          .select('''
            id,
            title,
            description,
            contact_info,
            price,
            image_url,
            is_service,
            created_at
          ''')
          .eq('user_id', _userId!)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(data);
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getMyMarketplaceItems) Error: ${e.message}');
      rethrow;
    }
  }
}
