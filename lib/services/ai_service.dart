import 'dart:convert';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/check_in.dart';

/// AI 服务 - 管理对话、流式请求、工具调用、限流
class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  static const String _baseUrl = 'https://api.siliconflow.cn/v1/chat/completions';
  static const String _model = 'Pro/moonshotai/Kimi-K2.6';
  static const int _dailyLimit = 20;
  static const String _usageKey = 'ai_daily_usage';
  static const String _usageDateKey = 'ai_usage_date';

  // 加密后的 Key（XOR + Base64）
  static const String _encryptedKey = 'dGY+e2d4VE1hb35meHdGR2N7YW1/d01YaH5/e3Z8QFNgZ3tydntOU3V5d3N8ZU9RY2Rm';

  String _getApiKey() {
    // 简单 XOR 解密
    const key = [7, 13, 19, 23, 29, 31, 37, 41];
    String encoded = _encryptedKey;
    List<int> bytes = base64Decode(encoded);
    String result = '';
    for (int i = 0; i < bytes.length; i++) {
      result += String.fromCharCode(bytes[i] ^ key[i % key.length]);
    }
    return result;
  }

  final Dio _dio = Dio();

  /// 获取今日剩余额度
  Future<int> getRemainingQuota() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString(_usageDateKey);
    final used = prefs.getInt(_usageKey) ?? 0;

    if (savedDate != today) {
      return _dailyLimit; // 新的一天，重置
    }
    return _dailyLimit - used;
  }

  /// 检查是否有额度
  Future<bool> hasQuota() async {
    return await getRemainingQuota() > 0;
  }

  /// 消耗一次额度
  Future<void> _consumeQuota() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = prefs.getString(_usageDateKey);
    var used = prefs.getInt(_usageKey) ?? 0;

    if (savedDate != today) {
      used = 0;
      await prefs.setString(_usageDateKey, today);
    }
    await prefs.setInt(_usageKey, used + 1);
  }

  /// 构建系统提示词
  String _buildSystemPrompt({bool enableTools = true}) {
    String prompt = '''你是"点到为止"应用的 AI 助手。你可以帮助用户查询和分析点名相关数据。

应用功能：
- 人员管理：管理学生/成员信息
- 点名签到：记录每次点名的出勤情况
- 出勤统计：统计个人和整体的出勤率
- 生日提醒：记录和提醒成员生日

请用简洁友好的中文回答问题。如果涉及数据查询，请使用提供的工具。''';

    if (enableTools) {
      prompt += '\n\n你可以使用以下工具来查询应用内的数据。';
    }
    return prompt;
  }

  /// 构建工具定义
  List<Map<String, dynamic>> _buildTools() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'query_members',
          'description': '查询人员信息列表，可按姓名搜索',
          'parameters': {
            'type': 'object',
            'properties': {
              'keyword': {
                'type': 'string',
                'description': '搜索关键词（姓名），不传则返回全部',
              },
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'query_member_detail',
          'description': '查询某个成员的详细信息，包括出勤统计',
          'parameters': {
            'type': 'object',
            'properties': {
              'name': {
                'type': 'string',
                'description': '成员姓名',
              },
            },
            'required': ['name'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'query_sessions',
          'description': '查询点名记录列表',
          'parameters': {
            'type': 'object',
            'properties': {
              'limit': {
                'type': 'integer',
                'description': '返回最近N条记录，默认10',
              },
            },
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'query_attendance_stats',
          'description': '查询出勤率统计数据',
          'parameters': {
            'type': 'object',
            'properties': {
              'period': {
                'type': 'string',
                'enum': ['week', 'month', 'all'],
                'description': '统计周期：week=本周, month=本月, all=全部',
              },
            },
            'required': ['period'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'query_absent_members',
          'description': '查询缺勤最多的成员排行',
          'parameters': {
            'type': 'object',
            'properties': {
              'limit': {
                'type': 'integer',
                'description': '返回前N名，默认5',
              },
            },
          },
        },
      },
    ];
  }

  /// 执行工具调用
  Future<String> executeToolCall(String name, Map<String, dynamic> arguments) async {
    // 这里需要访问应用数据，通过回调获取
    if (_dataProvider != null) {
      return await _dataProvider!(name, arguments);
    }
    return '数据不可用，请稍后再试。';
  }

  // 数据提供者回调
  Future<String> Function(String toolName, Map<String, dynamic> args)? _dataProvider;

  void setDataProvider(Future<String> Function(String, Map<String, dynamic>) provider) {
    _dataProvider = provider;
  }

  /// 流式对话（支持工具调用循环）
  /// 返回一个 Stream，事件类型：
  /// - {'type': 'thinking', 'content': '...'}  思考过程
  /// - {'type': 'content', 'content': '...'}  回复内容
  /// - {'type': 'tool_call', 'name': '...', 'args': {...}}  工具调用
  /// - {'type': 'tool_result', 'name': '...', 'result': '...'}  工具结果
  /// - {'type': 'done'}  完成
  /// - {'type': 'error', 'message': '...'}  错误
  Stream<Map<String, dynamic>> chatStream({
    required String userMessage,
    required List<Map<String, dynamic>> history,
    bool enableThinking = true,
    bool enableTools = true,
  }) async* {
    if (!await hasQuota()) {
      yield {'type': 'error', 'message': '今日 AI 使用次数已用完（每日限 ${_dailyLimit} 次），明天再来吧~'};
      return;
    }

    // 构建消息列表
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _buildSystemPrompt(enableTools: enableTools)},
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    final tools = enableTools ? _buildTools() : null;
    int maxIterations = 5; // 最多5轮工具调用
    int iteration = 0;

    while (iteration < maxIterations) {
      iteration++;
      String? functionName;
      Map<String, dynamic>? functionArgs;
      String thinkingContent = '';
      String contentContent = '';

      try {
        final response = await _dio.post(
          _baseUrl,
          options: Options(
            headers: {
              'Authorization': 'Bearer ${_getApiKey()}',
              'Content-Type': 'application/json',
            },
            responseType: ResponseType.stream,
          ),
          data: jsonEncode({
            'model': _model,
            'messages': messages,
            'stream': true,
            'tools': tools,
            ...(enableThinking ? {'enable_thinking': true} : {}),
          }),
        );

        // 解析 SSE 流
        final stream = response.data.stream as Stream<List<int>>;
        final transformer = StreamTransformer<List<int>, String>.fromHandlers(
          handleData: (data, sink) {
            sink.add(utf8.decode(data));
          },
        );

        String buffer = '';
        await for (final chunk in stream.transform(transformer)) {
          buffer += chunk;
          // 按行分割处理 SSE
          while (buffer.contains('\n')) {
            final index = buffer.indexOf('\n');
            final line = buffer.substring(0, index).trim();
            buffer = buffer.substring(index + 1);

            if (line.isEmpty || !line.startsWith('data: ')) continue;
            final data = line.substring(6).trim();
            if (data == '[DONE]') continue;

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final choice = (json['choices'] as List).first as Map<String, dynamic>;
              final delta = choice['delta'] as Map<String, dynamic>? ?? {};
              final finishReason = choice['finish_reason'];

              // 思考内容
              if (delta.containsKey('reasoning_content') && delta['reasoning_content'] != null) {
                thinkingContent += delta['reasoning_content'] as String;
                yield {'type': 'thinking', 'content': delta['reasoning_content'] as String};
              }

              // 正式回复内容
              if (delta.containsKey('content') && delta['content'] != null) {
                contentContent += delta['content'] as String;
                yield {'type': 'content', 'content': delta['content'] as String};
              }

              // 工具调用
              if (delta.containsKey('tool_calls') && delta['tool_calls'] != null) {
                for (final tc in (delta['tool_calls'] as List)) {
                  final tcMap = tc as Map<String, dynamic>;
                  final function = tcMap['function'] as Map<String, dynamic>;
                  functionName ??= function['name'] as String;
                  if (function['arguments'] != null) {
                    functionArgs ??= {};
                    final argsStr = function['arguments'] as String;
                    try {
                      functionArgs = jsonDecode(argsStr) as Map<String, dynamic>;
                    } catch (_) {
                      functionArgs = {'raw': argsStr};
                    }
                  }
                }
              }

              // 检查是否完成
              if (finishReason == 'tool_calls' || finishReason == 'stop') {
                break;
              }
            } catch (_) {
              // 跳过解析失败的行
            }
          }
        }

        // 处理工具调用
        if (functionName != null && functionArgs != null) {
          yield {
            'type': 'tool_call',
            'name': functionName,
            'args': functionArgs,
          };

          // 执行工具
          final result = await executeToolCall(functionName, functionArgs);
          yield {
            'type': 'tool_result',
            'name': functionName,
            'result': result,
          };

          // 将工具结果加入消息，继续对话
          messages.add({
            'role': 'assistant',
            'content': contentContent,
            'tool_calls': [
              {
                'id': 'call_${DateTime.now().millisecondsSinceEpoch}',
                'type': 'function',
                'function': {
                  'name': functionName,
                  'arguments': jsonEncode(functionArgs),
                },
              }
            ],
          });
          messages.add({
            'role': 'tool',
            'tool_call_id': 'call_${DateTime.now().millisecondsSinceEpoch}',
            'content': result,
          });

          // 继续循环，让模型处理工具结果
          continue;
        }

        // 正常完成
        await _consumeQuota();
        yield {'type': 'done'};
        return;

      } on DioException catch (e) {
        yield {'type': 'error', 'message': '网络请求失败：${e.message}'};
        return;
      } catch (e) {
        yield {'type': 'error', 'message': '发生错误：$e'};
        return;
      }
    }

    // 超过最大迭代次数
    yield {'type': 'done'};
  }
}
