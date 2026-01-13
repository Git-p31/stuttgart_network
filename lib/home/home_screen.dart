import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stuttgart_network/home/profile_screen.dart';
import 'package:stuttgart_network/home/ministries_screen.dart';
import 'package:stuttgart_network/home/events_screen.dart';
import 'package:stuttgart_network/home/workshops_screen.dart';
import 'package:stuttgart_network/home/marketplace_screen.dart';
import 'package:stuttgart_network/home/crm_screen.dart'; 
import 'package:stuttgart_network/services/auth_service.dart';
import 'package:stuttgart_network/services/database_service.dart';

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

  final List<Widget> _allScreens = [
    const ProfileScreen(),
    const CrmScreen(),
    const MinistriesScreen(),
    const EventsScreen(),
    const WorkshopsScreen(),
    const MarketplaceScreen(),
  ];

  static const List<String> _titles = [
    'Профиль', 'CRM', 'Служения', 'События', 'Воркшопы', 'Маркетплейс',
  ];

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _checkRole();
    if (mounted) _checkWhatsNew();
  }

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkWhatsNew() async {
    final prefs = await SharedPreferences.getInstance();
    const String currentUpdateId = 'update_v1_full_details_white'; 
    bool hasSeen = prefs.getBool(currentUpdateId) ?? false;

    if (!hasSeen) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _WhatsNewDialog(isAdmin: _isAdmin),
      );
      await prefs.setBool(currentUpdateId, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final List<_MenuItem> availableMenuItems = [
      _MenuItem(icon: Icons.person_outline, title: 'Профиль', index: 0),
    ];
    if (_isAdmin) {
      availableMenuItems.add(_MenuItem(icon: Icons.groups_outlined, title: 'CRM', index: 1));
    }
    availableMenuItems.addAll([
      _MenuItem(icon: Icons.hub_outlined, title: 'Служения', index: 2),
      _MenuItem(icon: Icons.event_outlined, title: 'События', index: 3),
      _MenuItem(icon: Icons.school_outlined, title: 'Воркшопы', index: 4),
      _MenuItem(icon: Icons.storefront, title: 'Маркетплейс', index: 5),
    ]);

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex]), elevation: 1),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text('Stuttgart Network', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              accountEmail: Text(_isAdmin ? 'Администратор' : 'Пользователь', style: const TextStyle(color: Colors.white70)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.hub, color: theme.colorScheme.primary),
              ),
            ),
            ...availableMenuItems.map((item) => ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              selected: _selectedIndex == item.index,
              onTap: () {
                setState(() => _selectedIndex = item.index);
                Navigator.pop(context);
              },
            )),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Что нового'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => UpdateDetailsScreen(isAdmin: _isAdmin)));
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: theme.colorScheme.error),
              title: Text('Выйти', style: TextStyle(color: theme.colorScheme.error)),
              onTap: () => AuthService().signOut(),
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _selectedIndex, children: _allScreens),
    );
  }
}

// --- СТРАНИЦА ПОДРОБНОСТЕЙ (БЕЛЫЙ ТЕКСТ) ---
class UpdateDetailsScreen extends StatelessWidget {
  final bool isAdmin;
  const UpdateDetailsScreen({super.key, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Темный фон для контраста
      appBar: AppBar(
        title: const Text('Детали обновления', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Версия 1.1.0', 
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          const Text('Мы постоянно работаем над улучшением Stuttgart Network. Вот подробности последнего релиза:',
            style: TextStyle(color: Colors.white70, fontSize: 16)),
          const Divider(height: 40, color: Colors.white24),
          
          if (isAdmin) _buildDetailSection(
            Icons.admin_panel_settings,
            'Управление CRM',
            'Новый мощный инструмент для администраторов. Теперь вы можете просматривать список всех участников, фильтровать их по ролям и управлять статусами доступа прямо из приложения.',
          ),
          
          _buildDetailSection(
            Icons.storefront,
            'Обновленный Маркетплейс',
            'Мы добавили категории товаров и улучшили поиск. Теперь находить нужные предложения в сообществе стало в два раза быстрее.',
          ),
          
          _buildDetailSection(
            Icons.school,
            'Воркшопы и Обучение',
            'Раздел воркшопов теперь поддерживает уведомления. Вы не пропустите начало регистрации на важные обучающие сессии.',
          ),
          
          _buildDetailSection(
            Icons.bug_report_outlined,
            'Исправления и оптимизация',
            'Исправлены ошибки при загрузке профиля на медленном интернете и улучшена плавность анимации меню.',
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(IconData icon, String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 6),
                Text(text, style: const TextStyle(color: Colors.white60, height: 1.5, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- МОДАЛЬНОЕ ОКНО (БЕЛЫЙ ТЕКСТ) ---
class _WhatsNewDialog extends StatelessWidget {
  final bool isAdmin;
  const _WhatsNewDialog({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E), // Темный фон диалога
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Обновление Network', style: TextStyle(color: Colors.white)),
      content: const Text(
        'Мы добавили CRM, Маркетплейс и улучшили работу воркшопов!',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => UpdateDetailsScreen(isAdmin: isAdmin)));
          }, 
          child: const Text('ПОДРОБНЕЕ', style: TextStyle(color: Colors.blueAccent)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
          onPressed: () => Navigator.pop(context),
          child: const Text('ПОНЯТНО', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final int index;
  _MenuItem({required this.icon, required this.title, required this.index});
}