import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

/// ============================================================
/// Data Backup & Restore Service
/// ============================================================
class BackupService {
  static const String _backupVersion = '1.0';

  static final _boxNames = [
    'members',
    'groups',
    'statusTags',
    'sessions',
    'checkIns',
    'operationLogs',
  ];

  /// Export all data to a JSON file and share it
  static Future<String?> exportToJson() async {
    try {
      final data = await _collectAllData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/rollcall_backup_$timestamp.json');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: '点到为止 数据备份',
        text: '点到为止数据备份文件',
      );

      return file.path;
    } catch (e) {
      debugPrint('Export error: $e');
      return null;
    }
  }

  /// Import data from a JSON file selected by user
  static Future<(bool, String, Map<String, int>)> importFromJson({
    required bool merge,
  }) async {
    final stats = <String, int>{
      'members': 0,
      'groups': 0,
      'tags': 0,
      'sessions': 0,
      'checkIns': 0,
      'logs': 0,
    };

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return (false, '未选择文件', stats);
      }

      final file = File(result.files.first.path!);
      final jsonStr = await file.readAsString();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Validate
      final version = data['version'] as String?;
      if (version == null || version != _backupVersion) {
        return (false, '不兼容的备份文件版本: $version', stats);
      }

      if (!merge) {
        await _clearAllBoxes();
      }

      // Import each box
      for (final boxName in _boxNames) {
        final items = data[boxName] as List<dynamic>?;
        if (items == null || items.isEmpty) continue;

        final box = await Hive.openBox(boxName);
        for (final item in items) {
          final map = item as Map<String, dynamic>;
          final key = map['id'] as String? ?? map['key'] as String?;
          if (key == null) continue;
          if (merge && box.containsKey(key)) continue;
          await box.put(key, map);
          final shortName = _shortName(boxName);
          if (stats.containsKey(shortName)) {
            stats[shortName] = stats[shortName]! + 1;
          }
        }
      }

      final total = stats.values.reduce((a, b) => a + b);
      final msg = '导入成功！共恢复 $total 条记录';
      return (true, msg, stats);
    } catch (e) {
      debugPrint('Import error: $e');
      return (false, '导入失败: $e', stats);
    }
  }

  /// Collect all data from Hive boxes as raw maps
  static Future<Map<String, dynamic>> _collectAllData() async {
    final data = <String, dynamic>{
      'version': _backupVersion,
      'app': 'rollcall',
      'exportedAt': DateTime.now().toIso8601String(),
    };

    for (final boxName in _boxNames) {
      try {
        final box = await Hive.openBox(boxName);
        final items = <Map<String, dynamic>>[];
        for (final key in box.keys) {
          final value = box.get(key);
          if (value is Map) {
            items.add(Map<String, dynamic>.from(value));
          } else if (value != null) {
            // Try to get raw Hive data
            items.add({'id': key, 'value': value.toString()});
          }
        }
        data[boxName] = items;
      } catch (e) {
        debugPrint('Error reading box $boxName: $e');
        data[boxName] = [];
      }
    }

    return data;
  }

  static Future<void> _clearAllBoxes() async {
    for (final boxName in _boxNames) {
      try {
        final box = await Hive.openBox(boxName);
        await box.clear();
      } catch (_) {}
    }
  }

  static String _shortName(String boxName) {
    switch (boxName) {
      case 'members': return 'members';
      case 'groups': return 'groups';
      case 'statusTags': return 'tags';
      case 'sessions': return 'sessions';
      case 'checkIns': return 'checkIns';
      case 'operationLogs': return 'logs';
      default: return boxName;
    }
  }
}
