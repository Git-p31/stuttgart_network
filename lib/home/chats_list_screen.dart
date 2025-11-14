import 'package:flutter/material.dart';
import 'package:stuttgart_network/services/database_service.dart';
import 'package:stuttgart_network/home/chat_message_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ НУЖНО ДОБАВИТЬ ЭТОТ ИМПОРТ

// Глобальный клиент, как в database_service.dart
final supabase = Supabase.instance.client;

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final DatabaseService _databaseService = DatabaseService();
  late Future<List<Map<String, dynamic>>> _groupsFuture;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  void _loadGroups() {
    setState(() {
      _groupsFuture = _databaseService.getMyChatGroups();
    });
  }

  Future<void> _refreshGroups() async {
    _loadGroups();
  }

  void _showCreateGroupModal(BuildContext context) {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final List<String> selectedUserIds = [];
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
                top: 20,
                left: 24,
                right: 24,
              ),
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
                      'Новая группа',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Название группы'),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Введите название'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    Text('Выберите участников',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),

                    // --- Список пользователей ---
                    SizedBox(
                      height: 300, // Ограничиваем высоту списка
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _databaseService.getCrmProfiles(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                                child: Text('Ошибка: ${snapshot.error}'));
                          }
                          final profiles = snapshot.data ?? [];

                          // ✅ ИСПРАВЛЕНИЕ ОШИБКИ 'currentUser'
                          final currentUserId = supabase.auth.currentUser?.id;

                          return ListView.builder(
                            itemCount: profiles.length,
                            itemBuilder: (context, index) {
                              final profile = profiles[index];
                              // Не даем выбрать самого себя (создатель
                              // добавляется автоматически)
                              if (profile['id'] == currentUserId) {
                                return const SizedBox.shrink();
                              }

                              return CheckboxListTile(
                                title:
                                    Text(profile['full_name'] ?? 'Без имени'),
                                subtitle: Text(profile['email'] ?? ''),
                                value: selectedUserIds.contains(profile['id']),
                                onChanged: (bool? value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      selectedUserIds.add(profile['id']);
                                    } else {
                                      selectedUserIds.remove(profile['id']);
                                    }
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                    // --- Кнопка ---
                    const SizedBox(height: 24),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isLoading = true);
                          try {
                            await _databaseService.createChatGroup(
                              nameController.text.trim(),
                              selectedUserIds,
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            _refreshGroups(); // Обновляем список чатов
                          } catch (e) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext)
                                  .showSnackBar(
                                SnackBar(
                                    content: Text('Ошибка создания: $e'),
                                    backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            setDialogState(() => isLoading = false);
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Создать группу'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshGroups,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _groupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Ошибка загрузки чатов: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final groups = snapshot.data ?? [];

            if (groups.isEmpty) {
              return const Center(
                child: Text('У вас пока нет чатов. Создайте первый!'),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                final groupName = group['name'] ?? 'Без названия';
                final members = (group['chat_members'] as List?) ?? [];

                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(groupName.isNotEmpty ? groupName[0] : '?'),
                    ),
                    title: Text(groupName,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${members.length} участника(ов)'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatMessageScreen(
                            groupId: group['id'],
                            groupName: groupName,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGroupModal(context),
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }
}