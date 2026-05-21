import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// 下载进度模型
class DownloadProgress {
  final int received;
  final int total;
  final double progress;
  final String status;

  DownloadProgress({
    required this.received,
    required this.total,
    required this.progress,
    required this.status,
  });
}

/// 更新服务类
class UpdateService {
  static const String repoOwner = 'Everett406';
  static const String repoName = 'Roll-Call-APP';
  static const String _githubApiUrl = 'https://api.github.com/repos';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );

  /// 获取当前应用版本号
  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// 获取当前应用版本号（包含 build number）
  static Future<String> getCurrentVersionWithBuild() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return '${packageInfo.version}+${packageInfo.buildNumber}';
  }

  /// 解析版本号为可比较的列表
  /// 支持格式: "1.2.3" 或 "v1.2.3"
  static List<int> _parseVersion(String version) {
    // 移除前缀 'v' 或 'V'
    String cleanVersion = version.toLowerCase().trim();
    if (cleanVersion.startsWith('v')) {
      cleanVersion = cleanVersion.substring(1);
    }

    // 分割版本号
    final parts = cleanVersion.split('+')[0].split('.');
    return parts.map((part) => int.tryParse(part) ?? 0).toList();
  }

  /// 比较两个版本号
  /// 返回值: >0 表示 v1 > v2, =0 表示相等, <0 表示 v1 < v2
  static int compareVersions(String v1, String v2) {
    final parts1 = _parseVersion(v1);
    final parts2 = _parseVersion(v2);

    final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;

    for (int i = 0; i < maxLength; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;

      if (p1 != p2) {
        return p1 - p2;
      }
    }

    return 0;
  }

  /// 检查是否有新版本
  /// 返回 ReleaseInfo 表示有新版本，返回 null 表示已是最新或检查失败
  static Future<ReleaseInfo?> checkUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();

      final response = await _dio.get(
        '$_githubApiUrl/$repoOwner/$repoName/releases/latest',
        options: Options(
          headers: {
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );

      if (response.statusCode != 200) {
        debugPrint('检查更新失败: HTTP ${response.statusCode}');
        return null;
      }

      final releaseInfo = ReleaseInfo.fromJson(response.data as Map<String, dynamic>);

      // 比较版本号
      final comparison = compareVersions(releaseInfo.version, currentVersion);

      if (comparison > 0) {
        // 有新版本
        return releaseInfo;
      } else {
        // 已是最新版本
        return null;
      }
    } on DioException catch (e) {
      debugPrint('检查更新网络错误: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('检查更新错误: $e');
      return null;
    }
  }

  /// 请求必要的权限
  static Future<bool> requestPermissions() async {
    // Android 10 及以上不需要 WRITE_EXTERNAL_STORAGE 权限
    // 但 REQUEST_INSTALL_PACKAGES 是必须的
    if (Platform.isAndroid) {
      // 检查安装权限
      final installStatus = await Permission.requestInstallPackages.status;
      if (!installStatus.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        if (!result.isGranted) {
          return false;
        }
      }

      // Android 9 及以下需要存储权限
      if (Platform.version.contains('28') ||
          Platform.version.contains('27') ||
          Platform.version.contains('26') ||
          Platform.version.contains('25')) {
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          final result = await Permission.storage.request();
          if (!result.isGranted) {
            return false;
          }
        }
      }
    }

    return true;
  }

  /// 获取下载目录路径
  static Future<String> getDownloadPath() async {
    if (Platform.isAndroid) {
      // 使用应用私有目录，不需要额外权限
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final downloadDir = Directory('${directory.path}/updates');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir.path;
      }
    }

    // 备用方案：使用临时目录
    final tempDir = await getTemporaryDirectory();
    final downloadDir = Directory('${tempDir.path}/updates');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  /// 下载并安装 APK
  /// 返回进度 Stream
  static Stream<DownloadProgress> downloadAndInstall(String downloadUrl) {
    final controller = StreamController<DownloadProgress>();

    () async {
      if (!Platform.isAndroid) {
        controller.add(DownloadProgress(
          received: 0,
          total: 0,
          progress: 0,
          status: '仅支持 Android 平台',
        ));
        controller.close();
        return;
      }

      // 请求权限
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        controller.add(DownloadProgress(
          received: 0,
          total: 0,
          progress: 0,
          status: '缺少必要权限',
        ));
        controller.close();
        return;
      }

      try {
        final downloadPath = await getDownloadPath();
        final fileName = 'update_${DateTime.now().millisecondsSinceEpoch}.apk';
        final filePath = '$downloadPath/$fileName';

        controller.add(DownloadProgress(
          received: 0,
          total: 0,
          progress: 0,
          status: '开始下载...',
        ));

        int totalBytes = 0;
        int receivedBytes = 0;

        await _dio.download(
          downloadUrl,
          filePath,
          onReceiveProgress: (received, total) {
            receivedBytes = received;
            totalBytes = total;

            if (total > 0) {
              final progress = received / total;
              controller.add(DownloadProgress(
                received: received,
                total: total,
                progress: progress,
                status: '下载中 ${(progress * 100).toStringAsFixed(1)}%',
              ));
            } else {
              controller.add(DownloadProgress(
                received: received,
                total: 0,
                progress: 0,
                status: '下载中...',
              ));
            }
          },
        );

        controller.add(DownloadProgress(
          received: receivedBytes,
          total: totalBytes,
          progress: 1.0,
          status: '下载完成，准备安装...',
        ));

        // 安装 APK
        final success = await _installApk(filePath);

        if (success) {
          controller.add(DownloadProgress(
            received: receivedBytes,
            total: totalBytes,
            progress: 1.0,
            status: '安装已启动',
          ));
        } else {
          controller.add(DownloadProgress(
            received: receivedBytes,
            total: totalBytes,
            progress: 1.0,
            status: '安装失败',
          ));
        }
      } catch (e) {
        controller.add(DownloadProgress(
          received: 0,
          total: 0,
          progress: 0,
          status: '下载失败: $e',
        ));
      }

      controller.close();
    }();

    return controller.stream;
  }

  /// 安装 APK（使用平台通道）
  static Future<bool> _installApk(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('APK 文件不存在: $filePath');
        return false;
      }

      // Android 7.0+ 使用 content URI，需要通过 FileProvider
      // 这里简化处理：直接使用 file:// URI
      // 在 Android 7.0+ 上需要在 AndroidManifest 中添加 provider 并配置 paths
      final fileUri = Uri.file(filePath);

      if (await canLaunchUrl(fileUri)) {
        await launchUrl(fileUri, mode: LaunchMode.externalApplication);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('安装 APK 错误: $e');
      return false;
    }
  }

  /// 打开浏览器下载页面（备用方案）
  static Future<bool> openBrowserDownload(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('打开浏览器错误: $e');
      return false;
    }
  }

  /// 获取发布历史（用于显示更新日志）
  static Future<List<ReleaseInfo>> getReleaseHistory({int limit = 10}) async {
    try {
      final response = await _dio.get(
        '$_githubApiUrl/$repoOwner/$repoName/releases',
        queryParameters: {'per_page': limit},
        options: Options(
          headers: {
            'Accept': 'application/vnd.github.v3+json',
          },
        ),
      );

      if (response.statusCode != 200) {
        return [];
      }

      final releases = response.data as List<dynamic>;
      return releases
          .map((release) => ReleaseInfo.fromJson(release as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('获取发布历史错误: $e');
      return [];
    }
  }
}
