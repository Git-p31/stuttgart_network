import 'package:flutter/material.dart';
import 'package:stuttgart_network/home/profile_screen.dart';
import 'package:stuttgart_network/home/ministries_screen.dart';
import 'package:stuttgart_network/home/events_screen.dart';
import 'package:stuttgart_network/home/workshops_screen.dart';
import 'package:stuttgart_network/home/marketplace_screen.dart';
import 'package:stuttgart_network/home/crm_screen.dart'; 
import 'package:stuttgart_network/services/auth_service.dart';
import 'package:stuttgart_network/services/database_service.dart'; // Добавляем импорт

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _dbService = DatabaseService();
  int _selectedIndex = 0;
  bool _isAdmin = false;
  bool _isLoading = true;

  // Полный список экранов
  final List<Widget> _allScreens = [
    const ProfileScreen(),     // 0
    const CrmScreen(),         // 1
    const MinistriesScreen(),  // 2
    const EventsScreen(),      // 3
    const WorkshopsScreen(),   // 4
    const MarketplaceScreen(), // 5
  ];

  static const List<String> _titles = [
    'Профиль',
    'CRM',
    'Служения',
    'События',
    'Воркшопы',
    'Маркетплейс',
  ];

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  // Проверяем роль пользователя при входе
  Future<void> _checkRole() async {
    try {
      final profile = await _dbService.getMyProfile();
      if (mounted) {
        setState(() {
          _isAdmin = profile['role'] == 'admin';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Динамически формируем список пунктов меню в зависимости от роли
    final List<_MenuItem> availableMenuItems = [
      _MenuItem(icon: Icons.person_outline, title: 'Профиль', index: 0),
    ];

    if (_isAdmin) {
      availableMenuItems.add(
        _MenuItem(icon: Icons.groups_outlined, title: 'CRM', index: 1),
      );
    }

    availableMenuItems.addAll([
      _MenuItem(icon: Icons.hub_outlined, title: 'Служения', index: 2),
      _MenuItem(icon: Icons.event_outlined, title: 'События', index: 3),
      _MenuItem(icon: Icons.school_outlined, title: 'Воркшопы', index: 4),
      _MenuItem(icon: Icons.storefront, title: 'Маркетплейс', index: 5),
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        elevation: 1,
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text(
                'Stuttgart Network',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: Text(_isAdmin ? 'Режим администратора' : 'Режим пользователя'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: theme.colorScheme.surface,
                child: Icon(Icons.hub, size: 32, color: theme.colorScheme.primary),
              ),
              decoration: BoxDecoration(color: theme.colorScheme.primary),
            ),
            // Рендерим только доступные пункты меню
            ...availableMenuItems.map(
              (item) => ListTile(
                leading: Icon(item.icon),
                title: Text(item.title),
                selected: _selectedIndex == item.index,
                onTap: () {
                  setState(() => _selectedIndex = item.index);
                  Navigator.pop(context);
                },
              ),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text('Выйти', style: TextStyle(color: theme.colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                AuthService().signOut();
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _allScreens,
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final int index;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.index,
  });
}