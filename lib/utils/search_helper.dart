import 'package:lpinyin/lpinyin.dart';

class PinyinSearchHelper {
  static bool matches(String text, String query) {
    if (text.isEmpty || query.isEmpty) return false;

    final normalizedText = text.toLowerCase();
    final normalizedQuery = query.toLowerCase();

    // 1. 直接包含匹配
    if (normalizedText.contains(normalizedQuery)) {
      return true;
    }

    // 2. 拼音首字母匹配
    final pinyin = PinyinHelper.getShortPinyin(text).toLowerCase();
    if (pinyin.contains(normalizedQuery)) {
      return true;
    }

    // 3. 每个字的首字母匹配（更宽松的匹配）
    if (_matchesFuzzyPinyin(text, normalizedQuery)) {
      return true;
    }

    // 4. 全拼音匹配
    final fullPinyin = PinyinHelper.getPinyin(text, separator: '').toLowerCase();
    if (fullPinyin.contains(normalizedQuery)) {
      return true;
    }

    return false;
  }

  static bool _matchesFuzzyPinyin(String text, String query) {
    final pinyinList = PinyinHelper.getPinyinArray(text);
    final queryChars = query.split('');

    int matchCount = 0;
    int queryIndex = 0;

    for (int i = 0; i < pinyinList.length && queryIndex < queryChars.length; i++) {
      final py = pinyinList[i].toLowerCase();
      if (py.startsWith(queryChars[queryIndex])) {
        matchCount++;
        queryIndex++;
      }
    }

    return queryIndex >= queryChars.length;
  }

  static String getSearchKey(String text) {
    final short = PinyinHelper.getShortPinyin(text).toLowerCase();
    final full = PinyinHelper.getPinyin(text, separator: '').toLowerCase();
    return '$text|$short|$full';
  }
}
