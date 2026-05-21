import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 发布信息模型
class ReleaseInfo {
  final String version;
  final String tagName;
  final String name;
  final String body;
  final DateTime publishedAt;
  final String? downloadUrl;
  final int? downloadSize;

  ReleaseInfo({
    required this.version,
    required this.tagName,
    required this.name,
    required this.body,
    required this.publishedAt,
    this.downloadUrl,
    this.downloadSize,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    String? apkUrl;
    int? apkSize;

    // 从 assets 中查找 APK 文件
    final assets = json['assets'] as List<dynamic>?;
    if (assets != null) {
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          apkSize = asset['size'] as int?;
          break;
        }
      }
    }

    return ReleaseInfo(
      version: json['tag_name'] as String? ?? '',
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? '') ?? DateTime.now(),
      downloadUrl: apkUrl,
      downloadSize: apkSize,
    );
  }
}

/// 更新服务类
class UpdateService {
  static const String repoOwner = 'Everett406';
  static const String repoName = 'Roll-Call-APP';
  static const String _githubApiUrl = 'https://api.github.com/repos';
  static const _channel = MethodChannel('com.example.roll_call_app/update');

  // Dio 实例 - 仅用于 API 请求
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 300),
    ),
  );

  /// 获取当前应用版本号
  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// 解析版本号为可比较的列表
  static List<int> _parseVersion(String version) {
    String cleanVersion = version.toLowerCase().trim();
    if (cleanVersion.startsWith('v')) {
      cleanVersion = cleanVersion.substring(1);
    }
    final parts = cleanVersion.split('+')[0].split('.');
    return parts.map((part) => int.tryParse(part) ?? 0).toList();
  }

  /// 比较两个版本号
  static int compareVersions(String v1, String v2) {
    final parts1 = _parseVersion(v1);
    final parts2 = _parseVersion(v2);
    final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < maxLength; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 != p2) return p1 - p2;
    }
    return 0;
  }

  /// 检查是否有新版本
  static Future<ReleaseInfo?> checkUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();
      final response = await _dio.get(
        '$_githubApiUrl/$repoOwner/$repoName/releases/latest',
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
        ),
      );

      if (response.statusCode != 200) return null;

      final releaseInfo = ReleaseInfo.fromJson(response.data as Map<String, dynamic>);
      final comparison = compareVersions(releaseInfo.version, currentVersion);

      return comparison > 0 ? releaseInfo : null;
    } on DioException catch (e) {
      debugPrint('检查更新网络错误: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('检查更新错误: $e');
      return null;
    }
  }

  /// 使用系统 DownloadManager 下载并安装
  static Future<bool> downloadAndInstall(String url, {String title = '下载更新'}) async {
    try {
      final result = await _channel.invokeMethod('downloadAndInstall', {
        'url': url,
        'title': title,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('下载失败: ${e.message}');
      return false;
    }
  }

  /// 保存自动检查更新设置
  static Future<void> setAutoCheckUpdate(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_check_update', value);
  }

  /// 读取自动检查更新设置
  static Future<bool> getAutoCheckUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('auto_check_update') ?? false;
  }
}
