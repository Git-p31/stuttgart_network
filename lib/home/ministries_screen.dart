import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:uuid/uuid.dart';
import 'package:stuttgart_network/services/database_service.dart';
import 'package:stuttgart_network/home/ministry_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;
const uuid = Uuid();

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

  Future<void> _deleteMinistry(String ministryId, BuildContext context) async {
    try {
      await supabase.from('ministries').delete().eq('id', ministryId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Служение удалено')),
        );
      }
      _refreshData();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                  ? _buildMobileLayout(ministries, isAdmin)
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

  Widget _buildMobileLayout(List<Map<String, dynamic>> ministries, bool isAdmin) {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12.0),
        itemCount: ministries.length,
        itemBuilder: (context, index) {
          final ministry = ministries[index];
          return _buildMinistryCard(ministry, isAdmin);
        },
      ),
    );
  }

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
          return _buildMinistryCard(ministry, isAdmin);
        },
      ),
    );
  }

  Widget _buildCreateCard(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showResponsiveCreateDialog(context, false),
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

  Widget _buildMinistryCard(Map<String, dynamic> ministry, bool isAdmin) {
    final memberCount = (ministry['ministry_members'] as List).length;
    final imageUrl = ministry['image_url'];
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
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
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(
                      Icons.hub,
                      size: 60,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (isAdmin)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      _showDeleteConfirmation(context, ministry['id'] as String);
                    },
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ministry['name'] ?? 'Без названия',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  ministry['description'] ?? 'Нет описания.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.groups_outlined, size: 20, color: theme.colorScheme.secondary),
                    const SizedBox(width: 8),
                    Text(
                      '$memberCount ${_getMemberText(memberCount)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MinistryDetailScreen(ministry: ministry),
                          ),
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

  String _getMemberText(int count) {
    if (count == 1) return 'участник';
    if (count > 1 && count < 5) return 'участника';
    return 'участников';
  }

  void _showDeleteConfirmation(BuildContext context, String ministryId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить служение?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMinistry(ministryId, context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showResponsiveCreateDialog(BuildContext context, bool isMobile) {
    final Widget dialogContent = _buildCreateDialogContent();
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => dialogContent,
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            content: SizedBox(width: 500, child: dialogContent),
            contentPadding: EdgeInsets.zero,
          );
        },
      );
    }
  }

  Widget _buildCreateDialogContent() {
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedLeaderId;
    XFile? pickedImage;
    bool isLoading = false;

    return StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        Future<void> pickImage() async {
          final ImagePicker picker = ImagePicker();
          try {
            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              setDialogState(() => pickedImage = image);
            }
          } catch (e) {
            debugPrint('Ошибка выбора фото: $e');
          }
        }

        Future<void> handleSave() async {
          if (!formKey.currentState!.validate()) return;
          if (selectedLeaderId == null) {
            if (dialogContext.mounted) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Выберите лидера'), backgroundColor: Colors.red),
              );
            }
            return;
          }

          setDialogState(() => isLoading = true);

          try {
            String? imageUrl;
            if (pickedImage != null) {
              final extension = pickedImage!.name.split('.').lastOrNull ?? 'jpg';
              final fileName = '${uuid.v4()}.$extension';
              final imageBytes = await pickedImage!.readAsBytes();

              await supabase.storage
                  .from('ministry_images')
                  .uploadBinary(
                    fileName,
                    imageBytes,
                    fileOptions: FileOptions(contentType: pickedImage!.mimeType),
                  );

              final publicUrlResponse = supabase.storage
                  .from('ministry_images')
                  .getPublicUrl(fileName);

              imageUrl = publicUrlResponse.data!['publicUrl'] as String?;
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
            _refreshData();
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

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
            top: 24,
            left: 24,
            right: 24,
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
                          setDialogState(() => selectedLeaderId = value);
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

extension on String {
  get data => null;
}