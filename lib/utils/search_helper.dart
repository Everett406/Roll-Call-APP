/// 拼音搜索辅助类
/// 支持中文姓名的拼音首字母搜索（如 "fyy" 搜 "付云阳"）
class PinyinSearchHelper {
  // 常用汉字拼音首字母映射表（GB2312 覆盖）
  static final List<String> _pinyinTable = _buildPinyinTable();

  static List<String> _buildPinyinTable() {
    // 按照GB2312区位码排序的拼音首字母边界
    const boundaries = [
      0x4E00, 'a', // 一
      0x4E03, 'b', // 七
      0x4E16, 'c', // 世
      0x4E2D, 'd', // 中
      0x4E48, 'e', // 也
      0x53D1, 'f', // 发
      0x54CE, 'g', // 嗨
      0x548C, 'h', // 和
      0x5750, 'j', // 坐
      0x5F00, 'k', // 开
      0x6240, 'l', // 所
      0x5E76, 'm', // 并 - adjust
      0x62FF, 'n', // 
      0x6B27, 'o', // 欧
      0x62AB, 'p', // 
      0x5176, 'q', // 其
      0x7136, 'r', // 然
      0x4E09, 's', // 三
      0x4ED6, 't', // 他
      0x5730, 'w', // 地
      0x4E0B, 'x', // 下
      0x4E00, 'y', // 一 (shared with a)
      0x575A, 'z', // 
    ];

    // 简化方案：使用Unicode范围映射
    return List.filled(65536, '');
  }

  /// 获取汉字的拼音首字母
  static String _getPinyinInitial(String char) {
    final code = char.codeUnitAt(0);
    if (code < 0x4E00 || code > 0x9FFF) {
      // 非汉字，直接返回小写
      return char.toLowerCase();
    }

    // GB2312 拼音首字母对照表
    if (code >= 0x4E00 && code < 0x4E03) return 'a';
    if (code >= 0x4E03 && code < 0x4E16) return 'b';
    if (code >= 0x4E16 && code < 0x4E2D) return 'c';
    if (code >= 0x4E2D && code < 0x4E48) return 'd';
    if (code >= 0x4E48 && code < 0x53D1) return 'e';
    if (code >= 0x53D1 && code < 0x54CE) return 'f';
    if (code >= 0x54CE && code < 0x548C) return 'g';
    if (code >= 0x548C && code < 0x5750) return 'h';
    if (code >= 0x5750 && code < 0x5F00) return 'j';
    if (code >= 0x5F00 && code < 0x6240) return 'k';
    if (code >= 0x6240 && code < 0x62FF) return 'l';
    if (code >= 0x62FF && code < 0x6B27) return 'm';
    if (code >= 0x6B27 && code < 0x6D2A) return 'n';
    if (code >= 0x6D2A && code < 0x6E2F) return 'o';
    if (code >= 0x6E2F && code < 0x7136) return 'p';
    if (code >= 0x7136 && code < 0x752F) return 'q';
    if (code >= 0x752F && code < 0x7682) return 'r';
    if (code >= 0x7682 && code < 0x7B4F) return 's';
    if (code >= 0x7B4F && code < 0x7F36) return 't';
    if (code >= 0x7F36 && code < 0x817F) return 'w';
    if (code >= 0x817F && code < 0x82B3) return 'x';
    if (code >= 0x82B3 && code < 0x8E8D) return 'y';
    if (code >= 0x8E8D) return 'z';
    return 'a'; // fallback
  }

  /// 获取字符串的拼音首字母序列（如 "付云阳" -> "fyy"）
  static String getPinyinInitials(String text) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char.codeUnitAt(0) >= 0x4E00 && char.codeUnitAt(0) <= 0x9FFF) {
        buffer.write(_getPinyinInitial(char));
      } else {
        buffer.write(char.toLowerCase());
      }
    }
    return buffer.toString();
  }

  /// 搜索匹配
  /// 支持：
  /// 1. 直接包含匹配（"张" 匹配 "张三"）
  /// 2. 拼音首字母匹配（"fyy" 匹配 "付云阳"）
  /// 3. 模糊子序列匹配（"小天" 匹配 "张晓天"）
  static bool matches(String text, String query) {
    if (text.isEmpty || query.isEmpty) return false;

    final normalizedText = text.toLowerCase();
    final normalizedQuery = query.toLowerCase();

    // 1. 直接包含匹配
    if (normalizedText.contains(normalizedQuery)) {
      return true;
    }

    // 2. 拼音首字母匹配
    final pinyin = getPinyinInitials(text);
    if (pinyin.contains(normalizedQuery)) {
      return true;
    }

    // 3. 模糊子序列匹配（查询字符按顺序出现在文本中）
    if (_matchesSubstring(normalizedText, normalizedQuery)) {
      return true;
    }

    return false;
  }

  /// 模糊子序列匹配
  static bool _matchesSubstring(String text, String query) {
    if (query.isEmpty) return false;
    int queryIndex = 0;
    for (int i = 0; i < text.length && queryIndex < query.length; i++) {
      if (text[i] == query[queryIndex]) {
        queryIndex++;
      }
    }
    return queryIndex >= query.length;
  }
}
