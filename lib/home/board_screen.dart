import 'package:flutter/material.dart';
import 'package:stuttgart_network/services/database_service.dart';

class BoardScreen extends StatefulWidget {
  final String? ministryId;
  final String? workshopId;
  final bool canEdit; // Админ или лидер

  const BoardScreen({
    super.key,
    this.ministryId,
    this.workshopId,
    required this.canEdit,
  });

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _controller = TextEditingController();
  late Future<Map<String, dynamic>> _boardFuture;

  @override
  void initState() {
    super.initState();
    _initFetch();
  }

  void _initFetch() {
    _boardFuture = _db.getBoardData(widget.ministryId, widget.workshopId);
  }

  void _refresh() {
    setState(() {
      _initFetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Доска задач и заметок'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _boardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Ошибка: ${snapshot.error}', 
                style: TextStyle(color: theme.colorScheme.error)),
            );
          }

          final data = snapshot.data ?? {};
          final boardId = data['id'] ?? '';
          final List items = data['board_items'] ?? [];

          return Column(
            children: [
              // Поле ввода только для тех, у кого есть права
              if (widget.canEdit)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Добавить задачу или объявление...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.send),
                        onPressed: () async {
                          if (_controller.text.trim().isEmpty) return;
                          
                          // Защита: если boardId пустой (ошибка в БД), не отправляем
                          if (boardId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Ошибка: ID доски не найден'))
                            );
                            return;
                          }

                          await _db.addBoardItem(boardId, _controller.text);
                          _controller.clear();
                          _refresh();
                        },
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('На доске пока нет записей'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final bool isDone = item['is_done'] ?? false;

                          return ListTile(
                            leading: Checkbox(
                              value: isDone,
                              onChanged: widget.canEdit
                                  ? (val) async {
                                      await _db.toggleBoardItem(item['id'], val!);
                                      _refresh();
                                    }
                                  : null,
                            ),
                            title: Text(
                              item['content'] ?? '',
                              style: TextStyle(
                                decoration: isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isDone ? Colors.grey : null,
                              ),
                            ),
                            trailing: widget.canEdit
                                ? IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () async {
                                      await _db.deleteBoardItem(item['id']);
                                      _refresh();
                                    },
                                  )
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}