import 'package:workmanager/workmanager.dart';
import 'notification_service.dart';
import 'update_service.dart';

/// 后台任务标识
class BackgroundTask {
  static const String weeklyReport = 'weekly_report_task';
  static const String attendanceCheck = 'attendance_check_task';
  static const String updateCheck = 'update_check_task';
}

/// 后台任务回调（必须是顶层函数）
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final notificationService = NotificationService();
    await notificationService.initialize();

    switch (task) {
      case BackgroundTask.weeklyReport:
        // 周日发送周报
        final now = DateTime.now();
        if (now.weekday == 7) { // 周日
          await notificationService.sendWeeklyReport(
            avgRate: 85.0,
            prevAvgRate: 80.0,
            totalSessions: 5,
            trend: 'up',
          );
        }
        break;

      case BackgroundTask.attendanceCheck:
        // 检查出勤率异常
        break;

      case BackgroundTask.updateCheck:
        // 检查新版本
        final release = await UpdateService.checkUpdate();
        if (release != null) {
          final notes = release.body.length > 100
              ? release.body.substring(0, 100)
              : release.body;
          await notificationService.sendNewVersionNotification(
            release.tagName,
            notes,
          );
        }
        break;
    }

    return Future.value(true);
  });
}

/// 后台服务管理
class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  bool _isInitialized = false;

  /// 初始化后台服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    _isInitialized = true;
  }

  /// 注册周期性任务
  Future<void> registerTasks() async {
    if (!_isInitialized) await initialize();

    // 注册周报任务（每天检查，实际只在周日发送）
    await Workmanager().registerPeriodicTask(
      BackgroundTask.weeklyReport,
      BackgroundTask.weeklyReport,
      frequency: const Duration(hours: 12), // 每12小时检查一次
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    // 注册出勤率检查任务
    await Workmanager().registerPeriodicTask(
      BackgroundTask.attendanceCheck,
      BackgroundTask.attendanceCheck,
      frequency: const Duration(hours: 6), // 每6小时检查一次
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    // 注册版本检查任务（每24小时检查一次）
    await Workmanager().registerPeriodicTask(
      BackgroundTask.updateCheck,
      BackgroundTask.updateCheck,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected, // 需要网络
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// 取消所有任务
  Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
  }

  /// 取消特定任务
  Future<void> cancelTask(String taskId) async {
    await Workmanager().cancelByUniqueName(taskId);
  }
}
