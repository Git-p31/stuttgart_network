import 'package:flutter/material.dart';
import 'package:stuttgart_network/services/database_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatMessageScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const ChatMessageScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<ChatMessageScreen> createState() => _ChatMessageScreenState();
}

class _ChatMessageScreenState extends State<ChatMessageScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _messageController = TextEditingController();
  final String _currentUserId = Supabase.instance.client.auth.currentUser!.id;

  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  
  // --- ✅ ИЗМЕНЕНИЯ ЗДЕСЬ ---
  Map<String, String> _memberNames = {}; // Карта для хранения имен
  bool _isLoadingNames = true; // Статус загрузки
  // --- КОНЕЦ ИЗМЕНЕНИЙ ---

  @override
  void initState() {
    super.initState();
    _messagesStream = _databaseService.getChatMessagesStream(widget.groupId);
    // --- ✅ ЗАГРУЖАЕМ ИМЕНА ПРИ ВХОДЕ ---
    _loadMemberNames();
  }

  // --- ✅ НОВАЯ ФУНКЦИЯ ДЛЯ ЗАГРУЗКИ ИМЕН ---
  Future<void> _loadMemberNames() async {
    try {
      final names =
          await _databaseService.getChatGroupMemberNames(widget.groupId);
      if (mounted) {
        setState(() {
          _memberNames = names;
          _isLoadingNames = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки участников: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoadingNames = false);
      }
    }
  }
  // --- КОНЕЦ НОВОЙ ФУНКЦИИ ---

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) {
      return;
    }

    _messageController.clear();
    try {
      await _databaseService.sendChatMessage(widget.groupId, content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
      ),
      body: Column(
        children: [
          // --- Поток сообщений ---
          Expanded(
            // --- ✅ ЖДЕМ СНАЧАЛА ЗАГРУЗКУ ИМЕН ---
            child: _isLoadingNames
                ? const Center(
                    child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ))
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _messagesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                            child: Text('Ошибка: ${snapshot.error}'));
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return const Center(
                            child: Text('Сообщений пока нет.'));
                      }

                      // Используем ListView.builder
                      return ListView.builder(
                        reverse: true, // ✅ Сообщения идут снизу вверх
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          // ✅ Логика реверса: stream (ascending: true) + ListView (reverse: true)
                          // требует инвертировать индекс для доступа к списку.
                          final reversedIndex = messages.length - 1 - index;
                          final msg = messages[reversedIndex];
                          
                          final senderId = msg['sender_id'];
                          final isMe = senderId == _currentUserId;

                          // --- ✅ ЗАМЕНА ЗАГЛУШКИ ---
                          // Ищем имя в нашей карте.
                          final senderName = _memberNames[senderId] ?? '...';
                          // --- КОНЕЦ ЗАМЕНЫ ---

                          return _buildMessageBubble(
                            context,
                            content: msg['content'],
                            isMe: isMe,
                            senderName: isMe ? 'Вы' : senderName, // Передаем имя
                          );
                        },
                      );
                    },
                  ),
          ),

          // --- Поле ввода ---
          _buildMessageInput(context, theme),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context, {
    required String content,
    required bool isMe,
    required String senderName,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Text(
              senderName, // ✅ Теперь здесь будет имя
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.secondary),
            ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(content),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput(BuildContext context, ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Сообщение...',
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(), // Отправка по Enter
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: theme.colorScheme.primary),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}