import 'dart:io'; 
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:dotted_border/dotted_border.dart';
import 'package:stuttgart_network/home/workshop_detail_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:stuttgart_network/services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
const uuid = Uuid();

class WorkshopsScreen extends StatefulWidget {
  const WorkshopsScreen({super.key});

  @override
  State<WorkshopsScreen> createState() => _WorkshopsScreenState();
}

class _WorkshopsScreenState extends State<WorkshopsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = supabase.auth.currentUser!.id;
  
  late Future<Map<String, dynamic>> _dataFuture;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _workshops = [];

  final Map<String, bool> _workshopLoadingState = {};
  final double _breakpoint = 600.0; 

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadScreenData();
  }

  Future<Map<String, dynamic>> _loadScreenData() async {
    try {
      final results = await Future.wait([
        _databaseService.getMyProfile(),
        _databaseService.getWorkshops(),
      ]);

      _profileData = results[0] as Map<String, dynamic>;
      _workshops = (results[1] as List).cast<Map<String, dynamic>>();

      return {
        'profile': _profileData,
        'workshops': _workshops,
      };
    } catch (e) {
      throw Exception('Ошибка загрузки данных: $e');
    }
  }

  void _refreshData() {
    setState(() {
      _dataFuture = _loadScreenData();
    });
  }

  Future<void> _toggleRegistration(String workshopId, bool isMember) async {
    setState(() => _workshopLoadingState[workshopId] = true);
    try {
      if (isMember) {
        await _databaseService.unregisterFromWorkshop(workshopId);
      } else {
        await _databaseService.registerForWorkshop(workshopId);
      }
      _refreshData(); 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _workshopLoadingState.remove(workshopId));
    }
  }

  /// Логика удаления воркшопа
  Future<void> _deleteWorkshop(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить воркшоп?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _databaseService.deleteWorkshop(id);
        _refreshData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка удаления: $e')));
        }
      }
    }
  }

  String _formatSchedule(String? recurringSchedule, String? recurringTime) {
    if (recurringSchedule == null || recurringTime == null) return 'Расписание не указано';
    return '$recurringSchedule, $recurringTime';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Ошибка: ${snapshot.error}'));
        
        final profile = snapshot.data!['profile'] as Map<String, dynamic>;
        final workshops = snapshot.data!['workshops'] as List<Map<String, dynamic>>;
        _profileData = profile;
        _workshops = workshops;
        final bool isAdmin = profile['role'] == 'admin';

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < _breakpoint;
            return Scaffold(
              body: isMobile ? _buildMobileLayout(workshops) : _buildWebLayout(workshops, isAdmin),
              floatingActionButton: (isAdmin && isMobile)
                  ? FloatingActionButton(
                      heroTag: 'workshops_fab_unique', // ✅ Исправлена ошибка Hero
                      onPressed: () => _showResponsiveCreateDialog(context, true),
                      child: const Icon(Icons.add),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildMobileLayout(List<Map<String, dynamic>> workshops) {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0), 
        itemCount: workshops.length,
        itemBuilder: (context, index) => _buildWorkshopCard(workshops[index]),
      ),
    );
  }

  Widget _buildWebLayout(List<Map<String, dynamic>> workshops, bool isAdmin) {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: GridView.builder(
        padding: const EdgeInsets.all(24.0), 
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 500.0,
          mainAxisSpacing: 24.0,
          crossAxisSpacing: 24.0,
          childAspectRatio: 0.8,
        ),
        itemCount: isAdmin ? workshops.length + 1 : workshops.length,
        itemBuilder: (context, index) {
          if (isAdmin && index == 0) return _buildCreateCard(context);
          final workshopIndex = isAdmin ? index - 1 : index; 
          return _buildWorkshopCard(workshops[workshopIndex]);
        },
      ),
    );
  }

  Widget _buildCreateCard(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showResponsiveCreateDialog(context, false),
      borderRadius: BorderRadius.circular(12.0),
      child: DottedBorder( 
        color: theme.colorScheme.outline,
        borderType: BorderType.RRect, 
        strokeWidth: 2,
        dashPattern: const [8, 4],
        radius: const Radius.circular(12.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              const Text('Создать воркшоп'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkshopCard(Map<String, dynamic> workshop) {
    final theme = Theme.of(context);
    final String id = workshop['id'];
    final String title = workshop['title'] ?? 'Без названия';
    final String description = workshop['description'] ?? 'Нет описания.';
    final String? imageUrl = workshop['image_url'];
    final int maxParticipants = workshop['max_participants'] ?? 50;
    final String leaderName = workshop['leader']?['full_name'] ?? 'Не назначен';
    final String scheduleStr = _formatSchedule(workshop['recurring_schedule'], workshop['recurring_time']);
    final List<String> tags = (workshop['tags'] as List?)?.cast<String>() ?? [];
    final List members = (workshop['workshop_members'] as List?) ?? [];
    final int memberCount = members.length;
    final bool isMember = members.any((m) => m['user_id'] == _currentUserId);
    final bool isFull = memberCount >= maxParticipants;
    final bool isLoading = _workshopLoadingState[id] ?? false;
    final bool isAdmin = _profileData?['role'] == 'admin';

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              if (imageUrl != null)
                Image.network(imageUrl, height: 220, width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(theme))
              else
                _buildImagePlaceholder(theme, height: 220),
              
              if (isAdmin) // Кнопка удаления для админа
                Positioned(
                  top: 8, right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.9),
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteWorkshop(id),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tags.isNotEmpty)
                  Wrap(spacing: 6.0, runSpacing: 4.0,
                    children: tags.map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                      labelStyle: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                if (tags.isNotEmpty) const SizedBox(height: 12),
                Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.mic_external_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(leaderName, style: theme.textTheme.bodyMedium),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.access_time_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Flexible(child: Text(scheduleStr, style: theme.textTheme.bodyMedium)),
                ]),
                const SizedBox(height: 8),
                Text(description, maxLines: 4, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Участники:', style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey)),
                  Text('$memberCount / $maxParticipants', 
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isFull ? theme.colorScheme.error : theme.colorScheme.secondary,
                      fontWeight: FontWeight.bold)),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (context) => WorkshopDetailScreen(
                        workshop: workshop, currentUserId: _currentUserId, isAdmin: isAdmin),
                    )).then((value) => value == true ? _refreshData() : null),
                    child: const Text('Подробнее'),
                  ),
                  const SizedBox(width: 8),
                  isLoading ? const CircularProgressIndicator() : _buildJoinButton(isMember, isFull, id)
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(ThemeData theme, {double height = 180}) {
    return Container(height: height, width: double.infinity, color: theme.colorScheme.surfaceContainerHighest,
      child: Center(child: Icon(Icons.school, size: 60, color: theme.colorScheme.onSurfaceVariant)));
  }

  Widget _buildJoinButton(bool isMember, bool isFull, String workshopId) {
    if (_profileData?['role'] == 'admin') {
      return ElevatedButton.icon(
        onPressed: () => _showResponsiveCreateDialog(context, false, 
          event: _workshops.firstWhere((w) => w['id'] == workshopId)),
        icon: const Icon(Icons.edit, size: 18),
        label: const Text('Ред-ть'),
      );
    }
    if (isMember) {
      return ElevatedButton.icon(
        onPressed: () => _toggleRegistration(workshopId, true),
        icon: const Icon(Icons.remove_circle_outline, size: 18),
        label: const Text('Покинуть'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          foregroundColor: Theme.of(context).colorScheme.onErrorContainer),
      );
    }
    if (isFull) {
      return ElevatedButton.icon(onPressed: null, icon: const Icon(Icons.block, size: 18), label: const Text('Мест нет'));
    }
    return ElevatedButton.icon(
      onPressed: () => _toggleRegistration(workshopId, false),
      icon: const Icon(Icons.add_circle_outline, size: 18),
      label: const Text('Присоединиться'),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800], foregroundColor: Colors.white),
    );
  }

  void _showResponsiveCreateDialog(BuildContext context, bool isMobile, {Map<String, dynamic>? event}) {
    final Widget dialogContent = _buildCreateDialogContent(event: event);
    if (isMobile) {
      showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => dialogContent);
    } else {
      showDialog(context: context, builder: (ctx) => AlertDialog(
        content: SizedBox(width: 600, child: dialogContent),
        contentPadding: EdgeInsets.zero));
    }
  }

  Widget _buildCreateDialogContent({Map<String, dynamic>? event}) {
    final bool isEditMode = event != null;
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: event?['title']);
    final descriptionController = TextEditingController(text: event?['description']);
    final maxParticipantsController = TextEditingController(text: event?['max_participants']?.toString() ?? '50');
    final tagsController = TextEditingController(text: (event?['tags'] as List?)?.cast<String>().join(', ') ?? '');
    final recurringScheduleController = TextEditingController(text: event?['recurring_schedule'] ?? '');
    final recurringTimeController = TextEditingController(text: event?['recurring_time'] ?? '');
    String? selectedLeaderId = event?['leader_id'];
    String? existingImageUrl = event?['image_url'];
    XFile? pickedImage;
    bool isLoading = false;

    return StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        Future<void> handleSave() async {
          if (!formKey.currentState!.validate()) return;
          setDialogState(() => isLoading = true);
          try {
            String? imageUrl = existingImageUrl;
            if (pickedImage != null) {
              final fileName = '${uuid.v4()}.jpg';
              await supabase.storage.from('workshop_images').uploadBinary(fileName, await pickedImage!.readAsBytes());
              imageUrl = supabase.storage.from('workshop_images').getPublicUrl(fileName);
            }

            final data = {
              'title': titleController.text,
              'description': descriptionController.text,
              'leader_id': selectedLeaderId,
              'max_participants': int.tryParse(maxParticipantsController.text) ?? 50,
              'tags': tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
              'image_url': imageUrl,
              'recurring_schedule': recurringScheduleController.text,
              'recurring_time': recurringTimeController.text,
            };

            if (isEditMode) {
              await supabase.from('workshops').update(data).eq('id', event['id']);
            } else {
              await supabase.from('workshops').insert(data);
            }
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            _refreshData(); 
          } catch (e) {
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
            }
          } finally {
            setDialogState(() => isLoading = false);
          }
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(dialogContext).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isEditMode ? 'Редактировать воркшоп' : 'Новый воркшоп', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 24),
                TextFormField(controller: titleController, decoration: const InputDecoration(labelText: 'Название'), 
                  validator: (val) => val == null || val.isEmpty ? 'Введите название' : null),
                const SizedBox(height: 16),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _databaseService.getCrmProfiles(),
                  builder: (context, snapshot) {
                    final profiles = snapshot.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: selectedLeaderId, hint: const Text('Выберите лидера'),
                      items: profiles.map((p) => DropdownMenuItem(value: p['id'] as String, child: Text(p['full_name'] ?? ''))).toList(),
                      onChanged: (v) => setDialogState(() => selectedLeaderId = v));
                  }),
                const SizedBox(height: 16),
                TextFormField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Описание'), maxLines: 3),
                const SizedBox(height: 16),
                TextFormField(controller: recurringScheduleController, decoration: const InputDecoration(labelText: 'Расписание (Дни)')),
                const SizedBox(height: 16),
                TextFormField(controller: recurringTimeController, decoration: const InputDecoration(labelText: 'Время')),
                const SizedBox(height: 16),
                TextFormField(controller: maxParticipantsController, decoration: const InputDecoration(labelText: 'Макс. участ.'), 
                  keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                const SizedBox(height: 16),
                TextFormField(controller: tagsController, decoration: const InputDecoration(labelText: 'Теги (через запятую)')),
                const SizedBox(height: 24),
                isLoading ? const Center(child: CircularProgressIndicator()) : 
                ElevatedButton.icon(onPressed: handleSave, icon: const Icon(Icons.save), label: const Text('Сохранить'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48))),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        );
      },
    );
  }
}