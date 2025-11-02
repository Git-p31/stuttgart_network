import 'dart:async';
// import 'dart:io'; // 🛑 УДАЛЕНО
// import 'package:flutter/foundation.dart'; // 🛑 УДАЛЕНО
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:image_picker/image_picker.dart'; // 🛑 УДАЛЕНО
import 'package:stuttgart_network/services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart'; 
// import 'package:uuid/uuid.dart'; // 🛑 УДАЛЕНО

final supabase = Supabase.instance.client;
// const uuid = Uuid(); // 🛑 УДАЛЕНО

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isAdmin = false;
  
  // --- Состояние Календаря ---
  late Future<Map<String, dynamic>> _dataFuture;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  final Map<DateTime, List<Map<String, dynamic>>> _eventsCache = {};
  List<Map<String, dynamic>> _selectedEvents = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _dataFuture = _loadScreenData(_selectedDay!);
  }

  /// Загружает профиль + события за первый месяц
  Future<Map<String, dynamic>> _loadScreenData(DateTime month) async {
    try {
      // Используем List<dynamic> для Future.wait
      final results = await Future.wait<dynamic>([
        _databaseService.getMyProfile(),      // Future<Map<String, dynamic>>
        _databaseService.getEventsForMonth(month), // Future<List<Map<String, dynamic>>>
      ]);

      // Приводим к нужным типам
      final profile = results[0] as Map<String, dynamic>;
      final events = (results[1] as List).cast<Map<String, dynamic>>();

      _isAdmin = profile['role'] == 'admin';
      _cacheEvents(month, events);
      _updateSelectedEvents(_selectedDay!);

      return {'profile': profile, 'events': events};
    } catch (e) {
      throw Exception('Ошибка загрузки данных: $e');
    }
  }

  /// Загружает события за НОВЫЙ месяц (при пролистывании)
  Future<void> _loadEventsForMonth(DateTime month) async {
    final monthKey = DateTime(month.year, month.month);
    if (_eventsCache.containsKey(monthKey)) return; 

    try {
      final events = await _databaseService.getEventsForMonth(month);
      setState(() {
        _cacheEvents(month, events);
      });
    } catch (e) {
      debugPrint("Ошибка загрузки событий для $month: $e");
    }
  }

  /// Обновляет кэш
  void _cacheEvents(DateTime month, List<Map<String, dynamic>> events) {
    final monthKey = DateTime(month.year, month.month);
    _eventsCache[monthKey] = events;
  }

  /// Вызывается, когда пользователь нажимает на день
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _updateSelectedEvents(selectedDay);
    });
  }

  /// Обновляет список _selectedEvents на основе кэша
  void _updateSelectedEvents(DateTime day) {
    final monthKey = DateTime(day.year, day.month);
    final eventsForMonth = _eventsCache[monthKey] ?? [];
    
    _selectedEvents = eventsForMonth.where((event) {
      final eventDate = DateTime.parse(event['starts_at']);
      return isSameDay(eventDate, day);
    }).toList();
  }

  /// Получает список событий для маркеров календаря
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final monthKey = DateTime(day.year, day.month);
    final eventsForMonth = _eventsCache[monthKey] ?? [];
    
    return eventsForMonth.where((event) {
      final eventDate = DateTime.parse(event['starts_at']);
      return isSameDay(eventDate, day);
    }).toList();
  }

  void _refreshData() {
    setState(() {
      _eventsCache.clear();
      _dataFuture = _loadScreenData(_focusedDay);
    });
  }

  /// Помощник для форматирования времени (н-р, "19:00 - 21:30")
  String _formatEventTime(String startsAt, String? endsAt) {
    const ruLocale = 'ru_RU';
    final startTime = DateFormat.Hm(ruLocale).format(DateTime.parse(startsAt));
    if (endsAt == null) {
      return startTime;
    }
    final endTime = DateFormat.Hm(ruLocale).format(DateTime.parse(endsAt));
    return '$startTime - $endTime';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 🛑 ИСПРАВЛЕНО: УБРАН Scaffold и AppBar
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}', style: TextStyle(color: theme.colorScheme.error)));
        }

        // Кнопка "Создать" (теперь плавающая)
        final fab = _isAdmin ? FloatingActionButton(
          onPressed: () => _showCreateEditDialog(context, preselectedDate: _selectedDay),
          child: const Icon(Icons.add),
        ) : null;

        return Scaffold(
          floatingActionButton: fab,
          body: Column(
            children: [
              _buildTableCalendar(theme),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Text(
                      DateFormat.yMMMMEEEEd('ru_RU').format(_selectedDay!),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _refreshData(),
                  child: _buildEventList(theme),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Виджет Календаря
  Widget _buildTableCalendar(ThemeData theme) {
    return TableCalendar(
      locale: 'ru_RU', 
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: CalendarFormat.month, 
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: _onDaySelected,
      onPageChanged: (focusedDay) {
        setState(() => _focusedDay = focusedDay);
        _loadEventsForMonth(focusedDay);
      },
      eventLoader: _getEventsForDay,
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          if (events.isNotEmpty) {
            return Positioned(
              bottom: 5,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }
          return null;
        },
      ),
      headerStyle: const HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
      ),
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          // ignore: deprecated_member_use
          color: theme.colorScheme.primary.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Виджет Списка Событий
  Widget _buildEventList(ThemeData theme) {
    if (_selectedEvents.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const Center(child: Text('На этот день событий нет.')),
            ),
          );
        }
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _selectedEvents.length,
      itemBuilder: (context, index) {
        final event = _selectedEvents[index];
        // final imageUrl = event['image_url']; // 🛑 УДАЛЕНО

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🛑 БЛОК С ФОТО ПОЛНОСТЬЮ УДАЛЕН
              
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatEventTime(event['starts_at'], event['ends_at']),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event['title'] ?? 'Без названия',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (event['location'] != null && event['location'].isNotEmpty) ...[ 
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded( // ✅ Добавлено, чтобы текст переносился
                            child: Text(
                              event['location'],
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(event['description'] ?? 'Нет описания.', style: theme.textTheme.bodyMedium),
                    
                    if (_isAdmin)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                            onPressed: () => _showCreateEditDialog(context, event: event), 
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                            onPressed: () => _showDeleteDialog(event['id']),
                          ),
                        ],
                      )
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  /// Диалог подтверждения удаления (без изменений)
  void _showDeleteDialog(String eventId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить событие?'),
        content: const Text('Это действие нельзя будет отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              try {
                await supabase.from('events').delete().eq('id', eventId);
                if (ctx.mounted) Navigator.pop(ctx);
                _refreshData();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  /// --- Диалог создания/редактирования события (без фото) ---
  void _showCreateEditDialog(BuildContext context, {Map<String, dynamic>? event, DateTime? preselectedDate}) {
    final bool isEditMode = event != null; 
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    
    final titleController = TextEditingController(text: event?['title']);
    final descriptionController = TextEditingController(text: event?['description']);
    final locationController = TextEditingController(text: event?['location']);

    DateTime pickedDate = preselectedDate ?? (event != null ? DateTime.parse(event['starts_at']) : _selectedDay ?? DateTime.now());
    TimeOfDay? pickedStartTime = event != null ? TimeOfDay.fromDateTime(DateTime.parse(event['starts_at'])) : null;
    TimeOfDay? pickedEndTime = event != null && event['ends_at'] != null ? TimeOfDay.fromDateTime(DateTime.parse(event['ends_at'])) : null;
    // 🛑 Логика Фото - УДАЛЕНА
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      builder: (ctx) {
        return StatefulBuilder(builder: (dialogContext, setDialogState) {
          
          Future<void> pickTime(bool isStart) async {
            final initialTime = (isStart ? pickedStartTime : pickedEndTime) ?? TimeOfDay.now();
            final time = await showTimePicker(context: context, initialTime: initialTime);
            if (time == null) return;
            setDialogState(() {
              if (isStart) {
                pickedStartTime = time;
              } else {
                pickedEndTime = time;
              }
            });
          }

          // 🛑 Функция pickImage() - УДАЛЕНА

          Future<void> handleSave() async {
            final user = supabase.auth.currentUser;
            if (user == null) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Ошибка: пользователь не авторизован'), backgroundColor: Colors.red),
              );
              return;
            }

            if (!formKey.currentState!.validate()) return;
            if (pickedStartTime == null) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Выберите время начала'), backgroundColor: Colors.red),
              );
              return;
            }

            setDialogState(() => isLoading = true);
            try {
              // 🛑 Логика Загрузки Фото - УДАЛЕНА
              
              // 2️⃣ Формируем даты
              final startsAt = DateTime(
                pickedDate.year, pickedDate.month, pickedDate.day,
                pickedStartTime!.hour, pickedStartTime!.minute,
              );
              
              DateTime? endsAt;
              if (pickedEndTime != null) {
                 endsAt = DateTime(
                  pickedDate.year, pickedDate.month, pickedDate.day,
                  pickedEndTime!.hour, pickedEndTime!.minute,
                );
              }

              // 3️⃣ Подготавливаем данные
              final eventData = {
                'title': titleController.text,
                'description': descriptionController.text,
                'starts_at': startsAt.toIso8601String(),
                'ends_at': endsAt?.toIso8601String(),
                'created_by': user.id,
              };

              // 4️⃣ Вставка или обновление
              if (isEditMode) {
                await supabase.from('events').update(eventData).eq('id', event['id']);
              } else {
                await supabase.from('events').insert(eventData);
              }

              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _refreshData();
            } catch (e) {
              debugPrint('Ошибка сохранения события: $e');
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
              top: 20, left: 20, right: 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isEditMode ? 'Редактировать событие' : 'Новое событие', style: theme.textTheme.headlineSmall),
                    Text('на ${DateFormat.yMMMMEEEEd('ru_RU').format(pickedDate)}', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 24),
                    
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Название'),
                      validator: (val) => val == null || val.isEmpty ? 'Введите название' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: locationController,
                      decoration: const InputDecoration(labelText: 'Место (напр. "Главный зал")'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Описание'),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),
                    
                    // --- Выбор Времени ---
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => pickTime(true),
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                              child: Center(child: Text(pickedStartTime == null ? 'Время *Начала*' : pickedStartTime!.format(context), style: theme.textTheme.bodyLarge)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => pickTime(false),
                            child: Container(
                              height: 60,
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                              child: Center(child: Text(pickedEndTime == null ? 'Время *Конца*' : pickedEndTime!.format(context), style: theme.textTheme.bodyLarge)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // 🛑 БЛОК ВЫБОРА ФОТО УДАЛЕН
                    
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
        });
      },
    );
  }
}

