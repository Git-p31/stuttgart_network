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

  // Хранит ID воркшопов, для которых идет загрузка (кнопки Присоединиться/Покинуть)
  final Map<String, bool> _workshopLoadingState = {};

  final double _breakpoint = 600.0; 

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadScreenData();
  }

  Future<Map<String, dynamic>> _loadScreenData() async {
    try {
      final results = await Future.wait<dynamic>([
        _databaseService.getMyProfile(),
        _databaseService.getWorkshops(), // ✅ Используем getWorkshops
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

  /// ✅ Логика "Присоединиться / Покинуть"
  Future<void> _toggleRegistration(String workshopId, bool isMember) async {
    // 1. Показываем индикатор загрузки для этой карточки
    setState(() {
      _workshopLoadingState[workshopId] = true;
    });

    try {
      if (isMember) {
        // --- Логика "Покинуть" ---
        await _databaseService.unregisterFromWorkshop(workshopId);
      } else {
        // --- Логика "Присоединиться" ---
        await _databaseService.registerForWorkshop(workshopId);
      }
      // 2. Обновляем весь список (это самый простой способ)
      _refreshData(); 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // 3. Убираем индикатор загрузки
      setState(() {
        _workshopLoadingState.remove(workshopId);
      });
    }
  }

  /// ✅ Новый Помощник для форматирования Расписания
  String _formatSchedule(String? recurringSchedule, String? recurringTime) {
    if (recurringSchedule == null || recurringTime == null) return 'Расписание не указано';
    return '$recurringSchedule, $recurringTime';
  }


  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Ошибка: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        
        final profile = snapshot.data!['profile'] as Map<String, dynamic>;
        final workshops = snapshot.data!['workshops'] as List<Map<String, dynamic>>;
        _profileData = profile;
        _workshops = workshops;
        final bool isAdmin = profile['role'] == 'admin';

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < _breakpoint;

            return Scaffold(
              body: isMobile
                  ? _buildMobileLayout(workshops)
                  : _buildWebLayout(workshops, isAdmin),
              
              floatingActionButton: (isAdmin && isMobile)
                  ? FloatingActionButton(
                      onPressed: () => _showResponsiveCreateDialog(context, true, event: null), // Передаем isMobile и event
                      child: const Icon(Icons.add),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  /// МАКЕТ ДЛЯ MOBILE (< 600px)
  Widget _buildMobileLayout(List<Map<String, dynamic>> workshops) {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0), 
        itemCount: workshops.length,
        itemBuilder: (context, index) {
          return _buildWorkshopCard(workshops[index]);
        },
      ),
    );
  }

  /// МАКЕТ ДЛЯ WEB (> 600px)
  Widget _buildWebLayout(List<Map<String, dynamic>> workshops, bool isAdmin) {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: GridView.builder(
        padding: const EdgeInsets.all(24.0), 
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 500.0, // Увеличено с 400 до 500
          mainAxisSpacing: 24.0,
          crossAxisSpacing: 24.0,
          childAspectRatio: 0.8, // Уменьшено для более высокой карточки
        ),
        itemCount: isAdmin ? workshops.length + 1 : workshops.length,
        itemBuilder: (context, index) {
          if (isAdmin && index == 0) {
            return _buildCreateCard(context);
          }

          final workshopIndex = isAdmin ? index - 1 : index; 
          return _buildWorkshopCard(workshops[workshopIndex]);
        },
      ),
    );
  }

  /// Карточка "Создать" (только для Web)
  Widget _buildCreateCard(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showResponsiveCreateDialog(context, false, event: null), // Передаем isMobile как false
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

  /// ✅ Виджет-карточка Воркшопа (ОБНОВЛЕН и ИСПРАВЛЕН)
  Widget _buildWorkshopCard(Map<String, dynamic> workshop) {
    final theme = Theme.of(context);

    // Извлекаем данные
    final String id = workshop['id'];
    final String title = workshop['title'] ?? 'Без названия';
    final String description = workshop['description'] ?? 'Нет описания.';
    final String? imageUrl = workshop['image_url'];
    final int maxParticipants = workshop['max_participants'] ?? 50;
    
    // ✅ ИСПРАВЛЕНО: Загружаем Лидера
    final String leaderName = workshop['leader']?['full_name'] ?? 'Не назначен';
    
    // ✅ ИСПРАВЛЕНО: Загружаем Расписание
    final String scheduleStr = _formatSchedule(workshop['recurring_schedule'], workshop['recurring_time']);
    
    // ✅ ИСПРАВЛЕНО: Загружаем Теги
    final List<String> tags = (workshop['tags'] as List?)?.cast<String>() ?? [];
    
    // Участники
    final List members = (workshop['workshop_members'] as List?) ?? [];
    final int memberCount = members.length;
    final bool isMember = members.any((m) => m['user_id'] == _currentUserId);
    final bool isFull = memberCount >= maxParticipants;

    // Статус загрузки
    final bool isLoading = _workshopLoadingState[id] ?? false;
    

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0), // Отступ для ListView
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Фото ---
          if (imageUrl != null)
            Image.network(
              imageUrl,
              height: 220, // Увеличено
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(theme),
            )
          else
            _buildImagePlaceholder(theme, height: 220), // Увеличено
          
          // --- Основной контент (исправлено для предотвращения переполнения) ---
          // Убран Expanded и SingleChildScrollView, чтобы всё корректно отображалось на мобиле
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- ✅ Теги (теперь отображаются) ---
                if (tags.isNotEmpty)
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 4.0,
                    children: tags.map((tag) => Chip(
                      label: Text(tag, style: const TextStyle(fontSize: 12)),
                      // ignore: deprecated_member_use
                      backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                      labelStyle: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )).toList(),
                  ),
                if (tags.isNotEmpty) const SizedBox(height: 12),

                // --- Заголовок ---
                Text(
                  title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // --- ✅ Лидер ---
                Row(
                  children: [
                    Icon(Icons.mic_external_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(leaderName, style: theme.textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 4),
                
                // --- ✅ Расписание ---
                Row(
                  children: [
                    Icon(Icons.access_time_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Flexible(child: Text(scheduleStr, style: theme.textTheme.bodyMedium)), // Flexible для переноса
                  ],
                ),
                const SizedBox(height: 8),
                
                // --- Описание ---
                Text(
                  description,
                  maxLines: 4, // Увеличено до 4 строк
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          
          // --- Футер (Подвал) карточки ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // --- Количество участников ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Участники:', 
                      style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey)
                    ),
                    Text(
                      '$memberCount / $maxParticipants',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isFull ? theme.colorScheme.error : theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                // --- Кнопки ---
                Row(
                  mainAxisSize: MainAxisSize.min, // Чтобы кнопки занимали минимум места
                  children: [
                    // Кнопка "Подробнее"
                    ElevatedButton(
                      onPressed: () {
                        // ✅ Переход на WorkshopDetailScreen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkshopDetailScreen(
                              workshop: workshop,
                              currentUserId: _currentUserId,
                              isAdmin: _profileData?['role'] == 'admin',
                            ),
                          ),
                        ).then((value) {
                          if (value == true) _refreshData(); // если удалили — обновить
                        });
                      },
                      child: const Text('Подробнее'),
                    ),
                    const SizedBox(width: 8), // Отступ между кнопками
                    // --- ✅ Кнопка "Присоединиться/Покинуть" (теперь видна) ---
                    if (isLoading)
                      const CircularProgressIndicator()
                    else
                      _buildJoinButton(isMember, isFull, id)
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Заглушка для фото
  Widget _buildImagePlaceholder(ThemeData theme, {double height = 180}) {
    return Container(
      height: height,
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.school, // Иконка воркшопа
          size: 60,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// ✅ Логика кнопки "Присоединиться" (ОБНОВЛЕНА)
  Widget _buildJoinButton(bool isMember, bool isFull, String workshopId) {
    // Если Админ, он видит кнопку "Редактировать"
    if (_profileData?['role'] == 'admin') {
      return ElevatedButton.icon(
        onPressed: () => _showResponsiveCreateDialog(context, 
          false, // isMobile всегда false для редактирования (AlertDialog)
          event: _workshops.firstWhere((w) => w['id'] == workshopId) // передаем воркшоп для редактирования
        ),
        icon: const Icon(Icons.edit, size: 18),
        label: const Text('Ред-ть'),
      );
    }
    
    // Если обычный юзер и он УЖЕ УЧАСТНИК
    if (isMember) {
      return ElevatedButton.icon(
        onPressed: () => _toggleRegistration(workshopId, true),
        icon: const Icon(Icons.remove_circle_outline, size: 18),
        label: const Text('Покинуть'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
        ),
      );
    }

    // Если мест нет
    if (isFull) {
      return ElevatedButton.icon(
        onPressed: null, // Отключена
        icon: const Icon(Icons.block, size: 18),
        label: const Text('Мест нет'),
      );
    }

    // Если юзер не участник и места есть
    return ElevatedButton.icon(
      onPressed: () => _toggleRegistration(workshopId, false),
      icon: const Icon(Icons.add_circle_outline, size: 18),
      label: const Text('Присоединиться'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[800], // Ярко-зеленая
        foregroundColor: Colors.white,
      ),
    );
  }


  /// ✅ Адаптивный диалог (исправленная сигнатура)
  void _showResponsiveCreateDialog(BuildContext context, bool isMobile, {Map<String, dynamic>? event}) { // Исправлена сигнатура
    // Для Web всегда показываем широкий диалог
    final bool useMobileDialog = isMobile;

    final Widget dialogContent = _buildCreateDialogContent(event: event);

    if (useMobileDialog) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true, 
        builder: (ctx) => dialogContent,
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            content: SizedBox(
              width: 600, // Увеличена ширина
              child: dialogContent,
            ),
            contentPadding: EdgeInsets.zero, 
          );
        },
      );
    }
  }

  /// ✅ UI диалога (ОБНОВЛЕН)
  Widget _buildCreateDialogContent({Map<String, dynamic>? event}) {
    final bool isEditMode = event != null;
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();

    // --- Заполняем поля, если это редактирование ---
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
        
        Future<void> pickImage() async {
           final picker = ImagePicker();
            try {
              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
              if (image != null) setDialogState(() => pickedImage = image);
            } catch (e) {
              debugPrint('Ошибка выбора фото: $e');
            }
        }

        Future<void> handleSave() async {
           if (!formKey.currentState!.validate()) return;

            setDialogState(() => isLoading = true);
            try {
              String? imageUrl = existingImageUrl;

              // 1. Загружаем фото
              if (pickedImage != null) {
                final extension = pickedImage!.name.split('.').lastOrNull ?? 'jpg';
                final fileName = '${uuid.v4()}.$extension';
                final imageBytes = await pickedImage!.readAsBytes();
                
                await supabase.storage
                    .from('workshop_imegas') // ✅ точное имя бакета
                    .uploadBinary(fileName, imageBytes,
                        fileOptions: FileOptions(contentType: pickedImage!.mimeType));

                imageUrl = supabase.storage
                    .from('workshop_imegas') // ✅ точное имя бакета
                    .getPublicUrl(fileName);

                
                
              }
              
              // 2. Готовим данные
              final tagsList = tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
              final maxP = int.tryParse(maxParticipantsController.text) ?? 50;

              final workshopData = {
                'title': titleController.text,
                'description': descriptionController.text,
                'leader_id': selectedLeaderId, // ✅ ИСПРАВЛЕНО
                'max_participants': maxP,
                'tags': tagsList,
                'image_url': imageUrl,
                'recurring_schedule': recurringScheduleController.text, // ✅ Новое поле
                'recurring_time': recurringTimeController.text,         // ✅ Новое поле
              };

              // 3. Обновляем или Вставляем
              if (isEditMode) {
                await supabase.from('workshops').update(workshopData).eq('id', event['id']);
              } else {
                await supabase.from('workshops').insert(workshopData);
              }

              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _refreshData(); 
            } catch (e) {
              debugPrint('Ошибка сохранения воркшопа: $e');
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
                );
              }
            } finally {
              setDialogState(() => isLoading = false);
            }
        }

        // --- UI Диалога ---
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
            top: 24, left: 24, right: 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isEditMode ? 'Редактировать воркшоп' : 'Новый воркшоп', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Название'),
                    validator: (val) => val == null || val.isEmpty ? 'Введите название' : null,
                  ),
                  const SizedBox(height: 16),
                  
                  // ✅ ИСПРАВЛЕНО: Выбор Лидера
                  Text('Лидер воркшопа', style: theme.textTheme.labelMedium),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _databaseService.getCrmProfiles(), // Загружаем всех юзеров
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ));
                      }
                      final profiles = snapshot.data ?? [];
                      return DropdownButtonFormField<String>(
                        initialValue: selectedLeaderId,
                        hint: const Text('Выберите лидера'),
                        items: profiles.map((profile) {
                          return DropdownMenuItem(
                            value: profile['id'] as String,
                            child: Text(profile['full_name'] ?? 'Без имени'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedLeaderId = value);
                        },
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Описание'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  // --- Расписание ---
                  TextFormField(
                    controller: recurringScheduleController,
                    decoration: const InputDecoration(labelText: 'Расписание (например: Каждую неделю по четвергам)'),
                    validator: (val) => val == null || val.isEmpty ? 'Введите расписание' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: recurringTimeController,
                    decoration: const InputDecoration(labelText: 'Время (например: 18:00 - 20:00)'),
                    validator: (val) => val == null || val.isEmpty ? 'Введите время' : null,
                  ),
                  
                  // --- Дата и Кол-во ---
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: maxParticipantsController,
                          decoration: const InputDecoration(labelText: 'Макс. участ.'),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: tagsController,
                    decoration: const InputDecoration(labelText: 'Теги (через запятую)', hintText: "дети, музыка, ..."),
                  ),
                  const SizedBox(height: 24),

                  // --- Выбор фото ---
                  Text('Фотография воркшопа', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: pickImage,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                      child: (pickedImage == null && existingImageUrl == null)
                          ? const Center(child: Icon(Icons.add_a_photo_outlined))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: pickedImage != null
                                  ? (kIsWeb ? Image.network(pickedImage!.path, fit: BoxFit.cover) : Image.file(File(pickedImage!.path), fit: BoxFit.cover))
                                  : Image.network(existingImageUrl!, fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: handleSave,
                          icon: const Icon(Icons.save),
                          label: const Text('Сохранить'),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                        ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}