import 'package:flutter/material.dart';
import 'package:stuttgart_network/services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MinistryDetailScreen extends StatefulWidget {
  // Мы получаем всю карту служения с предыдущего экрана
  final Map<String, dynamic> ministry;

  const MinistryDetailScreen({super.key, required this.ministry});

  @override
  State<MinistryDetailScreen> createState() => _MinistryDetailScreenState();
}

class _MinistryDetailScreenState extends State<MinistryDetailScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;

  late bool _isMember;
  late List<Map<String, dynamic>> _members;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Извлекаем участников из полученной карты
    _members = List<Map<String, dynamic>>.from(widget.ministry['ministry_members'] ?? []);
    // Проверяем, является ли текущий пользователь участником
    _checkMembership();
  }

  void _checkMembership() {
    setState(() {
      _isMember = _members.any((member) => member['user_id'] == _currentUserId);
    });
  }

  /// Логика "Присоединиться" / "Покинуть"
  Future<void> _toggleMembership() async {
    setState(() => _isLoading = true);
    final ministryId = widget.ministry['id'];

    try {
      if (_isMember) {
        // --- Логика "Покинуть" ---
        await _databaseService.leaveMinistry(ministryId);
        // Удаляем себя из локального списка, чтобы UI мгновенно обновился
        _members.removeWhere((m) => m['user_id'] == _currentUserId);
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Вы покинули служение'), backgroundColor: Colors.green),
          );
        }
      } else {
        // --- Логика "Присоединиться" ---
        await _databaseService.joinMinistry(ministryId);
        // Добавляем себя в локальный список
        // ПРИМЕЧАНИЕ: 'profiles' здесь будет null, но для _checkMembership это неважно
        _members.add({'user_id': _currentUserId, 'role_in_ministry': 'member', 'profiles': null});
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Вы присоединились к служению!'), backgroundColor: Colors.green),
          );
        }
      }
      _checkMembership(); // Обновляем состояние кнопки
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = widget.ministry['image_url'];
    final name = widget.ministry['name'] ?? 'Без названия';
    final description = widget.ministry['description'] ?? 'Нет описания.';
    
    // Ищем лидера
    final leaderMap = _members.firstWhere(
      (m) => m['role_in_ministry'] == 'leader',
      orElse: () => {'profiles': {'full_name': 'Не назначен'}},
    );
    final leaderName = leaderMap['profiles']?['full_name'] ?? 'Не назначен';

    return Scaffold(
      // CustomScrollView дает нам эффект "исчезающего" AppBar с картинкой
      body: CustomScrollView(
        slivers: [
          // --- AppBar с картинкой ---
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true, // AppBar остается видимым
            flexibleSpace: FlexibleSpaceBar(
              title: Text(name, style: const TextStyle(shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
              titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 16),
              background: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      // Градиент, чтобы текст AppBar был читаемым
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
                  : Container(color: theme.colorScheme.surfaceContainerHighest, child: Center(child: Icon(Icons.hub, size: 100, color: theme.colorScheme.primary))),
            ),
          ),

          // --- Контент страницы ---
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Кнопка "Присоединиться/Покинуть" ---
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton.icon(
                        onPressed: _toggleMembership,
                        icon: Icon(_isMember ? Icons.remove_circle_outline : Icons.add_circle_outline),
                        label: Text(_isMember ? 'Покинуть служение' : 'Присоединиться'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor: _isMember ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer,
                          foregroundColor: _isMember ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    
                    const SizedBox(height: 24),

                    // --- Описание ---
                    Text('О служении', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(description, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 24),
                    
                    // --- Лидер ---
                    ListTile(
                      leading: Icon(Icons.star_border, color: theme.colorScheme.secondary),
                      title: Text(leaderName),
                      subtitle: const Text('Лидер служения'),
                    ),
                    const Divider(),

                    // --- Список Участников ---
                    const SizedBox(height: 16),
                    Text('Участники (${_members.length})', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    
                    if (_members.isEmpty)
                      const Text('Участников пока нет.')
                    else
                      // Оборачиваем в Card для красоты
                      Card(
                        margin: EdgeInsets.zero,
                        child: ListView.builder(
                          itemCount: _members.length,
                          shrinkWrap: true, // Говорим ListView занять мин. место
                          physics: const NeverScrollableScrollPhysics(), // Отключаем скролл
                          itemBuilder: (context, index) {
                            final member = _members[index];
                            final profile = member['profiles'];
                            // Если мы только что присоединились, 'profiles' еще нет
                            final memberName = profile?['full_name'] ?? (_isMember ? 'Вы' : 'Загрузка...');
                            final initial = memberName.isNotEmpty ? memberName[0].toUpperCase() : '?';

                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(initial),
                              ),
                              title: Text(memberName),
                              subtitle: Text(member['role_in_ministry'] == 'leader' ? 'Лидер' : 'Участник'),
                            );
                          },
                        ),
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