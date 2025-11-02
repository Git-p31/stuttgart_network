import 'dart:io'; // Для работы с File
import 'package:flutter/foundation.dart'; // для kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Для выбора фото
import 'package:stuttgart_network/services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Глобальный клиент (удобно, т.к. auth_service его не предоставляет)
final supabase = Supabase.instance.client;

class MinistriesScreen extends StatefulWidget {
  const MinistriesScreen({super.key});

  @override
  State<MinistriesScreen> createState() => _MinistriesScreenState();
}

class _MinistriesScreenState extends State<MinistriesScreen> {
  final DatabaseService _databaseService = DatabaseService();
  
  // Future, который загружает ВСЕ данные для экрана
  late Future<Map<String, dynamic>> _dataFuture;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _ministries = [];

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadScreenData();
  }

  /// Загружает и профиль, и служения одновременно
  Future<Map<String, dynamic>> _loadScreenData() async {
    try {
      // Запускаем оба запроса параллельно
      final results = await Future.wait([
        _databaseService.getMyProfile(),
        _databaseService.getMinistries(),
      ]);

      // Сохраняем данные для удобства
      _profileData = results[0] as Map<String, dynamic>;
      _ministries = results[1] as List<Map<String, dynamic>>;

      return {
        'profile': _profileData,
        'ministries': _ministries,
      };
    } catch (e) {
      // Передаем ошибку в FutureBuilder
      throw Exception('Ошибка загрузки данных: $e');
    }
  }

  /// Функция для обновления списка (когда мы создадим новое служение)
  void _refreshData() {
    setState(() {
      _dataFuture = _loadScreenData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. FutureBuilder ждет загрузки всех данных
      body: FutureBuilder<Map<String, dynamic>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          // Состояние загрузки
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Состояние ошибки
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Ошибка: ${snapshot.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            );
          }
          
          // Проверяем роль

          // 2. Отображаем список служений
          return RefreshIndicator(
            onRefresh: () async => _refreshData(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _ministries.length,
              itemBuilder: (context, index) {
                final ministry = _ministries[index];
                final members = ministry['ministry_members'] as List;
                final memberCount = members.length;
                final imageUrl = ministry['image_url'];

                return _buildMinistryCard(ministry, memberCount, imageUrl);
              },
            ),
          );
        },
      ),

      // 3. Кнопка "Создать" (только для админов)
      floatingActionButton: _profileData != null && _profileData!['role'] == 'admin'
          ? FloatingActionButton(
              onPressed: () => _showCreateDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// Виджет-карточка для отображения служения
  Widget _buildMinistryCard(Map<String, dynamic> ministry, int memberCount, String? imageUrl) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4. Фотография служения
          if (imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12.0),
                topRight: Radius.circular(12.0),
              ),
              child: Image.network(
                imageUrl,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                // Заглушка на случай ошибки загрузки
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.image_not_supported)),
                ),
              ),
            )
          else
            // Заглушка, если фото нет
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12.0),
                  topRight: Radius.circular(12.0),
                ),
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
                // 5. Имя служения
                Text(
                  ministry['name'] ?? 'Без названия',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // 6. Описание
                Text(
                  ministry['description'] ?? 'Нет описания.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),

                // 7. Количество участников
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
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Переход на экран деталей служения
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

  /// Показывает диалог создания нового служения
  void _showCreateDialog(BuildContext context) {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    
    String? selectedLeaderId;
    XFile? pickedImage;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Позволяет быть выше
      builder: (ctx) {
        // StatefulBuilder нужен, чтобы UI диалога мог обновляться
        // (например, при выборе фото или загрузке)
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            
            /// Логика выбора изображения
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

            /// Логика сохранения
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

                // 1. Загружаем фото, если оно выбрано
                if (pickedImage != null) {
                  final fileName = '${DateTime.now().millisecondsSinceEpoch}.${pickedImage!.name.split('.').last}';
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

                // 2. Вставляем служение в БД
                final newMinistry = await supabase
                    .from('ministries')
                    .insert({
                      'name': nameController.text,
                      'description': descriptionController.text,
                      'image_url': imageUrl,
                    })
                    .select() // Возвращаем созданную запись
                    .single(); // Как одну Map

                final newMinistryId = newMinistry['id'];

                // 3. Назначаем лидера
                await supabase.from('ministry_members').insert({
                  'ministry_id': newMinistryId,
                  'user_id': selectedLeaderId!,
                  'role_in_ministry': 'leader',
                });

                // 4. Закрываем диалог и обновляем список
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext); // Закрыть диалог
                }
                _refreshData(); // Обновить главный экран

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
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
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

                      // --- Выбор фото ---
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

                      // --- Выбор лидера (с загрузкой) ---
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
                      
                      // --- Кнопка Сохранить ---
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
      },
    );
  }
}

