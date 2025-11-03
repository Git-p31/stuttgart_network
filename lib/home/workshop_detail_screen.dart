// lib/screens/workshop_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:stuttgart_network/services/database_service.dart';

class WorkshopDetailScreen extends StatefulWidget {
  final Map<String, dynamic> workshop;
  final String currentUserId;
  final bool isAdmin;

  const WorkshopDetailScreen({
    super.key,
    required this.workshop,
    required this.currentUserId,
    required this.isAdmin,
  });

  @override
  State<WorkshopDetailScreen> createState() => _WorkshopDetailScreenState();
}

class _WorkshopDetailScreenState extends State<WorkshopDetailScreen> {
  final DatabaseService _databaseService = DatabaseService();
  late List<Map<String, dynamic>> _members;
  late bool _isMember;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _members = List<Map<String, dynamic>>.from(widget.workshop['workshop_members'] ?? []);
    _isMember = _members.any((m) => m['user_id'] == widget.currentUserId);
  }

  Future<void> _toggleRegistration() async {
    setState(() => _isLoading = true);
    final workshopId = widget.workshop['id'];

    try {
      if (_isMember) {
        await _databaseService.unregisterFromWorkshop(workshopId);
        _members.removeWhere((m) => m['user_id'] == widget.currentUserId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Вы покинули воркшоп'), backgroundColor: Colors.green),
          );
        }
      } else {
        await _databaseService.registerForWorkshop(workshopId);
        _members.add({
          'user_id': widget.currentUserId,
          'profiles': null, // пока без профиля — обновится при полной перезагрузке
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Вы присоединились к воркшопу!'), backgroundColor: Colors.green),
          );
        }
      }
      _isMember = _members.any((m) => m['user_id'] == widget.currentUserId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

Future<void> _deleteWorkshop() async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Удалить воркшоп?'),
      content: const Text('Это действие нельзя отменить. Все участники потеряют доступ.'),
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
      // ⚠️ Сначала удаляем связи из workshop_members
      await supabase.from('workshop_members').delete().eq('workshop_id', widget.workshop['id']);

      // ⚠️ Затем удаляем сам воркшоп
      await supabase.from('workshops').delete().eq('id', widget.workshop['id']).select().single();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Воркшоп успешно удалён'), backgroundColor: Colors.green),
        );
        // ✅ Отправляем сигнал родителю (WorkshopsScreen) обновиться
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = widget.workshop['image_url'];
    final title = widget.workshop['title'] ?? 'Без названия';
    final description = widget.workshop['description'] ?? 'Нет описания.';
    final maxParticipants = widget.workshop['max_participants'] ?? 50;
    final isFull = _members.length >= maxParticipants;

    // Лидер: ищем по `leader_id` или по профилю с ролью (если структура такая)
    final leaderProfile = widget.workshop['leader'];
    final leaderName = leaderProfile?['full_name'] ?? 'Не назначен';

    // Расписание
    final schedule = widget.workshop['recurring_schedule'] ?? '—';
    final time = widget.workshop['recurring_time'] ?? '—';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // --- SliverAppBar с изображением ---
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(title, style: const TextStyle(shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16),
              background: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.image_not_supported)),
                      frameBuilder: (context, child, frame, wasSyncLoaded) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.5, 1.0],
                              // ignore: deprecated_member_use
                              colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                            ),
                          ),
                          child: child,
                        );
                      },
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Center(child: Icon(Icons.school, size: 100, color: theme.colorScheme.primary)),
                    ),
            ),
          ),

          // --- Основной контент ---
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Кнопки: Присоединиться / Покинуть / Удалить ---
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _toggleRegistration,
                              icon: Icon(_isMember ? Icons.exit_to_app : Icons.add_circle_outline),
                              label: Text(_isMember ? 'Покинуть воркшоп' : 'Присоединиться'),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                backgroundColor: _isMember
                                    ? theme.colorScheme.errorContainer
                                    : (isFull ? Colors.grey : theme.colorScheme.primaryContainer),
                                foregroundColor: _isMember
                                    ? theme.colorScheme.onErrorContainer
                                    : (isFull ? Colors.white70 : theme.colorScheme.onPrimaryContainer),
                              ),
                            ),
                          ),
                          if (widget.isAdmin) ...[
                            const SizedBox(width: 12),
                            IconButton(
                              onPressed: _deleteWorkshop,
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Удалить воркшоп',
                              iconSize: 36,
                            ),
                          ],
                        ],
                      ),

                    const SizedBox(height: 24),

                    // --- Информация ---
                    Text('О воркшопе', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(description, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 24),

                    // --- Лидер ---
                    ListTile(
                      leading: Icon(Icons.mic_external_on_outlined, color: theme.colorScheme.secondary),
                      title: Text(leaderName),
                      subtitle: const Text('Лидер воркшопа'),
                    ),
                    const Divider(),

                    // --- Расписание ---
                    ListTile(
                      leading: const Icon(Icons.access_time_outlined),
                      title: const Text('Расписание'),
                      subtitle: Text('$schedule, $time'),
                    ),
                    const Divider(),

                    // --- Участники ---
                    const SizedBox(height: 16),
                    Text('Участники (${_members.length} / $maxParticipants)', style: theme.textTheme.titleLarge),
                    if (isFull) ...[
                      const SizedBox(height: 4),
                      Text('Места закончились', style: TextStyle(color: theme.colorScheme.error)),
                    ],
                    const SizedBox(height: 8),

                    if (_members.isEmpty)
                      const Text('Пока никто не присоединился.')
                    else
                      Card(
                        margin: EdgeInsets.zero,
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _members.length,
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            final profile = member['user_profile'] ?? member['profiles'];
                            final name = profile?['full_name'] ?? (member['user_id'] == widget.currentUserId ? 'Вы' : 'Загрузка...');
                            final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

                            return ListTile(
                              leading: CircleAvatar(child: Text(initial)),
                              title: Text(name),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}