import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../services/ai_data_provider.dart';

/// 聊天消息模型
class ChatMessage {
  final String id;
  final bool isUser;
  String content;
  String? thinkingContent;
  List<ToolCallInfo>? toolCalls;
  final DateTime timestamp;
  bool isStreaming;

  ChatMessage({
    required this.id,
    required this.isUser,
    required this.content,
    this.thinkingContent,
    this.toolCalls,
    DateTime? timestamp,
    this.isStreaming = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 工具调用信息
class ToolCallInfo {
  final String name;
  String? result;
  bool isRunning;

  ToolCallInfo({
    required this.name,
    this.result,
    this.isRunning = true,
  });
}

/// 示例问题
const sampleQuestions = [
  '今天谁缺勤了？',
  '本周出勤率怎么样？',
  '张三的出勤情况如何？',
  '缺勤最多的人是谁？',
  '最近有哪些点名记录？',
];

class AiChatScreen extends StatefulWidget {
  /// 初始消息（从统计页传递过来）
  final String? initialMessage;

  const AiChatScreen({super.key, this.initialMessage});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  final AiService _aiService = AiService();

  bool _isLoading = false;
  int _remainingQuota = 20;
  bool _enableThinking = true;
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 设置数据提供者
    _aiService.setDataProvider(AiDataProvider.execute);

    // 加载思考模式偏好
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableThinking = prefs.getBool('ai_thinking_mode') ?? true;
    });

    // 加载历史记录
    await _loadHistory();

    // 获取剩余额度
    final quota = await _aiService.getRemainingQuota();
    if (mounted) {
      setState(() {
        _remainingQuota = quota;
      });
    }

    // 如果有初始消息，自动发送
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _inputController.text = widget.initialMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage();
      });
    }
  }

  /// 加载历史记录
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString('ai_chat_history');
    if (historyJson != null) {
      try {
        final List<dynamic> history = jsonDecode(historyJson);
        setState(() {
          _messages.addAll(history.map((h) => ChatMessage(
            id: h['id'],
            isUser: h['isUser'],
            content: h['content'],
            thinkingContent: h['thinkingContent'],
            timestamp: DateTime.parse(h['timestamp']),
          )));
        });
      } catch (_) {
        // 解析失败，忽略
      }
    }
  }

  /// 保存历史记录
  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    // 只保存最近 50 条
    final historyToSave = _messages.length > 50
        ? _messages.sublist(_messages.length - 50)
        : _messages;
    final history = historyToSave.map((m) => {
      'id': m.id,
      'isUser': m.isUser,
      'content': m.content,
      'thinkingContent': m.thinkingContent,
      'timestamp': m.timestamp.toIso8601String(),
    }).toList();
    await prefs.setString('ai_chat_history', jsonEncode(history));
  }

  /// 清空历史记录
  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('ai_chat_history');
    setState(() {
      _messages.clear();
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 发送消息
  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    _inputController.clear();
    _inputFocusNode.unfocus();

    // 添加用户消息
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isUser: true,
      content: text,
    );
    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _scrollToBottom();

    // 创建 AI 回复占位
    final aiMessage = ChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      isUser: false,
      content: '',
      isStreaming: true,
    );
    setState(() {
      _messages.add(aiMessage);
    });
    _scrollToBottom();

    // 构建对话历史
    final history = _messages
        .where((m) => !m.isStreaming)
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();

    // 移除最后一条（那是当前正在流式生成的 AI 消息）
    if (history.isNotEmpty && history.last['role'] == 'assistant' && history.last['content'] == '') {
      history.removeLast();
    }

    // 监听流式响应
    _streamSubscription?.cancel();
    _streamSubscription = _aiService
        .chatStream(
          userMessage: text,
          history: history,
          enableThinking: _enableThinking,
        )
        .listen(
      (event) {
        if (!mounted) return;

        final type = event['type'] as String;

        switch (type) {
          case 'thinking':
            setState(() {
              aiMessage.thinkingContent =
                  (aiMessage.thinkingContent ?? '') + (event['content'] as String);
            });
            _scrollToBottom();
            break;

          case 'content':
            setState(() {
              aiMessage.content += event['content'] as String;
            });
            _scrollToBottom();
            break;

          case 'tool_call':
            setState(() {
              final toolCall = ToolCallInfo(
                name: event['name'] as String,
                isRunning: true,
              );
              aiMessage.toolCalls ??= [];
              aiMessage.toolCalls!.add(toolCall);
            });
            _scrollToBottom();
            break;

          case 'tool_result':
            setState(() {
              final toolName = event['name'] as String;
              final result = event['result'] as String;
              if (aiMessage.toolCalls != null) {
                for (final tc in aiMessage.toolCalls!) {
                  if (tc.name == toolName && tc.isRunning) {
                    tc.isRunning = false;
                    tc.result = result;
                    break;
                  }
                }
              }
            });
            _scrollToBottom();
            break;

          case 'done':
            setState(() {
              aiMessage.isStreaming = false;
              _isLoading = false;
              _remainingQuota--;
            });
            _saveHistory(); // 保存历史记录
            break;

          case 'error':
            setState(() {
              aiMessage.content = event['message'] as String;
              aiMessage.isStreaming = false;
              _isLoading = false;
            });
            break;
        }
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          aiMessage.content = '发生错误：$error';
          aiMessage.isStreaming = false;
          _isLoading = false;
        });
      },
    );
  }

  /// 切换思考模式
  Future<void> _toggleThinkingMode(bool value) async {
    setState(() {
      _enableThinking = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_thinking_mode', value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('AI 助手'),
          ],
        ),
        actions: [
          // 思考模式开关
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.psychology,
                  size: 18,
                  color: _enableThinking
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '思考',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _enableThinking
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 24,
                  child: Switch(
                    value: _enableThinking,
                    onChanged: _toggleThinkingMode,
                    activeColor: theme.colorScheme.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          // 清空历史按钮
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空对话',
            onPressed: _messages.isEmpty ? null : () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('清空对话'),
                  content: const Text('确定要清空所有对话记录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () {
                        _clearHistory();
                        Navigator.pop(context);
                      },
                      child: const Text('清空'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 额度提示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bolt,
                  size: 14,
                  color: _remainingQuota > 5
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  '今日剩余 $_remainingQuota/20 次',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _remainingQuota > 5
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // 消息列表
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcomeState(theme)
                : _buildMessageList(theme),
          ),

          // 底部输入框
          _buildInputArea(theme),
        ],
      ),
    );
  }

  /// 欢迎状态
  Widget _buildWelcomeState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI 图标
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.tertiaryContainer,
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '你好，我是 AI 助手',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '可以帮你查询和分析点名数据',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            // 示例问题
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sampleQuestions.map((question) {
                return ActionChip(
                  label: Text(question),
                  onPressed: () {
                    _inputController.text = question;
                    _sendMessage();
                  },
                  avatar: Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// 消息列表
  Widget _buildMessageList(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message, theme);
      },
    );
  }

  /// 消息气泡
  Widget _buildMessageBubble(ChatMessage message, ThemeData theme) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            // AI 头像
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8, top: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
          // 消息内容
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.75 : 0.82),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isUser)
                    Text(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    _buildAiMessageContent(message, theme),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            // 用户头像
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.person,
                size: 16,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// AI 消息内容（包含思考过程、工具调用、Markdown 渲染）
  Widget _buildAiMessageContent(ChatMessage message, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 思考过程（可折叠）
        if (message.thinkingContent != null && message.thinkingContent!.isNotEmpty)
          _buildThinkingSection(message, theme),

        // 工具调用状态
        if (message.toolCalls != null && message.toolCalls!.isNotEmpty)
          ...message.toolCalls!.map((tc) => _buildToolCallCard(tc, theme)),

        // 正式回复内容
        if (message.content.isNotEmpty)
          MarkdownBody(
            data: message.content,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
              ),
              code: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                fontSize: 12,
              ),
              codeblockDecoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

        // 流式加载指示器
        if (message.isStreaming && message.content.isEmpty && message.thinkingContent == null && (message.toolCalls == null || message.toolCalls!.isEmpty))
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '思考中...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

        // 流式光标
        if (message.isStreaming && message.content.isNotEmpty)
          Text(
            '|',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  /// 思考过程折叠区域 - 简洁风格
  Widget _buildThinkingSection(ChatMessage message, ThemeData theme) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        final hasContent = message.thinkingContent != null &&
            message.thinkingContent!.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: Row(
                children: [
                  Text(
                    message.isStreaming ? '思考中' : '已思考',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                  if (message.isStreaming) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Icon(
                Icons.expand_more,
                size: 18,
                color: theme.colorScheme.primary.withOpacity(0.5),
              ),
              initiallyExpanded: false,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    message.thinkingContent ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 工具调用卡片
  Widget _buildToolCallCard(ToolCallInfo toolCall, ThemeData theme) {
    final displayName = _getToolDisplayName(toolCall.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (toolCall.isRunning)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            else
              Icon(
                Icons.check_circle,
                size: 14,
                color: theme.colorScheme.primary,
              ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                toolCall.isRunning
                    ? '正在查询$displayName...'
                    : '已查询$displayName',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取工具调用的友好名称
  String _getToolDisplayName(String toolName) {
    switch (toolName) {
      case 'query_members':
        return '人员信息';
      case 'query_member_detail':
        return '成员详情';
      case 'query_sessions':
        return '点名记录';
      case 'query_attendance_stats':
        return '出勤统计';
      case 'query_absent_members':
        return '缺勤排行';
      default:
        return '数据';
    }
  }

  /// 底部输入区域
  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          // Hero 输入框
          Expanded(
            child: Hero(
              tag: 'ai_input',
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: '输入你的问题...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 发送按钮
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isLoading || _inputController.text.trim().isEmpty
                  ? theme.colorScheme.surfaceContainerHighest
                  : theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: (_isLoading || _inputController.text.trim().isEmpty)
                  ? null
                  : _sendMessage,
              icon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Icon(
                      Icons.send_rounded,
                      color: (_isLoading || _inputController.text.trim().isEmpty)
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onPrimary,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
