import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stuttgart_network/services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

final supabase = Supabase.instance.client;

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isAdmin = false;

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

  Future<Map<String, dynamic>> _loadScreenData(DateTime month) async {
    try {
      final results = await Future.wait<dynamic>([
        _databaseService.getMyProfile(),
        _databaseService.getEventsForMonth(month),
      ]);

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

  void _cacheEvents(DateTime month, List<Map<String, dynamic>> events) {
    final monthKey = DateTime(month.year, month.month);
    _eventsCache[monthKey] = events;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _updateSelectedEvents(selectedDay);
    });
  }

  // Генерация дат для повторяющихся событий
  List<DateTime> _generateRecurringDates({
    required String recurrenceRule,
    required DateTime startDate,
    required DateTime monthStart,
    required DateTime monthEnd,
  }) {
    final List<DateTime> dates = [];

    if (recurrenceRule == 'daily') {
      var current = DateTime(monthStart.year, monthStart.month, 1);
      while (current.isBefore(monthEnd)) {
        if (current.isAfter(startDate.subtract(const Duration(days: 1))) &&
            current.isBefore(monthEnd)) {
          dates.add(current);
        }
        current = current.add(const Duration(days: 1));
      }
    } else if (recurrenceRule.startsWith('weekly_on_')) {
      final dayKey = recurrenceRule.substring(11);
      final weekdayMap = {
        'monday': 1,
        'tuesday': 2,
        'wednesday': 3,
        'thursday': 4,
        'friday': 5,
        'saturday': 6,
        'sunday': 7,
      };

      final targetWeekday = weekdayMap[dayKey] ?? startDate.weekday;

      var current = DateTime(monthStart.year, monthStart.month, 1);
      while (current.weekday != targetWeekday && current.isBefore(monthEnd)) {
        current = current.add(const Duration(days: 1));
      }

      while (current.isBefore(monthEnd)) {
        if (current.isAfter(startDate.subtract(const Duration(days: 1)))) {
          dates.add(current);
        }
        current = current.add(const Duration(days: 7));
      }
    }

    return dates;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final monthKey = DateTime(day.year, day.month);
    final eventsForMonth = _eventsCache[monthKey] ?? [];

    // Прямые события
    final directEvents = eventsForMonth.where((event) {
      final eventDate = DateTime.parse(event['starts_at']);
      return isSameDay(eventDate, day);
    }).toList();

    // Повторяющиеся события
    final recurringEvents = eventsForMonth.where((event) {
      return event['is_recurring'] == true && event['recurrence_rule'] != null;
    }).map((event) {
      final startsAt = DateTime.parse(event['starts_at']);
      final monthStart = DateTime(day.year, day.month, 1);
      final monthEnd = DateTime(day.year, day.month + 1, 1);

      final recurringDates = _generateRecurringDates(
        recurrenceRule: event['recurrence_rule'],
        startDate: startsAt,
        monthStart: monthStart,
        monthEnd: monthEnd,
      );

      if (recurringDates.any((date) => isSameDay(date, day))) {
        final eventCopy = Map<String, dynamic>.from(event);
        final newStartsAt = DateTime(
          day.year,
          day.month,
          day.day,
          startsAt.hour,
          startsAt.minute,
        );
        eventCopy['starts_at'] = newStartsAt.toIso8601String();
        if (event['ends_at'] != null) {
          final endsAt = DateTime.parse(event['ends_at']);
          final newEndsAt = DateTime(
            day.year,
            day.month,
            day.day,
            endsAt.hour,
            endsAt.minute,
          );
          eventCopy['ends_at'] = newEndsAt.toIso8601String();
        }
        return eventCopy;
      }
      return null;
    }).whereType<Map<String, dynamic>>().toList();

    return [...directEvents, ...recurringEvents];
  }

  void _updateSelectedEvents(DateTime day) {
    _selectedEvents = _getEventsForDay(day);
  }

  void _refreshData() {
    setState(() {
      _eventsCache.clear();
      _dataFuture = _loadScreenData(_focusedDay);
    });
  }

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

    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Ошибка: ${snapshot.error}',
                  style: TextStyle(color: theme.colorScheme.error)));
        }

        final fab = _isAdmin
            ? FloatingActionButton(
                onPressed: () =>
                    _showCreateEditDialog(context, preselectedDate: _selectedDay),
                child: const Icon(Icons.add),
              )
            : null;

        return Scaffold(
          floatingActionButton: fab,
          body: Column(
            children: [
              _buildTableCalendar(theme),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Text(
                      DateFormat.yMMMMEEEEd('ru_RU').format(_selectedDay!),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
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
          color: theme.colorScheme.primary.withAlpha(77), // замена withOpacity
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: theme.colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

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
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _selectedEvents.length,
      itemBuilder: (context, index) {
        final event = _selectedEvents[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          clipBehavior: Clip.hardEdge,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _formatEventTime(event['starts_at'], event['ends_at']),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (event['is_recurring'] == true) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.repeat, size: 16, color: theme.colorScheme.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  event['title'] ?? 'Без названия',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (event['location'] != null && event['location'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event['location'],
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(event['description'] ?? 'Нет описания.',
                    style: theme.textTheme.bodyMedium),
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
          ),
        );
      },
    );
  }

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

    bool isRecurring = event?['is_recurring'] == true;
    String recurrenceRule = event?['recurrence_rule'] ?? 'weekly_on_monday';

    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (dialogContext, setDialogState) {
          Future<void> pickTime(bool isStart) async {
            final initialTime = (isStart ? pickedStartTime : pickedEndTime) ?? TimeOfDay.now();
            final time = await showTimePicker(context: dialogContext, initialTime: initialTime);
            if (time != null) {
              setDialogState(() {
                if (isStart) {
                  pickedStartTime = time;
                } else {
                  pickedEndTime = time;
                }
              });
            }
          }

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

              final eventData = {
                'title': titleController.text.trim(),
                'description': descriptionController.text.trim(),
                'location': locationController.text.trim(),
                'starts_at': startsAt.toIso8601String(),
                'ends_at': endsAt?.toIso8601String(),
                'created_by': user.id,
                'is_recurring': isRecurring,
                'recurrence_rule': isRecurring ? recurrenceRule : null,
              };

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

          final weekdays = {
            'monday': 'Понедельник',
            'tuesday': 'Вторник',
            'wednesday': 'Среда',
            'thursday': 'Четверг',
            'friday': 'Пятница',
            'saturday': 'Суббота',
            'sunday': 'Воскресенье',
          };

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 20,
              bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withAlpha(77),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEditMode ? 'Редактировать событие' : 'Новое событие',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'на ${DateFormat.yMMMMEEEEd('ru_RU').format(pickedDate)}',
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Название *',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Введите название' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: locationController,
                      decoration: InputDecoration(
                        labelText: 'Место',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Описание',
                        labelStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTimeButton(
                            label: 'Начало *',
                            time: pickedStartTime,
                            onTap: () => pickTime(true),
                            theme: theme,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimeButton(
                            label: 'Конец',
                            time: pickedEndTime,
                            onTap: () => pickTime(false),
                            theme: theme,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Checkbox(
                          value: isRecurring,
                          onChanged: (value) {
                            setDialogState(() {
                              isRecurring = value ?? false;
                            });
                          },
                          activeColor: theme.colorScheme.primary,
                        ),
                        const Text('Повторяющееся событие', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    if (isRecurring) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: recurrenceRule,
                            items: [
                              const DropdownMenuItem(value: 'daily', child: Text('Ежедневно')),
                              ...weekdays.keys.map((key) {
                                return DropdownMenuItem(
                                  value: 'weekly_on_$key',
                                  child: Text('Каждый ${weekdays[key]!}'),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() {
                                  recurrenceRule = value;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            style: theme.textTheme.bodyLarge,
                            dropdownColor: theme.cardColor,
                            icon: Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Событие будет отображаться во все соответствующие даты в календаре.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                    ],

                    const SizedBox(height: 24),
                    isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: handleSave,
                              icon: const Icon(Icons.save, size: 18),
                              label: Text(isEditMode ? 'Сохранить' : 'Создать'),
                              style: FilledButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildTimeButton({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.grey),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            time?.format(context) ?? '—',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: time != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}