import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Для форматирования даты
import 'package:stuttgart_network/services/database_service.dart';

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});

  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen> {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _allProfiles = [];
  List<Map<String, dynamic>> _filteredProfiles = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedRole = 'All';

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() => _isLoading = true);
    try {
      // Подгружаем профили через DatabaseService
      final profiles = await _dbService.getCrmProfiles();
      setState(() {
        _allProfiles = profiles;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredProfiles = _allProfiles.where((p) {
        final name = (p['full_name'] ?? '').toString().toLowerCase();
        final email = (p['email'] ?? '').toString().toLowerCase();
        final phone = (p['phone'] ?? '').toString().toLowerCase();
        final address = (p['address'] ?? '').toString().toLowerCase();
        final role = p['role'] ?? 'user';

        final matchesSearch = name.contains(_searchQuery) || 
                             email.contains(_searchQuery) || 
                             phone.contains(_searchQuery) ||
                             address.contains(_searchQuery);
        
        final matchesRole = _selectedRole == 'All' || role == _selectedRole.toLowerCase();

        return matchesSearch && matchesRole;
      }).toList();
    });
  }

  // Расширенный диалог редактирования
  Future<void> _showEditDialog(Map<String, dynamic> profile) async {
    final nameController = TextEditingController(text: profile['full_name']);
    final phoneController = TextEditingController(text: profile['phone']);
    final addressController = TextEditingController(text: profile['address'] ?? '');
    final dobController = TextEditingController(
      text: profile['birthday'] != null 
        ? DateFormat('dd.MM.yyyy').format(DateTime.parse(profile['birthday'])) 
        : ''
    );
    String currentRole = profile['role'] ?? 'user';

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Карточка резидента'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'ФИО')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Телефон')),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Адрес проживания')),
              TextField(
                controller: dobController, 
                decoration: const InputDecoration(labelText: 'День рождения (ГГГГ-ММ-ДД)', hintText: '1990-05-20'),
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: currentRole,
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('Пользователь (User)')),
                  DropdownMenuItem(value: 'admin', child: Text('Администратор (Admin)')),
                  DropdownMenuItem(value: 'leader', child: Text('Лидер (Leader)')),
                ],
                onChanged: (val) => currentRole = val!,
                decoration: const InputDecoration(labelText: 'Системная роль'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _dbService.updateProfile(
                  userId: profile['id'],
                  fullName: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                  role: currentRole,
                  address: addressController.text.trim(), // ДОБАВЬТЕ ЭТО
                  birthday: dobController.text.trim(),    // ДОБАВЬТЕ ЭТО
                );
                if (mounted) Navigator.pop(context);
                _loadProfiles();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
              }
            }, 
            child: const Text('Сохранить изменения')
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('База Stuttgart Network'),
        actions: [
          IconButton(onPressed: _loadProfiles, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск (имя, почта, телефон, адрес)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) {
                _searchQuery = val.toLowerCase();
                _applyFilters();
              },
            ),
          ),
          // Быстрые фильтры по ролям
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Admin', 'Leader', 'User'].map((role) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(role),
                    selected: _selectedRole == role,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedRole = role);
                        _applyFilters();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _filteredProfiles.length,
                  itemBuilder: (context, index) {
                    final p = _filteredProfiles[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      elevation: 2,
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(p['role']),
                          child: Text(p['full_name']?[0] ?? '?', style: const TextStyle(color: Colors.white)),
                        ),
                        title: Text(p['full_name'] ?? 'Без имени', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${p['role']?.toUpperCase()} • ${p['phone'] ?? 'Нет телефона'}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _infoRow(Icons.email, 'Email', p['email']),
                                _infoRow(Icons.location_on, 'Адрес', p['address']),
                                _infoRow(Icons.cake, 'День рождения', p['birthday']),
                                const Divider(),
                                const Text('Активность:', style: TextStyle(fontWeight: FontWeight.bold)),
                                _infoRow(Icons.hub, 'Служения', _formatList(p['ministries'])),
                                _infoRow(Icons.school, 'Воркшопы', _formatList(p['workshops'])),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _showEditDialog(p),
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Редактировать'),
                                    ),
                                    TextButton.icon(
                                      onPressed: () => _confirmDelete(p['id']),
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      label: const Text('Удалить', style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey)),
          Expanded(child: Text(value?.toString() ?? '—', style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin': return Colors.redAccent;
      case 'leader': return Colors.orangeAccent;
      default: return Colors.blueAccent;
    }
  }

  String _formatList(dynamic list) {
    if (list == null || (list as List).isEmpty) return 'Нет данных';
    return (list as List).join(', ');
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление'),
        content: const Text('Вы уверены, что хотите удалить профиль из CRM?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Нет')),
          ElevatedButton(
            onPressed: () async {
              await _dbService.deleteProfile(id); // Метод в DatabaseService
              Navigator.pop(ctx);
              _loadProfiles();
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Да, удалить')
          ),
        ],
      ),
    );
  }
}