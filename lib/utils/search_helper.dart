class PinyinSearchHelper {
  static bool matches(String text, String query) {
    if (text.isEmpty || query.isEmpty) return false;

    final normalizedText = text.toLowerCase();
    final normalizedQuery = query.toLowerCase();

    // 1. 直接包含匹配
    if (normalizedText.contains(normalizedQuery)) {
      return true;
    }

    // 2. 模糊匹配（查询是姓名的子串）
    // 比如输入 "小天" 可以匹配 "张晓天"
    if (_matchesSubstring(text, normalizedQuery)) {
      return true;
    }

    return false;
  }

  static bool _matchesSubstring(String text, String query) {
    // 如果查询是空，返回 false
    if (query.isEmpty) return false;

    // 将文本转为小写
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    // 检查查询中的每个字符是否按顺序出现在文本中
    int queryIndex = 0;
    for (int i = 0; i < lowerText.length && queryIndex < lowerQuery.length; i++) {
      if (lowerText[i] == lowerQuery[queryIndex]) {
        queryIndex++;
      }
    }

    return queryIndex >= lowerQuery.length;
  }

  static String getSearchKey(String text) {
    return text;
  }
}
