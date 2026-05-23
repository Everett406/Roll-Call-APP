import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_conversation.dart';
import 'ai_chat_screen.dart';

/// AI 对话列表底部弹窗
class AiConversationsBottomSheet extends StatefulWidget {
  const AiConversationsBottomSheet({super.key});

  @override
  State<AiConversationsBottomSheet> createState() => _AiConversationsBottomSheetState();
}

class _AiConversationsBottomSheetState extends State<AiConversationsBottomSheet> {
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
          _conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        });
      } catch (_) {}
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
      Navigator.pop(context, conversation);
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
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖动条
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '历史对话',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _createNewConversation,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新建'),
                ),
              ],
            ),
          ),
          const Divider(),
          // 列表
          Flexible(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _conversations.isEmpty
                    ? _buildEmptyState(theme)
                    : _buildConversationList(theme),
          ),
          // 底部安全区域
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
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
            '点击"新建"开始新对话',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(ThemeData theme) {
    return ListView.builder(
      shrinkWrap: true,
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
              Navigator.pop(context, conv);
            },
          ),
        );
      },
    );
  }
}

/// 显示历史对话底部弹窗
Future<AiConversation?> showAiConversationsBottomSheet(BuildContext context) async {
  return showModalBottomSheet<AiConversation>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const AiConversationsBottomSheet(),
  );
}
