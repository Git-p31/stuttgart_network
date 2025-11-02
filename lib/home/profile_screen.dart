import 'package:flutter/material.dart';
import 'package:stuttgart_network/services/auth_service.dart';
import 'package:stuttgart_network/services/database_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  // Храним будущее (данные профиля)
  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    // Загружаем данные при открытии экрана
    _profileFuture = _databaseService.getMyProfile();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой профиль'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {
          // 1. Состояние загрузки
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Ошибка при загрузке
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка загрузки профиля: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            );
          }

          // 3. Нет данных
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Не удалось найти профиль.'));
          }

          // 4. Данные успешно получены
          final profile = snapshot.data!;
          final fullName = profile['full_name'] ?? 'Без имени';
          final email = profile['email'] ?? 'Нет данных';
          final phone = profile['phone'] ?? 'Нет данных';
          final role = profile['role'] ?? 'user';
          final initial =
              fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

          // --- UI профиля ---
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Аватар
                    CircleAvatar(
                      radius: 50,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.5),
                      child: Text(
                        initial,
                        style: theme.textTheme.headlineLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Имя
                    Text(
                      fullName,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // Роль (чип)
                    Chip(
                      label: Text(
                        role == 'admin' ? 'Администратор' : 'Участник',
                        style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                      backgroundColor: theme.colorScheme.secondaryContainer,
                    ),
                    const SizedBox(height: 32),

                    // Контактная информация
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.email_outlined),
                            title: const Text('Email'),
                            subtitle: Text(email),
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          ListTile(
                            leading: const Icon(Icons.phone_outlined),
                            title: const Text('Телефон'),
                            subtitle: Text(phone),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Кнопка выхода
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Выйти из аккаунта'),
                      onPressed: () {
                        _authService.signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
