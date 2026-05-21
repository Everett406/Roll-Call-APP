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

/// 下载状态
enum DownloadStatus {
  idle,
  downloading,
  paused,
  completed,
  failed,
}

/// 下载任务
class DownloadTask {
  final String id;
  final String downloadUrl;
  final String filePath;
  DownloadStatus status;
  double progress;
  String statusText;
  String? errorMessage;

  DownloadTask({
    required this.id,
    required this.downloadUrl,
    required this.filePath,
    this.status = DownloadStatus.idle,
    this.progress = 0,
    this.statusText = '等待下载',
    this.errorMessage,
  });
}

/// 更新服务类
class UpdateService {
  static const String repoOwner = 'Everett406';
  static const String repoName = 'Roll-Call-APP';
  static const String _githubApiUrl = 'https://api.github.com/repos';

  // 单例模式
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  // Dio 实例 - 更长的超时时间
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 300),
    ),
  );

  // 当前下载任务
  DownloadTask? _currentTask;
  StreamController<DownloadTask>? _downloadController;
  CancelToken? _cancelToken;

  // 获取下载状态流
  Stream<DownloadTask>? get downloadStream => _downloadController?.stream;

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

  /// 请求必要的权限
  static Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return false;

    // 检查安装权限
    final installStatus = await Permission.requestInstallPackages.status;
    if (!installStatus.isGranted) {
      final result = await Permission.requestInstallPackages.request();
      if (!result.isGranted) return false;
    }

    return true;
  }

  /// 获取下载目录路径
  static Future<String> getDownloadPath() async {
    if (Platform.isAndroid) {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final downloadDir = Directory('${directory.path}/updates');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir.path;
      }
    }
    final tempDir = await getTemporaryDirectory();
    final downloadDir = Directory('${tempDir.path}/updates');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  /// 开始后台下载
  /// 返回下载任务ID，可以通过 downloadStream 监听进度
  Future<String> startBackgroundDownload(String downloadUrl) async {
    // 如果已有下载任务，先取消
    await cancelDownload();

    final downloadPath = await getDownloadPath();
    final fileName = 'update_${DateTime.now().millisecondsSinceEpoch}.apk';
    final filePath = '$downloadPath/$fileName';

    _currentTask = DownloadTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      downloadUrl: downloadUrl,
      filePath: filePath,
      status: DownloadStatus.downloading,
      statusText: '准备下载...',
    );

    _downloadController = StreamController<DownloadTask>.broadcast();
    _cancelToken = CancelToken();

    // 启动后台下载
    _doDownloadWithRetry(downloadUrl, filePath);

    return _currentTask!.id;
  }

  /// 带重试的下载
  Future<void> _doDownloadWithRetry(String downloadUrl, String filePath) async {
    const maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        await _doDownload(downloadUrl, filePath);
        return; // 下载成功
      } on DioException catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          _updateTask(
            status: DownloadStatus.failed,
            statusText: _getFriendlyErrorMessage(e),
            errorMessage: e.message,
          );
          return;
        }
        // 等待后重试
        _updateTask(
          status: DownloadStatus.downloading,
          statusText: '下载失败，正在重试 ($retryCount/$maxRetries)...',
        );
        await Future.delayed(Duration(seconds: retryCount * 2));
      } catch (e) {
        _updateTask(
          status: DownloadStatus.failed,
          statusText: '下载失败: ${e.toString()}',
          errorMessage: e.toString(),
        );
        return;
      }
    }
  }

  /// 执行下载
  Future<void> _doDownload(String downloadUrl, String filePath) async {
    int totalBytes = 0;
    int receivedBytes = 0;

    await _dio.download(
      downloadUrl,
      filePath,
      cancelToken: _cancelToken,
      onReceiveProgress: (received, total) {
        receivedBytes = received;
        totalBytes = total;

        if (total > 0) {
          final progress = received / total;
          _updateTask(
            status: DownloadStatus.downloading,
            progress: progress,
            statusText: '下载中 ${(progress * 100).toStringAsFixed(1)}%',
          );
        } else {
          final mb = (received / 1024 / 1024).toStringAsFixed(1);
          _updateTask(
            status: DownloadStatus.downloading,
            statusText: '已下载 ${mb}MB',
          );
        }
      },
    );

    // 下载完成
    _updateTask(
      status: DownloadStatus.completed,
      progress: 1.0,
      statusText: '下载完成',
    );

    // 自动触发安装
    await _installApk(filePath);
  }

  /// 更新任务状态并通知监听者
  void _updateTask({
    DownloadStatus? status,
    double? progress,
    String? statusText,
    String? errorMessage,
  }) {
    if (_currentTask == null) return;

    if (status != null) _currentTask!.status = status;
    if (progress != null) _currentTask!.progress = progress;
    if (statusText != null) _currentTask!.statusText = statusText;
    if (errorMessage != null) _currentTask!.errorMessage = errorMessage;

    _downloadController?.add(_currentTask!);
  }

  /// 获取友好的错误提示
  String _getFriendlyErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接超时，请检查网络后重试';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络设置';
      case DioExceptionType.cancel:
        return '下载已取消';
      case DioExceptionType.badResponse:
        return '服务器响应错误 (${e.response?.statusCode})';
      default:
        return '下载失败: ${e.message}';
    }
  }

  /// 取消下载
  Future<void> cancelDownload() async {
    _cancelToken?.cancel('用户取消');
    _cancelToken = null;
    _downloadController?.close();
    _downloadController = null;
    _currentTask = null;
  }

  /// 获取当前下载任务
  DownloadTask? get currentTask => _currentTask;

  /// 安装 APK
  Future<bool> _installApk(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

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

  /// 打开浏览器下载（备用方案）
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
}
