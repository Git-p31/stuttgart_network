import 'package:flutter/material.dart';
import 'package:stuttgart_network/home/profile_screen.dart';
import 'package:stuttgart_network/home/ministries_screen.dart';
import 'package:stuttgart_network/home/events_screen.dart';
import 'package:stuttgart_network/home/workshops_screen.dart';
import 'package:stuttgart_network/home/marketplace_screen.dart';
import 'package:stuttgart_network/home/crm_screen.dart'; // Импортируем CRM
import 'package:stuttgart_network/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // Список заголовков для AppBar
  static const List<String> _titles = [
    'Профиль',
    'CRM',
    'Служения',
    'События',
    'Воркшопы',
    'Маркетплейс',
  ];

  // Список экранов
  static final List<Widget> _screens = [
    const ProfileScreen(),
    const CrmScreen(), // Заглушка удалена, добавлен реальный экран
    const MinistriesScreen(),
    const EventsScreen(),
    const WorkshopsScreen(),
    const MarketplaceScreen(),
  ];

  // Список пунктов меню для Drawer
  final List<_MenuItem> _menuItems = [];

  @override
  void initState() {
    super.initState();
    _menuItems.addAll([
      _MenuItem(icon: Icons.person_outline, title: 'Профиль', index: 0),
      _MenuItem(
          icon: Icons.groups_outlined,
          title: 'CRM',
          index: 1,
          isDisabled: false), // isDisabled теперь false
      _MenuItem(icon: Icons.hub_outlined, title: 'Служения', index: 2),
      _MenuItem(icon: Icons.event_outlined, title: 'События', index: 3),
      _MenuItem(icon: Icons.school_outlined, title: 'Воркшопы', index: 4),
      _MenuItem(icon: Icons.storefront, title: 'Маркетплейс', index: 5),
    ]);
  }

  // Метод для обработки нажатия на пункт меню
  void _onItemTapped(_MenuItem item) {
    Navigator.pop(context); // Закрываем Drawer
    setState(() {
      _selectedIndex = item.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              accountEmail: const Text('Меню навигации'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: theme.colorScheme.surface,
                child: Icon(Icons.hub, size: 32, color: theme.colorScheme.primary),
              ),
              decoration: BoxDecoration(color: theme.colorScheme.primary),
            ),
            ..._menuItems.map(
              (item) => ListTile(
                leading: Icon(item.icon),
                title: Text(item.title),
                selected: _selectedIndex == item.index,
                onTap: () => _onItemTapped(item),
              ),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title:
                  Text('Выйти', style: TextStyle(color: theme.colorScheme.error)),
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
        children: _screens,
      ),
    );
  }
}

// Класс для пунктов меню
class _MenuItem {
  final IconData icon;
  final String title;
  final int index;
  final bool isDisabled;

  _MenuItem({
    required this.icon,
    required this.title,
    required this.index,
    this.isDisabled = false,
  });
}