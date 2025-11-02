import 'package:flutter/material.dart';
// import 'package:stuttgart_network/services/auth_service.dart'; // <-- Больше не нужен
import 'package:stuttgart_network/services/database_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // final AuthService _authService = AuthService(); // <-- Больше не нужен
  final DatabaseService _databaseService = DatabaseService();

  late Future<Map<String, dynamic>> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _databaseService.getMyProfile();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // ✅ ИСПРАВЛЕНО: Возвращаем Scaffold и AppBar
    return Scaffold(
      // AppBar не нужен, так как он есть в home_screen.dart
      // appBar: AppBar(
      //   title: const Text('Мой Профиль'),
      // ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Ошибка загрузки профиля: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Не удалось найти профиль.'));
          }

          final profile = snapshot.data!;
          final fullName = profile['full_name'] ?? 'Без имени';
          final email = profile['email'] ?? 'Нет данных';
          final phone = profile['phone'] ?? 'Нет данных';
          final role = profile['role'] ?? 'user';
          final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

          // --- UI Профиля ---
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      // ignore: deprecated_member_use
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.5),
                      child: Text(
                        initial,
                        style: theme.textTheme.headlineLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      fullName,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    Chip(
                      label: Text(
                        role == 'admin' ? 'Администратор' : 'Участник',
                        style: TextStyle(color: theme.colorScheme.onSecondaryContainer),
                      ),
                      backgroundColor: theme.colorScheme.secondaryContainer,
                    ),
                    const SizedBox(height: 32),

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

                    // 🛑 Кнопка "Выйти" УДАЛЕНА, так как она в Drawer
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

