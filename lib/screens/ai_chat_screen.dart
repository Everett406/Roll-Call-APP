import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_service.dart';
import '../services/ai_data_provider.dart';
import '../models/ai_conversation.dart';
import 'ai_conversations_screen.dart' show showAiConversationsBottomSheet;
import 'session_detail_screen.dart';

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
  /// 当前对话（从对话列表传递过来）
  final AiConversation? conversation;
  /// 初始消息（从统计页传递过来）
  final String? initialMessage;

  const AiChatScreen({
    super.key,
    this.conversation,
    this.initialMessage,
  });

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

  // 等待动画相关
  DateTime? _lastContentTime;
  bool _showWaiting = false;
  Timer? _waitingTimer;

  // 当前对话
  AiConversation? _currentConversation;

  @override
  void initState() {
    super.initState();
    // 监听输入框文本变化以更新发送按钮状态
    _inputController.addListener(() {
      setState(() {});
    });
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

    // 初始化对话
    if (widget.conversation != null) {
      // 使用传入的对话
      _currentConversation = widget.conversation;
      // 加载对话中的消息
      _loadConversationMessages(widget.conversation!);
    } else {
      // 创建新对话
      _currentConversation = AiConversation.create();
    }

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

  /// 从对话中加载消息
  void _loadConversationMessages(AiConversation conversation) {
    if (conversation.messages.isNotEmpty) {
      setState(() {
        _messages.addAll(conversation.messages.map((m) => ChatMessage(
          id: m['id'] as String,
          isUser: m['isUser'] as bool,
          content: m['content'] as String,
          thinkingContent: m['thinkingContent'] as String?,
          timestamp: DateTime.parse(m['timestamp'] as String),
        )));
      });
    }
  }

  /// 获取当前对话标题
  String _getConversationTitle() {
    if (_currentConversation == null) return 'AI 助手';
    
    // 如果是"新对话"且已有消息，使用第一条用户消息作为标题
    if (_currentConversation!.title == '新对话' && _messages.isNotEmpty) {
      final firstUserMessage = _messages.firstWhere(
        (m) => m.isUser,
        orElse: () => _messages.first,
      );
      final content = firstUserMessage.content;
      if (content.length > 20) {
        return content.substring(0, 20);
      }
      return content;
    }
    
    return _currentConversation!.title;
  }

  /// 保存当前对话到对话列表
  Future<void> _saveConversation() async {
    if (_currentConversation == null) return;

    // 更新对话
    final updated = _currentConversation!.copyWith(
      messages: _messages.map((m) => {
        'id': m.id,
        'isUser': m.isUser,
        'content': m.content,
        'thinkingContent': m.thinkingContent,
        'timestamp': m.timestamp.toIso8601String(),
      }).toList(),
      updatedAt: DateTime.now(),
      // 如果是第一条用户消息，用它作为标题（截断前20字）
      title: _currentConversation!.title == '新对话' && _messages.isNotEmpty
          ? () {
              final firstUserMessage = _messages.firstWhere(
                (m) => m.isUser,
                orElse: () => _messages.first,
              );
              final content = firstUserMessage.content;
              return content.substring(0, min(20, content.length));
            }()
          : _currentConversation!.title,
    );

    // 保存到对话列表
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('ai_conversations');
    List<AiConversation> conversations = [];
    if (json != null) {
      final List<dynamic> list = jsonDecode(json);
      conversations = list.map((e) => AiConversation.fromJson(e)).toList();
    }

    // 更新或添加
    final index = conversations.indexWhere((c) => c.id == updated.id);
    if (index >= 0) {
      conversations[index] = updated;
    } else {
      conversations.insert(0, updated);
    }

    // 只保留最近 50 个对话
    if (conversations.length > 50) {
      conversations = conversations.sublist(0, 50);
    }

    await prefs.setString('ai_conversations', jsonEncode(conversations.map((c) => c.toJson()).toList()));
    
    // 更新当前对话引用
    _currentConversation = updated;
  }

  /// 清空历史记录
  Future<void> _clearHistory() async {
    setState(() {
      _messages.clear();
    });
    
    // 更新对话（清空消息）
    if (_currentConversation != null) {
      final updated = _currentConversation!.copyWith(
        messages: [],
        updatedAt: DateTime.now(),
      );
      
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('ai_conversations');
      if (json != null) {
        final List<dynamic> list = jsonDecode(json);
        final conversations = list.map((e) => AiConversation.fromJson(e)).toList();
        final index = conversations.indexWhere((c) => c.id == updated.id);
        if (index >= 0) {
          conversations[index] = updated;
          await prefs.setString('ai_conversations', jsonEncode(conversations.map((c) => c.toJson()).toList()));
        }
      }
      
      _currentConversation = updated;
    }
  }

  /// 启动等待检测定时器
  void _startWaitingTimer() {
    _waitingTimer?.cancel();
    _lastContentTime = DateTime.now();
    _showWaiting = false;

    _waitingTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) {
        _waitingTimer?.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_lastContentTime!).inMilliseconds;
      final shouldShow = elapsed > 1000;
      if (shouldShow != _showWaiting) {
        setState(() {
          _showWaiting = shouldShow;
        });
      }
    });
  }

  /// 停止等待检测定时器
  void _stopWaitingTimer() {
    _waitingTimer?.cancel();
    _waitingTimer = null;
    _showWaiting = false;
  }

  /// 重置等待时间（收到新内容时调用）
  void _resetWaitingTime() {
    _lastContentTime = DateTime.now();
    if (_showWaiting) {
      setState(() {
        _showWaiting = false;
      });
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _waitingTimer?.cancel();
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

    // 启动等待检测定时器
    _startWaitingTimer();

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
            _resetWaitingTime();
            setState(() {
              aiMessage.thinkingContent =
                  (aiMessage.thinkingContent ?? '') + (event['content'] as String);
            });
            _scrollToBottom();
            break;

          case 'content':
            _resetWaitingTime();
            setState(() {
              aiMessage.content += event['content'] as String;
            });
            _scrollToBottom();
            break;

          case 'tool_call':
            _resetWaitingTime();
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
            _resetWaitingTime();
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
            _stopWaitingTimer();
            setState(() {
              aiMessage.isStreaming = false;
              _isLoading = false;
              _remainingQuota--;
            });
            _saveConversation(); // 保存对话
            break;

          case 'error':
            _stopWaitingTimer();
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
        _stopWaitingTimer();
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

  /// 处理深度链接
  Future<void> _handleDeepLink(String uri) async {
    final parts = uri.replaceFirst('rollcall://', '').split('/');
    if (parts.length >= 2) {
      final type = parts[0];
      final id = parts[1];
      switch (type) {
        case 'session':
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionDetailScreen(sessionId: id),
            ),
          );
          break;
        case 'member':
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('成员详情（ID: $id）- 功能开发中')),
          );
          break;
      }
    }
  }

  /// 判断内容是否为 HTML
  bool _isHtmlContent(String content) {
    final trimmed = content.trim();
    return trimmed.startsWith('<html>') || trimmed.contains('<html>');
  }

  /// 获取日期分组标签
  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return '今天';
    } else if (messageDate == yesterday) {
      return '昨天';
    } else {
      return '${date.month}月${date.day}日';
    }
  }

  /// 获取消息时间字符串（如 "14:30"）
  String _getMessageTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// 构建带日期分组的消息列表项
  List<Widget> _buildGroupedMessages(ThemeData theme) {
    final List<Widget> widgets = [];
    DateTime? lastDate;

    for (int i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      final messageDate = DateTime(
        message.timestamp.year,
        message.timestamp.month,
        message.timestamp.day,
      );

      // 如果日期不同，添加日期标签
      if (lastDate == null || messageDate != lastDate) {
        lastDate = messageDate;
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getDateLabel(message.timestamp),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }

      // 添加消息气泡
      widgets.add(_buildMessageBubble(message, theme));
    }

    return widgets;
  }

  /// 等待动画 - 三个跳动的点
  Widget _buildWaitingDots(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.3 + value * 0.7),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.history),
          tooltip: '历史对话',
          onPressed: () async {
            final result = await showAiConversationsBottomSheet(context);
            if (result is AiConversation) {
              setState(() {
                _messages.clear();
                _currentConversation = result;
                _loadConversationMessages(result);
              });
            }
          },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _getConversationTitle(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: _buildGroupedMessages(theme),
    );
  }

  /// 消息气泡
  Widget _buildMessageBubble(ChatMessage message, ThemeData theme) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI 消息：无头像，简洁风格
              if (!isUser)
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: _buildAiMessageContent(message, theme),
                  ),
                ),
              // 用户消息：右侧蓝色气泡
              if (isUser) ...[
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(4),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Text(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          // 时间戳
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              _getMessageTime(message.timestamp),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// AI 消息内容（包含思考过程、工具调用、Markdown/HTML 渲染）
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
          _isHtmlContent(message.content)
              ? _buildHtmlContent(message.content, theme)
              : _buildMarkdownContent(message.content, theme),

        // 流式加载指示器（初始等待）
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

        // 等待动画（流式过程中超过1秒无新内容）
        if (message.isStreaming && message.content.isNotEmpty && _showWaiting)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildWaitingDots(theme),
          ),

        // 流式光标
        if (message.isStreaming && message.content.isNotEmpty && !_showWaiting)
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

  /// Markdown 内容渲染（支持深度链接）
  Widget _buildMarkdownContent(String content, ThemeData theme) {
    return MarkdownBody(
      data: content,
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null && href.startsWith('rollcall://')) {
          _handleDeepLink(href);
        } else if (href != null) {
          launchUrl(Uri.parse(href));
        }
      },
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
    );
  }

  /// HTML 内容渲染
  Widget _buildHtmlContent(String content, ThemeData theme) {
    return Html(
      data: content,
      style: {
        'body': Style(
          fontSize: FontSize(theme.textTheme.bodyMedium?.fontSize ?? 14),
          lineHeight: LineHeight(1.6),
          color: theme.colorScheme.onSurface,
        ),
        'a': Style(
          color: theme.colorScheme.primary,
          textDecoration: TextDecoration.underline,
        ),
      },
      onLinkTap: (url, _, __) {
        if (url != null && url.startsWith('rollcall://')) {
          _handleDeepLink(url);
        } else if (url != null) {
          launchUrl(Uri.parse(url));
        }
      },
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hero 输入框
          Expanded(
            child: Hero(
              tag: 'ai_input',
              child: Material(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  alignment: Alignment.centerLeft,
                  child: TextField(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: '输入你的问题...',
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 发送按钮
          Material(
            color: _isLoading || _inputController.text.trim().isEmpty
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: (_isLoading || _inputController.text.trim().isEmpty)
                  ? null
                  : _sendMessage,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                child: _isLoading
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
          ),
        ],
      ),
    );
  }
}
