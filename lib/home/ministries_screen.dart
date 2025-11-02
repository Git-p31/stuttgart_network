import 'dart:io'; 
import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:dotted_border/dotted_border.dart'; // ✅ Импорт
import 'package:uuid/uuid.dart'; // ✅ Импорт
import 'package:stuttgart_network/services/database_service.dart';
import 'package:stuttgart_network/home/ministry_detail_screen.dart'; // ✅ Импорт
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
const uuid = Uuid(); // ✅ Создаем экземпляр Uuid

class MinistriesScreen extends StatefulWidget {
  const MinistriesScreen({super.key});

  @override
  State<MinistriesScreen> createState() => _MinistriesScreenState();
}

class _MinistriesScreenState extends State<MinistriesScreen> {
  final DatabaseService _databaseService = DatabaseService();
  
  late Future<Map<String, dynamic>> _dataFuture;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _ministries = [];

  final double _breakpoint = 600.0; 

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadScreenData();
  }

  Future<Map<String, dynamic>> _loadScreenData() async {
    try {
      final results = await Future.wait([
        _databaseService.getMyProfile(),
        _databaseService.getMinistries(),
      ]);

      _profileData = results[0] as Map<String, dynamic>;
      _ministries = results[1] as List<Map<String, dynamic>>;

      return {
        'profile': _profileData,
        'ministries': _ministries,
      };
    } catch (e) {
      throw Exception('Ошибка загрузки данных: $e');
    }
  }

  void _refreshData() {
    setState(() {
      _dataFuture = _loadScreenData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'Ошибка: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          );
        }
        
        final profile = snapshot.data!['profile'] as Map<String, dynamic>;
        final ministries = snapshot.data!['ministries'] as List<Map<String, dynamic>>;
        _profileData = profile;
        _ministries = ministries;
        
        final bool isAdmin = profile['role'] == 'admin';

        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isMobile = constraints.maxWidth < _breakpoint;

            return Scaffold(
              body: isMobile
                  ? _buildMobileLayout(ministries)
                  : _buildWebLayout(ministries, isAdmin),
              
              floatingActionButton: (isAdmin && isMobile)
                  ? FloatingActionButton(
                      onPressed: () => _showResponsiveCreateDialog(context, isMobile),
                      child: const Icon(Icons.add),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  /// МАКЕТ ДЛЯ MOBILE (< 600px)
  Widget _buildMobileLayout(List<Map<String, dynamic>> ministries) {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0), 
        itemCount: ministries.length,
        itemBuilder: (context, index) {
          final ministry = ministries[index];
          return _buildMinistryCard(ministry); // Передаем всю карту
        },
      ),
    );
  }

  /// МАКЕТ ДЛЯ WEB (> 600px)
  Widget _buildWebLayout(List<Map<String, dynamic>> ministries, bool isAdmin) {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: GridView.builder(
        padding: const EdgeInsets.all(24.0), 
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400.0,
          mainAxisSpacing: 24.0,
          crossAxisSpacing: 24.0,
          childAspectRatio: 0.9, 
        ),
        itemCount: isAdmin ? ministries.length + 1 : ministries.length,
        itemBuilder: (context, index) {
          if (isAdmin && index == 0) {
            return _buildCreateCard(context);
          }

          final ministryIndex = isAdmin ? index - 1 : index; 
          final ministry = ministries[ministryIndex];
          return _buildMinistryCard(ministry); // Передаем всю карту
        },
      ),
    );
  }

  /// Карточка "Создать" (только для Web)
  Widget _buildCreateCard(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showResponsiveCreateDialog(context, false), // isMobile = false
      borderRadius: BorderRadius.circular(12.0),
      child: DottedBorder( 
        color: theme.colorScheme.outline,
        borderType: BorderType.RRect, 
        strokeWidth: 2,
        dashPattern: const [8, 4],
        radius: const Radius.circular(12.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 48, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              const Text('Создать служение'),
            ],
          ),
        ),
      ),
    );
  }

  /// Виджет-карточка
  Widget _buildMinistryCard(Map<String, dynamic> ministry) {
    // Извлекаем данные из карты
    final memberCount = (ministry['ministry_members'] as List).length;
    final imageUrl = ministry['image_url'];
    
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero, 
      clipBehavior: Clip.hardEdge, // Обрезаем изображение по углам
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 180,
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.image_not_supported)),
              ),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Center(
                child: Icon(
                  Icons.hub,
                  size: 60,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ministry['name'] ?? 'Без названия',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  ministry['description'] ?? 'Нет описания.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.groups_outlined, size: 20, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Text(
                      '$memberCount ${memberCount == 1 ? 'участник' : (memberCount > 1 && memberCount < 5 ? 'участника' : 'участников')}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    
                    // ✅ ФИЧА: Кнопка "Подробнее" теперь работает
                    ElevatedButton(
                      onPressed: () {
                        // Передаем всю карту служения на новый экран
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MinistryDetailScreen(ministry: ministry),
                          ),
                          // После возврата (напр., если вышли из служения) - обновляем список
                        ).then((_) => _refreshData());
                      },
                      child: const Text('Подробнее'),
                    )
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Адаптивный диалог
  void _showResponsiveCreateDialog(BuildContext context, bool isMobile) {
    // Контент диалога (один и тот же)
    final Widget dialogContent = _buildCreateDialogContent();

    if (isMobile) {
      // --- MOBILE: Выдвижная панель ---
      showModalBottomSheet(
        context: context,
        isScrollControlled: true, 
        builder: (ctx) => dialogContent,
      );
    } else {
      // --- WEB: Центральный диалог ---
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            content: SizedBox(
              width: 500, // Фиксируем ширину для web
              child: dialogContent,
            ),
            contentPadding: EdgeInsets.zero, 
          );
        },
      );
    }
  }

  /// UI диалога
  Widget _buildCreateDialogContent() {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    String? selectedLeaderId;
    XFile? pickedImage;
    bool isLoading = false;

    // StatefulBuilder нужен, чтобы UI диалога мог обновляться
    return StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        
        Future<void> pickImage() async {
           final ImagePicker picker = ImagePicker();
            try {
              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                setDialogState(() {
                  pickedImage = image;
                });
              }
            } catch (e) {
              debugPrint('Ошибка выбора фото: $e');
            }
        }

        Future<void> handleSave() async {
           if (!formKey.currentState!.validate()) return;
            if (selectedLeaderId == null) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Выберите лидера'), backgroundColor: Colors.red),
              );
              return;
            }

            setDialogState(() => isLoading = true);

            try {
              String? imageUrl;

              if (pickedImage != null) {
                // ✅ ИСПРАВЛЕН БАГ: Используем Uuid для уникального имени
                final extension = pickedImage!.name.split('.').lastOrNull ?? 'jpg';
                final fileName = '${uuid.v4()}.$extension';
                final imageBytes = await pickedImage!.readAsBytes();
                
                await supabase.storage
                    .from('ministry_images')
                    .uploadBinary(fileName, imageBytes,
                        fileOptions: FileOptions(
                          contentType: pickedImage!.mimeType,
                        ));
                
                imageUrl = supabase.storage
                    .from('ministry_images')
                    .getPublicUrl(fileName);
              }

              final newMinistry = await supabase
                  .from('ministries')
                  .insert({
                    'name': nameController.text,
                    'description': descriptionController.text,
                    'image_url': imageUrl,
                  })
                  .select()
                  .single(); 

              final newMinistryId = newMinistry['id'];

              await supabase.from('ministry_members').insert({
                'ministry_id': newMinistryId,
                'user_id': selectedLeaderId!,
                'role_in_ministry': 'leader',
              });

              if (dialogContext.mounted) {
                Navigator.pop(dialogContext); 
              }
              _refreshData(); // Обновляем главный экран (простой способ)

            } catch (e) {
              debugPrint('Ошибка создания служения: $e');
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
                );
              }
            } finally {
              setDialogState(() => isLoading = false);
            }
        }

        // --- UI Диалога ---
        return Padding(
          padding: EdgeInsets.only(
            // Отступ для клавиатуры на mobile
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
            // Стандартные отступы
            top: 24, left: 24, right: 24,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Новое служение', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Название'),
                    validator: (val) => val == null || val.isEmpty ? 'Введите название' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Описание'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  Text('Фотография служения', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: pickImage,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: pickedImage == null
                          ? const Center(child: Icon(Icons.add_a_photo_outlined))
                          : (kIsWeb
                              ? Image.network(pickedImage!.path, fit: BoxFit.cover)
                              : Image.file(File(pickedImage!.path), fit: BoxFit.cover)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('Назначить лидера', style: theme.textTheme.labelMedium),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _databaseService.getCrmProfiles(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ));
                      }
                      if (snapshot.hasError) {
                        return Text('Ошибка загрузки лидеров: ${snapshot.error}');
                      }
                      final profiles = snapshot.data ?? [];

                      return DropdownButtonFormField<String>(
                        initialValue: selectedLeaderId,
                        hint: const Text('Выберите пользователя'),
                        items: profiles.map((profile) {
                          return DropdownMenuItem(
                            value: profile['id'] as String,
                            child: Text(profile['full_name'] ?? 'Без имени'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedLeaderId = value;
                          });
                        },
                        validator: (val) => val == null ? 'Выберите лидера' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          onPressed: handleSave,
                          icon: const Icon(Icons.save),
                          label: const Text('Сохранить'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                          ),
                        ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}