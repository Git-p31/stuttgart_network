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

  // --- ИСПРАВЛЕННАЯ ЛОГИКА ФИЛЬТРАЦИИ ---
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final monthKey = DateTime(day.year, day.month);
    final eventsForMonth = _eventsCache[monthKey] ?? [];

    // 1. Прямые события: ИСКЛЮЧАЕМ повторяющиеся, чтобы не было дублей
    final directEvents = eventsForMonth.where((event) {
      final eventDate = DateTime.parse(event['starts_at']);
      return isSameDay(eventDate, day) && event['is_recurring'] != true;
    }).toList();

    // 2. Повторяющиеся события: Генерируем вхождения
    final recurringEvents = eventsForMonth.where((event) {
      return event['is_recurring'] == true && event['recurrence_rule'] != null;
    }).map((event) {
      final startsAt = DateTime.parse(event['starts_at']);
      final monthStart = DateTime(day.year, day.month, 1);
      final monthEnd = DateTime(day.year, day.month + 1, 1).subtract(const Duration(seconds: 1));

      final recurringDates = _generateRecurringDates(
        recurrenceRule: event['recurrence_rule'],
        startDate: startsAt,
        monthStart: monthStart,
        monthEnd: monthEnd,
      );

      if (recurringDates.any((date) => isSameDay(date, day))) {
        final eventCopy = Map<String, dynamic>.from(event);
        final newStartsAt = DateTime(day.year, day.month, day.day, startsAt.hour, startsAt.minute);
        eventCopy['starts_at'] = newStartsAt.toIso8601String();
        
        if (event['ends_at'] != null) {
          final endsAt = DateTime.parse(event['ends_at']);
          final newEndsAt = DateTime(day.year, day.month, day.day, endsAt.hour, endsAt.minute);
          eventCopy['ends_at'] = newEndsAt.toIso8601String();
        }
        return eventCopy;
      }
      return null;
    }).whereType<Map<String, dynamic>>().toList();

    return [...directEvents, ...recurringEvents];
  }

  // --- ИСПРАВЛЕННАЯ ЛОГИКА ГЕНЕРАЦИИ (СУББОТЫ И Т.Д.) ---
  List<DateTime> _generateRecurringDates({
    required String recurrenceRule,
    required DateTime startDate,
    required DateTime monthStart,
    required DateTime monthEnd,
  }) {
    final List<DateTime> dates = [];
    
    // Начинаем проверку либо с начала месяца, либо с даты старта события (что позже)
    DateTime current = monthStart.isBefore(startDate) 
        ? DateTime(startDate.year, startDate.month, startDate.day) 
        : monthStart;

    if (recurrenceRule == 'daily') {
      while (current.isBefore(monthEnd) || isSameDay(current, monthEnd)) {
        dates.add(current);
        current = current.add(const Duration(days: 1));
      }
    } else if (recurrenceRule.startsWith('weekly_on_')) {
      final dayKey = recurrenceRule.substring(11);
      final weekdayMap = {
        'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
        'friday': 5, 'saturday': 6, 'sunday': 7,
      };
      final targetWeekday = weekdayMap[dayKey] ?? startDate.weekday;

      // Ищем первый нужный день недели
      while (current.weekday != targetWeekday && current.isBefore(monthEnd)) {
        current = current.add(const Duration(days: 1));
      }

      // Добавляем все вхождения до конца текущего месяца
      while (current.isBefore(monthEnd) || isSameDay(current, monthEnd)) {
        dates.add(current);
        current = current.add(const Duration(days: 7));
      }
    }
    return dates;
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
    if (endsAt == null) return startTime;
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
          return Center(child: Text('Ошибка: ${snapshot.error}', style: TextStyle(color: theme.colorScheme.error)));
        }

        return Scaffold(
          floatingActionButton: _isAdmin
              ? FloatingActionButton(
                  onPressed: () => _showCreateEditDialog(context, preselectedDate: _selectedDay),
                  child: const Icon(Icons.add),
                )
              : null,
          body: Column(
            children: [
              _buildTableCalendar(theme),
              const SizedBox(height: 8),
              _buildSectionHeader(theme),
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

  Widget _buildSectionHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4, height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            DateFormat.yMMMMEEEEd('ru_RU').format(_selectedDay!),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCalendar(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.dividerColor.withAlpha(40)),
      ),
      child: TableCalendar(
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
                bottom: 6,
                child: Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                ),
              );
            }
            return null;
          },
        ),
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(color: theme.colorScheme.primary.withAlpha(50), shape: BoxShape.circle),
          selectedDecoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
          weekendTextStyle: TextStyle(color: theme.colorScheme.error),
        ),
      ),
    );
  }

  Widget _buildEventList(ThemeData theme) {
    if (_selectedEvents.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.1),
          Opacity(
            opacity: 0.5,
            child: Column(
              children: [
                Icon(Icons.event_busy, size: 64, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                const Text('На этот день событий нет.'),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _selectedEvents.length,
      itemBuilder: (context, index) {
        final event = _selectedEvents[index];
        return _buildEventCard(theme, event);
      },
    );
  }

  Widget _buildEventCard(ThemeData theme, Map<String, dynamic> event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withAlpha(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatEventTime(event['starts_at'], event['ends_at']),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (event['is_recurring'] == true)
                  Icon(Icons.autorenew_rounded, size: 20, color: theme.colorScheme.primary),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              event['title'] ?? 'Без названия',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            if (event['location'] != null && event['location'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.place_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event['location'],
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              event['description'] ?? 'Нет описания.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withAlpha(180)),
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showCreateEditDialog(context, event: event),
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: const Text('Правка'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showDeleteDialog(event['id']),
                    icon: Icon(Icons.delete_sweep_rounded, size: 20, color: theme.colorScheme.error),
                    label: Text('Удалить', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
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
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
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
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) {
        return StatefulBuilder(builder: (dialogContext, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(left: 24, right: 24, top: 12, bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.dividerColor, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 24),
                    Text(isEditMode ? 'Редактировать' : 'Новое событие', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    _buildField(titleController, 'Название *', Icons.title_rounded, (v) => v!.isEmpty ? 'Введите название' : null),
                    const SizedBox(height: 16),
                    _buildField(locationController, 'Где пройдет?', Icons.place_rounded, null),
                    const SizedBox(height: 16),
                    _buildField(descriptionController, 'Описание', Icons.description_rounded, null, maxLines: 3),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _buildTimePicker(dialogContext, 'Начало', pickedStartTime, (t) => setDialogState(() => pickedStartTime = t))),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTimePicker(dialogContext, 'Конец', pickedEndTime, (t) => setDialogState(() => pickedEndTime = t))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Повторять событие'),
                      subtitle: const Text('Автоматически в календаре'),
                      value: isRecurring,
                      onChanged: (v) => setDialogState(() => isRecurring = v),
                    ),
                    if (isRecurring) _buildRecurrenceDropdown(theme, recurrenceRule, (v) => setDialogState(() => recurrenceRule = v!)),
                    const SizedBox(height: 32),
                    isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () async {
                                if (!formKey.currentState!.validate() || pickedStartTime == null) return;
                                setDialogState(() => isLoading = true);
                                try {
                                  final startsAt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedStartTime!.hour, pickedStartTime!.minute);
                                  DateTime? endsAt = pickedEndTime != null ? DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedEndTime!.hour, pickedEndTime!.minute) : null;
                                  final data = {
                                    'title': titleController.text.trim(),
                                    'description': descriptionController.text.trim(),
                                    'location': locationController.text.trim(),
                                    'starts_at': startsAt.toIso8601String(),
                                    'ends_at': endsAt?.toIso8601String(),
                                    'is_recurring': isRecurring,
                                    'recurrence_rule': isRecurring ? recurrenceRule : null,
                                    'created_by': supabase.auth.currentUser!.id,
                                  };
                                  if (isEditMode) await supabase.from('events').update(data).eq('id', event['id']);
                                  else await supabase.from('events').insert(data);
                                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                                  _refreshData();
                                } catch (e) {
                                  if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                                } finally {
                                  setDialogState(() => isLoading = false);
                                }
                              },
                              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              child: Text(isEditMode ? 'Сохранить изменения' : 'Создать событие'),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, String? Function(String?)? validator, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 20),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        filled: true,
      ),
    );
  }

  Widget _buildTimePicker(BuildContext context, String label, TimeOfDay? time, Function(TimeOfDay) onPick) {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now());
        if (t != null) onPick(t);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(time?.format(context) ?? '--:--', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurrenceDropdown(ThemeData theme, String value, Function(String?) onChanged) {
    final weekdays = {'monday': 'Пн', 'tuesday': 'Вт', 'wednesday': 'Ср', 'thursday': 'Чт', 'friday': 'Пт', 'saturday': 'Сб', 'sunday': 'Вс'};
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest.withAlpha(100), borderRadius: BorderRadius.circular(16)),
      child: DropdownButton<String>(
        isExpanded: true,
        underline: const SizedBox(),
        value: value,
        items: [
          const DropdownMenuItem(value: 'daily', child: Text('Каждый день')),
          ...weekdays.entries.map((e) => DropdownMenuItem(value: 'weekly_on_${e.key}', child: Text('Раз в неделю (${e.value})'))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}