import 'package:flutter/material.dart';
import 'package:stuttgart_network/services/database_service.dart';
import 'package:stuttgart_network/home/board_screen.dart'; // Импортируем экран доски

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
    // Извлекаем список участников
    _members = List<Map<String, dynamic>>.from(widget.workshop['workshop_members'] ?? []);
    _isMember = _members.any((m) => m['user_id'] == widget.currentUserId);
  }

  Future<void> _toggleRegistration() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      if (_isMember) {
        await _databaseService.unregisterFromWorkshop(widget.workshop['id']);
        _members.removeWhere((m) => m['user_id'] == widget.currentUserId);
      } else {
        await _databaseService.registerForWorkshop(widget.workshop['id']);
        // Добавляем себя в локальный список для мгновенного обновления UI
        _members.add({'user_id': widget.currentUserId, 'profiles': null});
      }
      setState(() => _isMember = _members.any((m) => m['user_id'] == widget.currentUserId));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leaderId = widget.workshop['leader_id'] ?? widget.workshop['leader']?['id'];
    
    // ПРОВЕРКА ПРАВ: админ или создатель (лидер) воркшопа
    final bool canEditBoard = widget.isAdmin || leaderId == widget.currentUserId;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.workshop['title'] ?? '', style: const TextStyle(shadows: [Shadow(blurRadius: 8, color: Colors.black)])),
              background: widget.workshop['image_url'] != null 
                ? Image.network(widget.workshop['image_url'], fit: BoxFit.cover)
                : Container(color: theme.colorScheme.secondary),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _toggleRegistration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isMember ? theme.colorScheme.errorContainer : null,
                            ),
                            child: Text(_isMember ? 'Покинуть воркшоп' : 'Записаться'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => BoardScreen(
                            workshopId: widget.workshop['id'],
                            canEdit: canEditBoard,
                          ),
                        ));
                      },
                      icon: const Icon(Icons.assignment_outlined),
                      label: const Text('Доска воркшопа'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    ),

                    const SizedBox(height: 24),
                    Text('Описание', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(widget.workshop['description'] ?? 'Нет описания'),
                    const Divider(height: 32),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(widget.workshop['leader']?['full_name'] ?? 'Не назначен'),
                      subtitle: const Text('Лидер воркшопа'),
                    ),
                    const Divider(height: 32),

                    // --- СПИСОК УЧАСТНИКОВ ---
                    Text('Участники (${_members.length})', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (_members.isEmpty)
                      const Text('Пока никто не записался.')
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          final profile = member['profiles'];
                          final String name = profile?['full_name'] ?? (member['user_id'] == widget.currentUserId ? 'Вы' : 'Участник');
                          
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                            ),
                            title: Text(name),
                          );
                        },
                      ),
                  ],
                ),
              )
            ]),
          ),
        ],
      ),
    );
  }
}