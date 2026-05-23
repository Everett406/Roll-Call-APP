import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_conversation.dart';
import 'ai_chat_screen.dart';

/// AI 对话列表页面
class AiConversationsScreen extends StatefulWidget {
  const AiConversationsScreen({super.key});

  @override
  State<AiConversationsScreen> createState() => _AiConversationsScreenState();
}

class _AiConversationsScreenState extends State<AiConversationsScreen> {
  List<AiConversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('ai_conversations');
    
    if (json != null) {
      try {
        final List<dynamic> list = jsonDecode(json);
        setState(() {
          _conversations = list.map((e) => AiConversation.fromJson(e)).toList();
          // 按更新时间倒序
          _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        });
      } catch (_) {
        // 解析失败
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_conversations.map((c) => c.toJson()).toList());
    await prefs.setString('ai_conversations', json);
  }

  Future<void> _createNewConversation() async {
    final conversation = AiConversation.create();
    setState(() {
      _conversations.insert(0, conversation);
    });
    await _saveConversations();
    
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiChatScreen(conversation: conversation),
        ),
      ).then((_) => _loadConversations());
    }
  }

  Future<void> _deleteConversation(String id) async {
    setState(() {
      _conversations.removeWhere((c) => c.id == id);
    });
    await _saveConversations();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    
    if (dateDay == today) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (dateDay == today.subtract(const Duration(days: 1))) {
      return '昨天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else {
      return '${date.month}月${date.day}日';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 对话'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建对话',
            onPressed: _createNewConversation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _buildEmptyState(theme)
              : _buildConversationList(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有对话',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 开始新对话',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _createNewConversation,
            icon: const Icon(Icons.add),
            label: const Text('开始对话'),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(ThemeData theme) {
    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        return Dismissible(
          key: Key(conv.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: theme.colorScheme.error,
            child: Icon(Icons.delete, color: theme.colorScheme.onError),
          ),
          onDismissed: (_) => _deleteConversation(conv.id),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.chat,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              conv.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _formatDate(conv.updatedAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiChatScreen(conversation: conv),
                ),
              ).then((_) => _loadConversations());
            },
          ),
        );
      },
    );
  }
}
