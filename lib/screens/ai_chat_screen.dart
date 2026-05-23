import 'dart:async';
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

  /// 思考过程折叠区域
  Widget _buildThinkingSection(ChatMessage message, ThemeData theme) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        final isExpanded = message.thinkingContent != null &&
            message.thinkingContent!.isNotEmpty &&
            !message.isStreaming;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              // 使用外层 setState 来触发重建
              // 由于 thinkingContent 本身不变，我们需要一个本地状态
            },
            borderRadius: BorderRadius.circular(8),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 4),
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Icon(
                Icons.psychology,
                size: 16,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
              title: Text(
                message.isStreaming ? '正在思考...' : '思考过程',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              trailing: message.isStreaming
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                    )
                  : null,
              initiallyExpanded: false,
              onExpansionChanged: (expanded) {
                setLocalState(() {});
              },
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
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
