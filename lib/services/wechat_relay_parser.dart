import 'package:hive_flutter/hive_flutter.dart';
import '../models/member.dart';
import '../models/status_tag.dart';

/// 微信接龙解析结果
class RelayParseResult {
  final String rawLine;      // 原始行
  final String? name;        // 识别到的人名
  final String? memberId;    // 匹配到的成员ID
  final String status;       // 识别到的状态文本
  final String? matchedTagId; // 匹配到的标签ID
  final String? matchedTagName; // 匹配到的标签名
  final ParseStatus parseStatus; // 解析状态
  final String? currentTagId; // 当前标签ID（如果已有状态）
  final String? currentTagName; // 当前标签名

  RelayParseResult({
    required this.rawLine,
    this.name,
    this.memberId,
    required this.status,
    this.matchedTagId,
    this.matchedTagName,
    required this.parseStatus,
    this.currentTagId,
    this.currentTagName,
  });

  RelayParseResult copyWith({
    String? name,
    String? memberId,
    String? status,
    String? matchedTagId,
    String? matchedTagName,
    ParseStatus? parseStatus,
    String? currentTagId,
    String? currentTagName,
  }) {
    return RelayParseResult(
      rawLine: rawLine,
      name: name ?? this.name,
      memberId: memberId ?? this.memberId,
      status: status ?? this.status,
      matchedTagId: matchedTagId ?? this.matchedTagId,
      matchedTagName: matchedTagName ?? this.matchedTagName,
      parseStatus: parseStatus ?? this.parseStatus,
      currentTagId: currentTagId ?? this.currentTagId,
      currentTagName: currentTagName ?? this.currentTagName,
    );
  }
}

enum ParseStatus {
  matched,      // 完全匹配
  statusMissing, // 状态未匹配
  nameMissing,   // 人名未找到
  alreadySet,    // 已有状态（冲突）
}

/// 微信接龙解析服务
class WechatRelayParser {
  static const String _boxName = 'status_mapping';

  /// 加载保存的映射
  static Map<String, String> loadMappings() {
    try {
      final box = Hive.box<String>(_boxName);
      final mapping = <String, String>{};
      for (var key in box.keys) {
        final value = box.get(key);
        if (value != null) {
          mapping[key] = value;
        }
      }
      return mapping;
    } catch (e) {
      return {};
    }
  }

  /// 保存映射
  static Future<void> saveMapping(String statusText, String tagId) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put(statusText, tagId);
  }

  /// 删除映射
  static Future<void> removeMapping(String statusText) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.delete(statusText);
  }

  /// 解析微信接龙文本
  static List<RelayParseResult> parse(
    String text,
    List<Member> members,
    List<StatusTag> tags,
    Map<String, String> mappings, // statusText -> tagId
    Map<String, String> currentStatuses, // memberId -> tagId
  ) {
    final results = <RelayParseResult>[];
    final lines = text.split('\n');

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // 保存原始行
      final rawLine = line;

      // 去掉序号（"1. " 或 "1、 "）
      line = line.replaceFirst(RegExp(r'^\d+[.、]\s*'), '');
      if (line.isEmpty) continue;

      // 跳过纯数字行（如第一行的"1"）
      if (!RegExp(r'[\u4e00-\u9fa5]').hasMatch(line)) continue;

      // 跳过只有1-2个汉字的行（可能是标题）
      if (RegExp(r'^[\u4e00-\u9fa5]{1,2}$').hasMatch(line)) continue;

      final result = _parseLine(line, members, tags, mappings, currentStatuses);
      results.add(result);
    }

    return results;
  }

  static RelayParseResult _parseLine(
    String line,
    List<Member> members,
    List<StatusTag> tags,
    Map<String, String> mappings,
    Map<String, String> currentStatuses,
  ) {
    // 1. 识别人名（精确匹配 + 最长匹配）
    String? matchedName;
    String? matchedMemberId;

    // 按名字长度降序排列（优先匹配更长的名字）
    final sortedMembers = List<Member>.from(members)
      ..sort((a, b) => b.name.length.compareTo(a.name.length));

    for (var member in sortedMembers) {
      // 在文本中精确查找人名
      if (line.contains(member.name)) {
        matchedName = member.name;
        matchedMemberId = member.id;
        break;
      }
    }

    if (matchedName == null) {
      return RelayParseResult(
        rawLine: line,
        name: null,
        memberId: null,
        status: '',
        parseStatus: ParseStatus.nameMissing,
      );
    }

    // 2. 提取状态文本（人名后面的部分）
    int nameEnd = line.indexOf(matchedName) + matchedName.length;
    String statusText = line.substring(nameEnd).trim();

    // 去掉手机号（11位数字）
    statusText = statusText.replaceFirst(RegExp(r'\d{11}'), '');
    // 去掉数字前缀（如"2405"）
    statusText = statusText.replaceFirst(RegExp(r'^\d+'), '');
    statusText = statusText.trim();

    // 3. 查找匹配的状态
    String? matchedTagId;
    String? matchedTagName;

    for (var tag in tags) {
      if (statusText.contains(tag.name) || tag.name.contains(statusText)) {
        matchedTagId = tag.id;
        matchedTagName = tag.name;
        break;
      }
    }

    // 如果没有直接匹配，尝试从映射中查找
    if (matchedTagId == null && mappings.containsKey(statusText)) {
      final mappedTagId = mappings[statusText];
      final tag = tags.firstWhere(
        (t) => t.id == mappedTagId,
        orElse: () => StatusTag(id: '', name: '', colorValue: 0),
      );
      if (tag.id.isNotEmpty) {
        matchedTagId = tag.id;
        matchedTagName = tag.name;
      }
    }

    // 4. 检查是否有当前状态
    String? currentTagId;
    String? currentTagName;
    if (currentStatuses.containsKey(matchedMemberId)) {
      final curTagId = currentStatuses[matchedMemberId];
      final tag = tags.firstWhere(
        (t) => t.id == curTagId,
        orElse: () => StatusTag(id: '', name: '', colorValue: 0),
      );
      if (tag.id.isNotEmpty) {
        currentTagId = tag.id;
        currentTagName = tag.name;
      }
    }

    // 5. 确定解析状态
    ParseStatus status;
    if (currentTagId != null && currentTagId != matchedTagId) {
      status = ParseStatus.alreadySet;
    } else if (matchedTagId != null) {
      status = ParseStatus.matched;
    } else {
      status = ParseStatus.statusMissing;
    }

    return RelayParseResult(
      rawLine: line,
      name: matchedName,
      memberId: matchedMemberId,
      status: statusText,
      matchedTagId: matchedTagId,
      matchedTagName: matchedTagName,
      parseStatus: status,
      currentTagId: currentTagId,
      currentTagName: currentTagName,
    );
  }
}
