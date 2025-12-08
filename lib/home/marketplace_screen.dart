import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart'; // для kIsWeb

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
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterType = 'Все';

  @override
  void initState() {
    super.initState();
    _loadItems();
    _checkIfAdmin();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    if (query != _searchQuery) {
      setState(() => _searchQuery = query);
      _applyFilters();
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> results = List.from(_items);

    if (_filterType != 'Все') {
      results = results.where((item) {
        if (_filterType == 'Товар') return !item['is_service'];
        if (_filterType == 'Услуга') return item['is_service'];
        return true;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      results = results.where((item) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        final desc = (item['description'] ?? '').toString().toLowerCase();
        return title.contains(_searchQuery) || desc.contains(_searchQuery);
      }).toList();
    }

    setState(() => _filteredItems = results);
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
        setState(() => _isAdmin = profile['role'] == 'admin');
      }
    } catch (e) {
      debugPrint('Ошибка проверки админа: $e');
    }
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('marketplace')
          .select('*')
          .order('created_at', ascending: false);

      setState(() {
        _items = (data as List).cast<Map<String, dynamic>>();
        _filteredItems = List.from(_items);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки товаров: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
      setState(() => _isLoading = false);
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
        const bucketName = 'marketplace_images';
        // Проверки bucket удалены, так как они ломают Web, если bucket не создан.
        // Ожидаем, что bucket создан в Supabase.

        final fileName = '${uuid.v4()}_${image.name}';

        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          await supabase.storage
              .from(bucketName)
              .uploadBinary(fileName, bytes,
                  fileOptions: FileOptions(contentType: image.mimeType));
        } else {
          await supabase.storage
              .from(bucketName)
              .upload(fileName, File(image.path),
                  fileOptions: FileOptions(contentType: image.mimeType));
        }

        imageUrl = supabase.storage.from(bucketName).getPublicUrl(fileName);
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

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Объявление успешно добавлено!')),
      );

      _loadItems();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть контакт: $contact')),
        );
      }
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                    const Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 40,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Добавить товар или услугу',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Название *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Описание',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      minLines: 3,
                      maxLines: 6,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: contactController,
                      decoration: const InputDecoration(
                        labelText: 'Контакт (телефон или @telegram) *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(
                        labelText: 'Цена (введите число или оставьте пустым)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text('Это услуга'),
                      value: isService,
                      onChanged: (val) => setDialogState(() => isService = val),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final picked = await _picker.pickImage(
                            source: ImageSource.gallery);
                        if (picked != null) {
                          setDialogState(() => image = picked);
                        }
                      },
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Выбрать фото'),
                    ),
                    if (image != null) ...[
                      const SizedBox(height: 10),
                      AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb // ✅ ИСПРАВЛЕННЫЙ БЛОК: Проверка платформы
                              ? Image.network(image!.path, fit: BoxFit.cover)
                              : Image.file(File(image!.path), fit: BoxFit.cover),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final description = descriptionController.text.trim();
                        final contact = contactController.text.trim();
                        final priceText = priceController.text.trim();

                        if (title.isEmpty || contact.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Название и контакт обязательны.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        final price = priceText.isNotEmpty
                            ? double.tryParse(priceText)
                            : (isService ? null : 0.0);

                        await _addItem(
                          title: title,
                          description: description,
                          contactInfo: contact,
                          price: price,
                          isService: isService,
                          image: image,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child:
                          const Text('Добавить', style: TextStyle(fontSize: 16)),
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Маркетплейс'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String value) {
              setState(() => _filterType = value);
              _applyFilters();
            },
            itemBuilder: (BuildContext context) => const [
              PopupMenuItem(value: 'Все', child: Text('Все')),
              PopupMenuItem(value: 'Товар', child: Text('Только товары')),
              PopupMenuItem(value: 'Услуга', child: Text('Только услуги')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddItemDialog,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по названию или описанию...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredItems.isEmpty
                    ? const Center(child: Text('Нет объявлений'))
                    : RefreshIndicator(
                        onRefresh: _loadItems,
                        child: GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.75,
                          ),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final isMyItem =
                                item['user_id'] == supabase.auth.currentUser?.id;
                            final typeColor = item['is_service']
                                ? Colors.orange
                                : Colors.green;

                            return GestureDetector(
                              onTap: () =>
                                  _launchContact(item['contact_info']),
                              child: Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (item['image_url'] != null)
                                        AspectRatio(
                                          aspectRatio: 1.3,
                                          child: Image.network(
                                            item['image_url'],
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                              Icons.broken_image,
                                              size: 40,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      else
                                        AspectRatio(
                                          aspectRatio: 1.3,
                                          child: item['is_service']
                                              ? Image.asset(
                                                  'assets/images/maxresdefault.jpg',
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                )
                                              : Container(
                                                  color: Colors.grey[300],
                                                  child: const Icon(
                                                    Icons.shopping_bag_outlined,
                                                    size: 40,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['title'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            if (item['price'] != null)
                                              Text(
                                                '${item['price']} €',
                                                style: TextStyle(
                                                  color: typeColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            const SizedBox(height: 4),
                                            Text(
                                              item['description'] ??
                                                  'Нет описания',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(
                                                  item['is_service']
                                                      ? Icons
                                                          .construction_outlined
                                                      : Icons
                                                          .shopping_bag_outlined,
                                                  color: typeColor,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  item['is_service']
                                                      ? 'Услуга'
                                                      : 'Товар',
                                                  style: TextStyle(
                                                    color: typeColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (_isAdmin || isMyItem)
                                                  IconButton(
                                                    icon: const Icon(
                                                        Icons.delete,
                                                        color: Colors.red,
                                                        size: 18),
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    onPressed: () =>
                                                        _deleteItem(item['id'].toString()),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
