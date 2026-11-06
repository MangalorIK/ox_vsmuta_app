import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MessagesScreen extends StatefulWidget {
  final bool notificationsEnabled;
  final Function(bool) onNotificationsChanged;

  const MessagesScreen({
    super.key,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ScrollController _scrollController = ScrollController();
  int _lastDocCount = 0; // Для отслеживания новых сообщений

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Локатор ВС'), // 👈 Изменено название
        actions: [
          // Переключатель справа от текста
          Row(
            children: [
              const Text('Уведомления', style: TextStyle(fontSize: 13)),
              Switch(
                value: widget.notificationsEnabled,
                onChanged: widget.onNotificationsChanged,
                activeColor: Colors.green, // Цвет в стиле темы
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Padding(
        // 👈 Отступ от нижней границы в 10%
        padding: EdgeInsets.only(bottom: screenHeight * 0.1),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('messages')
              .where('channel', isEqualTo: 'locations')
              // 👈 ascending: true — новые снизу
              .orderBy('createdAt', descending: false)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Ошибка: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            // Автоскролл вниз при первой загрузке или при новых сообщениях
            if (docs.length != _lastDocCount) {
              _lastDocCount = docs.length;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });
            }

            if (docs.isEmpty) {
              return const Center(child: Text('Пока нет сообщений'));
            }

            return ListView.builder(
              controller: _scrollController,
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;
                final text = data['plainText'] as String? ?? '';
                final createdAt = data['createdAt'] as Timestamp?;

                // Разделяем заголовок и тело
                final lines = text.split('\n');
                final title = lines.isNotEmpty ? lines.first : '';
                final body = lines.length > 1
                    ? lines.sublist(1).join('\n')
                    : '';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: ListTile(
                    title: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: body.isNotEmpty ? Text(body) : null,
                    trailing: createdAt != null
                        ? Text(
                            _formatTime(createdAt.toDate()),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays < 1) return '${diff.inHours} ч назад';
    return '${dt.day}.${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
