// lib/home/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:stuttgart_network/services/database_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _databaseService = DatabaseService();

  late Future<Map<String, dynamic>> _profileFuture;
  late Future<List<Map<String, dynamic>>> _workshopsFuture;
  late Future<List<Map<String, dynamic>>> _ministriesFuture;
  late Future<List<Map<String, dynamic>>> _marketplaceFuture;

  @override
  void initState() {
    super.initState();

    _profileFuture = _databaseService.getMyProfile();
    _workshopsFuture = _databaseService.getMyWorkshops();
    _ministriesFuture = _databaseService.getMyMinistries();
    _marketplaceFuture = _databaseService.getMyMarketplaceItems();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (profileSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Ошибка загрузки профиля: ${profileSnapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            );
          }

          if (!profileSnapshot.hasData || profileSnapshot.data == null) {
            return const Center(child: Text('Не удалось найти профиль.'));
          }

          final profile = profileSnapshot.data!;
          final fullName = profile['full_name'] ?? 'Без имени';
          final email = profile['email'] ?? 'Нет данных';
          final phone = profile['phone'] ?? 'Нет данных';
          final role = profile['role'] ?? 'user';
          final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

          return FutureBuilder<List<List<Map<String, dynamic>>>>(
            future: Future.wait([
              _workshopsFuture,
              _ministriesFuture,
              _marketplaceFuture,
            ]),
            builder: (context, futuresSnapshot) {
              if (futuresSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (futuresSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Ошибка загрузки данных: ${futuresSnapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                );
              }

              final workshops = futuresSnapshot.data![0];
              final ministries = futuresSnapshot.data![1];
              final marketplaceItems = futuresSnapshot.data![2];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // --- Профиль ---
                        CircleAvatar(
                          radius: 50,
                          backgroundColor:
                              // ignore: deprecated_member_use
                              theme.colorScheme.primary.withOpacity(0.5),
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
                            role == 'admin'
                                ? 'Администратор'
                                : 'Участник',
                            style: TextStyle(
                                color:
                                    theme.colorScheme.onSecondaryContainer),
                          ),
                          backgroundColor:
                              theme.colorScheme.secondaryContainer,
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

                        // --- Мои воркшопы ---
                        if (workshops.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Мои воркшопы (${workshops.length})',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...workshops
                              .take(3)
                              .map((w) => _buildWorkshopCard(w, theme)),
                          if (workshops.length > 3) ...[
                            const SizedBox(height: 8),
                            Text(
                              '... и ещё ${workshops.length - 3}',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],

                        // --- Мои служения ---
                        if (ministries.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Мои служения (${ministries.length})',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...ministries
                              .take(3)
                              .map((m) => _buildMinistryCard(m, theme)),
                          if (ministries.length > 3) ...[
                            const SizedBox(height: 8),
                            Text(
                              '... и ещё ${ministries.length - 3}',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                          const SizedBox(height: 32),
                        ],

                        // --- Мои товары/услуги ---
                        if (marketplaceItems.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Мои товары/услуги (${marketplaceItems.length})',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...marketplaceItems
                              .take(3)
                              .map((i) => _buildMarketplaceCard(i, theme)),
                          if (marketplaceItems.length > 3) ...[
                            const SizedBox(height: 8),
                            Text(
                              '... и ещё ${marketplaceItems.length - 3}',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ],

                        // --- Если ничего нет ---
                        if (workshops.isEmpty &&
                            ministries.isEmpty &&
                            marketplaceItems.isEmpty)
                          Text(
                            'Вы пока не участвуете ни в одном воркшопе, служении или не создали товаров/услуг.',
                            style: theme.textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- Карточка воркшопа ---
  Widget _buildWorkshopCard(Map<String, dynamic> workshop, ThemeData theme) {
    final title = workshop['title'] ?? 'Без названия';
    final leaderName = workshop['leader']?['full_name'] ?? 'Не назначен';
    final schedule = workshop['recurring_schedule'] ?? '—';
    final time = workshop['recurring_time'] ?? '—';
    final String? imageUrl = workshop['image_url'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl,
                    width: 60, height: 60, fit: BoxFit.cover),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school_outlined, size: 30),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  Text('Лидер: $leaderName',
                      style:
                          theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                  Text('$schedule, $time',
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Карточка служения ---
  Widget _buildMinistryCard(Map<String, dynamic> ministry, ThemeData theme) {
    final name = ministry['name'] ?? 'Без названия';
    final members = ministry['ministry_members'] as List<dynamic>? ?? [];
    final role = members.isNotEmpty
        ? members[0]['role_in_ministry'] ?? 'member'
        : 'member';
    final String? imageUrl = ministry['image_url'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl,
                    width: 60, height: 60, fit: BoxFit.cover),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.hub_outlined, size: 30),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  Text('Роль: $role',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Карточка товара/услуги ---
  Widget _buildMarketplaceCard(Map<String, dynamic> item, ThemeData theme) {
    final title = item['title'] ?? 'Без названия';
    final isService = item['is_service'] ?? false;
    final price = item['price'] != null
        ? '${item['price']} €'
        : 'Цена по запросу';
    final String? imageUrl = item['image_url'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl,
                    width: 60, height: 60, fit: BoxFit.cover),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                    isService
                        ? Icons.build_outlined
                        : Icons.shopping_bag_outlined,
                    size: 30),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w500)),
                  Text(isService ? 'Услуга' : 'Товар',
                      style:
                          theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                  Text(price,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.green)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
