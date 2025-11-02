import 'package:flutter/material.dart';
import 'package:stuttgart_network/home/profile_screen.dart';
import 'package:stuttgart_network/home/crm_screen.dart';
import 'package:stuttgart_network/home/ministries_screen.dart';
import 'package:stuttgart_network/home/events_screen.dart'; 
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
  ];

  // Список экранов
  static final List<Widget> _screens = <Widget>[
    const ProfileScreen(),
    const CrmScreen(),
    const MinistriesScreen(),
    const EventsScreen(), 
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Закрываем Drawer
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
                child: Icon(
                  Icons.hub,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Профиль'),
              selected: _selectedIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('CRM'),
              selected: _selectedIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('Служения'),
              selected: _selectedIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('События'),
              selected: _selectedIndex == 3,
              onTap: () => _onItemTapped(3),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text(
                'Выйти',
                style: TextStyle(color: theme.colorScheme.error),
              ),
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
