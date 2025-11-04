import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

final supabase = Supabase.instance.client;
const uuid = Uuid();

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isAdmin = false;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _checkIfAdmin();
  }

  Future<void> _checkIfAdmin() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted && profile != null) {
        setState(() {
          _isAdmin = profile['role'] == 'admin';
        });
      }
    } catch (e) {
      debugPrint('Ошибка проверки админа: $e');
    }
  }

  Future<void> _loadItems() async {
    try {
      final data = await supabase
          .from('marketplace')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        _items = (data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки товаров: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addItem({
    required String title,
    required String description,
    required String contactInfo,
    required double? price,
    required bool isService,
    XFile? image,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка: пользователь не авторизован'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    String? imageUrl;
    if (image != null) {
      try {
        final fileName = '${uuid.v4()}_${image.name}';

        // upload() возвращает строку пути (String), без .path
        final uploadPath = await supabase.storage
            .from('marketplace_images')
            .upload(fileName, File(image.path));

        imageUrl = supabase.storage
            .from('marketplace_images')
            .getPublicUrl(uploadPath);
      } catch (e) {
        debugPrint('Ошибка загрузки изображения: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка загрузки изображения: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    try {
      await supabase.from('marketplace').insert({
        'user_id': user.id,
        'title': title,
        'description': description,
        'contact_info': contactInfo,
        'price': price,
        'image_url': imageUrl,
        'is_service': isService,
      });

      if (mounted) {
        Navigator.pop(context); // закрыть окно
        _loadItems(); // обновить список
      }
    } catch (e) {
      debugPrint('Ошибка добавления товара: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка добавления: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await supabase.from('marketplace').delete().eq('id', id);
      _loadItems();
    } catch (e) {
      debugPrint('Ошибка удаления: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка удаления: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchContact(String contact) async {
    final uri = contact.startsWith('@')
        ? Uri.parse('https://t.me/${contact.substring(1)}')
        : Uri.parse('tel:$contact');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть контакт: $contact')),
      );
    }
  }

  void _showAddItemDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final contactController = TextEditingController();
    final priceController = TextEditingController();
    bool isService = false;
    XFile? image;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Добавить товар или услугу',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Название *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(labelText: 'Описание'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contactController,
                      decoration:
                          const InputDecoration(labelText: 'Контакт (телефон или @telegram) *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(
                          labelText: 'Цена (введите число или оставьте пустым)'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text('Это услуга (без цены по умолчанию)'),
                      value: isService,
                      onChanged: (val) => setDialogState(() => isService = val),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picked = await _picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          setDialogState(() => image = picked);
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text('Выбрать фото'),
                    ),
                    if (image != null) ...[
                      const SizedBox(height: 10),
                      Image.file(File(image!.path), height: 100),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final price = priceController.text.isNotEmpty
                            ? double.tryParse(priceController.text)
                            : null;

                        await _addItem(
                          title: titleController.text,
                          description: descriptionController.text,
                          contactInfo: contactController.text,
                          price: price,
                          isService: isService,
                          image: image,
                        );
                      },
                      child: const Text('Добавить'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Маркетплейс'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Пока нет товаров или услуг.'))
              : RefreshIndicator(
                  onRefresh: _loadItems,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isMyItem = item['user_id'] == supabase.auth.currentUser?.id;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item['image_url'] != null)
                              ClipRRect(
                                borderRadius:
                                    const BorderRadius.vertical(top: Radius.circular(8)),
                                child: Image.network(
                                  item['image_url'],
                                  fit: BoxFit.cover,
                                  height: 200,
                                  width: double.infinity,
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'],
                                    style: theme.textTheme.titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  if (item['price'] != null) ...[
                                    Text(
                                      'Цена: ${item['price']} €',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(color: Colors.green),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  Text(
                                    item['description'] ?? 'Нет описания',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _launchContact(item['contact_info']),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.phone, size: 16),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Связаться: ${item['contact_info']}',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: Colors.blue,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_isAdmin || isMyItem)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () =>
                                            _deleteItem(item['id'].toString()),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
