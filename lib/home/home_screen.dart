import 'package:flutter/material.dart';
import 'package:stuttgart_network/home/profile_screen.dart';
import 'package:stuttgart_network/home/crm_screen.dart';
import 'package:stuttgart_network/home/ministries_screen.dart';
import 'package:stuttgart_network/services/auth_service.dart'; // Нужен для Выхода

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0; // Индекс выбранной вкладки

  // Экраны, которые будут отображаться
  static final List<Widget> _screens = <Widget>[
    const ProfileScreen(),
    const CrmScreen(),
    const MinistriesScreen(),
  ];

  // Заголовки для AppBar
  static const List<String> _titles = <String>[
    'Мой Профиль',
    'CRM',
    'Служения',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.pop(context); // Закрываем Drawer после выбора
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // 1. AppBar теперь здесь (а не на дочерних экранах)
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]), // 2. Заголовок меняется
        elevation: 1,
      ),
      
      // 3. Добавляем само боковое меню (Drawer)
      drawer: Drawer(
        child: Column(
          children: [
            // 4. "Красивый" заголовок меню
            UserAccountsDrawerHeader(
              accountName: const Text(
                'Stuttgart Network',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
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
            
            // 5. Пункты меню
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Профиль'),
              selected: _selectedIndex == 0, // Выделяем активный пункт
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
            
            // 6. Разделитель и кнопка "Выйти"
            const Spacer(), // Прижимает "Выйти" к низу
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text(
                'Выйти',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context); // Сначала закрываем меню
                AuthService().signOut(); // Затем выходим
              },
            ),
          ],
        ),
      ),
      
      // 7. Тело экрана (остается как было)
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
    );
  }
}