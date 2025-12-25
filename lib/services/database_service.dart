import 'package:flutter/foundation.dart'; // Для debugPrint и kIsWeb
import 'package:supabase_flutter/supabase_flutter.dart';

// Глобальный клиент Supabase
final supabase = Supabase.instance.client;

class DatabaseService {
  /// Геттер для ID текущего пользователя
  String? get _userId => supabase.auth.currentUser?.id;

// ---------------- PROFILES & CRM ----------------

  /// Получает профиль текущего пользователя
  Future<Map<String, dynamic>> getMyProfile() async {
    final userId = _userId;
    if (userId == null) throw Exception('Пользователь не авторизован');

    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (data == null) throw Exception('Профиль не найден');
      return Map<String, dynamic>.from(data);
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getMyProfile) Error: ${e.message}');
      rethrow;
    }
  }

  /// Получает расширенные профили для CRM (включая служения и воркшопы)
  Future<List<Map<String, dynamic>>> getCrmProfiles() async {
    try {
      // Запрос тянет данные профиля и названия связанных сущностей
      final data = await supabase
          .from('profiles')
          .select('''
            id, 
            full_name, 
            email, 
            phone, 
            role, 
            address, 
            birthday,
            ministries:ministry_members(ministries(name)),
            workshops:workshop_members(workshops(title))
          ''')
          .order('full_name', ascending: true);

      return List<Map<String, dynamic>>.from(data);
    } on PostgrestException catch (e) {
      debugPrint('DatabaseService (getCrmProfiles) Error: ${e.message}');
      rethrow;
    }
  }

  /// Обновление расширенных данных пользователя в CRM
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String phone,
    required String role,
    String? address,
    String? birthday,
  }) async {
    try {
      await supabase.from('profiles').update({
        'full_name': fullName,
        'phone': phone,
        'role': role,
        'address': address,
        'birthday': birthday, // Формат ГГГГ-ММ-ДД
      }).eq('id', userId);
    } catch (e) {
      debugPrint('DatabaseService (updateProfile) Error: $e');
      rethrow;
    }
  }

  /// Удаление профиля пользователя
  Future<void> deleteProfile(String userId) async {
    try {
      await supabase.from('profiles').delete().eq('id', userId);
    } catch (e) {
      debugPrint('DatabaseService (deleteProfile) Error: $e');
      rethrow;
    }
  }

  // ---------------- MINISTRIES ----------------

  Future<List<Map<String, dynamic>>> getMinistries() async {
    try {
      final data = await supabase
          .from('ministries')
          .select('''
            id, name, description, image_url,
            ministry_members (
              user_id, role_in_ministry,
              profiles (id, full_name, phone)
            )
          ''')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('DatabaseService (getMinistries) Error: $e');
      rethrow;
    }
  }

  Future<void> joinMinistry(String ministryId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Пользователь не авторизован');
    await supabase.from('ministry_members').insert({
      'ministry_id': ministryId,
      'user_id': userId,
      'role_in_ministry': 'member',
    });
  }

  Future<void> leaveMinistry(String ministryId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Пользователь не авторизован');
    await supabase
        .from('ministry_members')
        .delete()
        .match({'ministry_id': ministryId, 'user_id': userId});
  }

  // ---------------- WORKSHOPS ----------------

  Future<List<Map<String, dynamic>>> getWorkshops() async {
    try {
      final data = await supabase
          .from('workshops')
          .select('''
            id, title, description, start_date, end_date, max_participants, image_url, tags,
            recurring_schedule, recurring_time,
            workshop_members (user_id, profiles (id, full_name, phone)),
            leader:leader_id (id, full_name)
          ''')
          .order('start_date', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('DatabaseService (getWorkshops) Error: $e');
      rethrow;
    }
  }

  Future<void> registerForWorkshop(String workshopId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Пользователь не авторизован');
    await supabase.from('workshop_members').upsert({
      'workshop_id': workshopId,
      'user_id': userId,
    });
  }

  Future<void> unregisterFromWorkshop(String workshopId) async {
    final userId = _userId;
    if (userId == null) throw Exception('Пользователь не авторизован');
    await supabase
        .from('workshop_members')
        .delete()
        .match({'workshop_id': workshopId, 'user_id': userId});
  }

  Future<void> deleteWorkshop(String workshopId) async {
    try {
      await supabase.from('workshop_members').delete().eq('workshop_id', workshopId);
      await supabase.from('workshops').delete().eq('id', workshopId);
    } catch (e) {
      debugPrint('DatabaseService (deleteWorkshop) Error: $e');
      rethrow;
    }
  }

  // ---------------- EVENTS ----------------

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
    } catch (e) {
      debugPrint('DatabaseService (getEventsForMonth) Error: $e');
      rethrow;
    }
  }

  // ---------------- MARKETPLACE ----------------

  Future<List<Map<String, dynamic>>> getMarketplaceItems() async {
    try {
      final data = await supabase
          .from('marketplace')
          .select('*, profiles(full_name)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('DatabaseService (getMarketplaceItems) Error: $e');
      rethrow;
    }
  }

  Future<String?> addMarketplaceItem({
    required String title,
    required String contactInfo,
    required bool isService,
    String? description,
    double? price,
    Uint8List? imageBytes,
    String? imageExtension,
  }) async {
    final userId = _userId;
    if (userId == null) throw Exception('Пользователь не авторизован');

    String? imageUrl;
    if (imageBytes != null) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.${imageExtension ?? 'jpg'}';
        await supabase.storage.from('marketplace_images').uploadBinary(
          fileName, 
          imageBytes,
          fileOptions: const FileOptions(upsert: true),
        );
        imageUrl = supabase.storage.from('marketplace_images').getPublicUrl(fileName);
      } catch (e) {
        debugPrint('Storage Error: $e');
      }
    }

    final result = await supabase.from('marketplace').insert({
      'user_id': userId,
      'title': title,
      'contact_info': contactInfo,
      'is_service': isService,
      if (description != null) 'description': description,
      if (price != null) 'price': price,
      if (imageUrl != null) 'image_url': imageUrl,
    }).select('id').single();

    return result['id'] as String?;
  }

  // ---------------- BOARDS ----------------

  Future<Map<String, dynamic>> getBoardData(String? ministryId, String? workshopId) async {
    try {
      var query = supabase.from('boards').select('id, board_items(*)');
      if (ministryId != null) query = query.eq('ministry_id', ministryId);
      else if (workshopId != null) query = query.eq('workshop_id', workshopId);

      final data = await query.maybeSingle();
      return data != null ? Map<String, dynamic>.from(data) : {'id': '', 'board_items': []};
    } catch (e) {
      return {'id': '', 'board_items': []};
    }
  }

  Future<void> addBoardItem(String boardId, String content) async {
    await supabase.from('board_items').insert({
      'board_id': boardId, 
      'content': content.trim()
    });
  }

  Future<void> deleteBoardItem(String itemId) async {
    await supabase.from('board_items').delete().eq('id', itemId);
  }

  Future<void> toggleBoardItem(String itemId, bool isDone) async {
    await supabase.from('board_items').update({'is_done': isDone}).eq('id', itemId);
  }

  // ---------------- CHATS ----------------

  Stream<List<Map<String, dynamic>>> getChatMessagesStream(String groupId) {
    return supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('created_at', ascending: true);
  }

  Future<void> sendChatMessage(String groupId, String content) async {
    final userId = _userId;
    if (userId == null) return;
    await supabase.from('chat_messages').insert({
      'group_id': groupId, 
      'sender_id': userId, 
      'content': content.trim()
    });
  }

  // ---------------- PERSONAL DATA (ProfileScreen) ----------------

  Future<List<Map<String, dynamic>>> getMyWorkshops() async {
    final userId = _userId;
    if (userId == null) return [];
    final data = await supabase
        .from('workshops')
        .select('*, workshop_members!inner(user_id), leader:leader_id(id, full_name)')
        .eq('workshop_members.user_id', userId);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> getMyMinistries() async {
    final userId = _userId;
    if (userId == null) return [];
    try {
      final data = await supabase
          .from('ministries')
          .select('*, ministry_members!inner(user_id)')
          .eq('ministry_members.user_id', userId)
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('DatabaseService (getMyMinistries) Error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getMyMarketplaceItems() async {
    final userId = _userId;
    if (userId == null) return [];
    try {
      final data = await supabase
          .from('marketplace')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('DatabaseService (getMyMarketplaceItems) Error: $e');
      return [];
    }
  }
}