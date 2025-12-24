import 'package:flutter/material.dart';
import 'package:stuttgart_network/services/database_service.dart';
import 'package:stuttgart_network/home/board_screen.dart'; // Импортируем экран доски
import 'package:supabase_flutter/supabase_flutter.dart';

class MinistryDetailScreen extends StatefulWidget {
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
  Map<String, dynamic>? _myProfile;

  @override
  void initState() {
    super.initState();
    _members = List<Map<String, dynamic>>.from(widget.ministry['ministry_members'] ?? []);
    _checkMembership();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _databaseService.getMyProfile();
      if (mounted) setState(() => _myProfile = profile);
    } catch (e) {
      debugPrint('Ошибка загрузки профиля: $e');
    }
  }

  void _checkMembership() {
    setState(() {
      _isMember = _members.any((member) => member['user_id'] == _currentUserId);
    });
  }

  Future<void> _toggleMembership() async {
    setState(() => _isLoading = true);
    final ministryId = widget.ministry['id'];

    try {
      if (_isMember) {
        await _databaseService.leaveMinistry(ministryId);
        _members.removeWhere((m) => m['user_id'] == _currentUserId);
      } else {
        await _databaseService.joinMinistry(ministryId);
        _members.add({
          'user_id': _currentUserId, 
          'role_in_ministry': 'member', 
          'profiles': {'full_name': _myProfile?['full_name'] ?? 'Вы'}
        });
      }
      _checkMembership();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = widget.ministry['image_url'];
    final name = widget.ministry['name'] ?? 'Без названия';
    
    final leaderMap = _members.firstWhere(
      (m) => m['role_in_ministry'] == 'leader',
      orElse: () => {'user_id': '', 'profiles': {'full_name': 'Не назначен'}},
    );
    
    final bool isAdmin = _myProfile?['role'] == 'admin';
    final bool isLeader = leaderMap['user_id'] == _currentUserId;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(name, style: const TextStyle(shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
              background: imageUrl != null ? Image.network(imageUrl, fit: BoxFit.cover) : Container(color: theme.colorScheme.primary),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton.icon(
                        onPressed: _toggleMembership,
                        icon: Icon(_isMember ? Icons.remove_circle_outline : Icons.add_circle_outline),
                        label: Text(_isMember ? 'Покинуть служение' : 'Присоединиться'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor: _isMember ? theme.colorScheme.errorContainer : null,
                        ),
                      ),
                    
                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => BoardScreen(
                            ministryId: widget.ministry['id'],
                            canEdit: isAdmin || isLeader,
                          ),
                        ));
                      },
                      icon: const Icon(Icons.dashboard_customize_outlined),
                      label: const Text('Доска задач'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    ),

                    const SizedBox(height: 24),
                    Text('О служении', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(widget.ministry['description'] ?? 'Нет описания.'),
                    const Divider(height: 40),
                    
                    // --- СПИСОК УЧАСТНИКОВ ---
                    Text('Участники (${_members.length})', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (_members.isEmpty)
                      const Text('В этом служении пока нет участников.')
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          final profile = member['profiles'];
                          final bool isThisLeader = member['role_in_ministry'] == 'leader';
                          final String memberName = profile?['full_name'] ?? 'Участник';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: isThisLeader ? theme.colorScheme.primaryContainer : null,
                              child: Icon(isThisLeader ? Icons.star : Icons.person, size: 20),
                            ),
                            title: Text(memberName),
                            subtitle: Text(isThisLeader ? 'Лидер' : 'Участник'),
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