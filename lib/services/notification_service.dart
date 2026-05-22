import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';
import '../models/session.dart';
import '../models/check_in.dart';

/// 通知类型
enum NotificationType {
  birthday, // 生日提醒
  weeklyReport, // 出勤率周报
  attendanceDrop, // 出勤率下降提醒
  newVersion, // 新版本通知
}

/// 通知记录
class NotificationRecord {
  final String id;
  final NotificationType type;
  final DateTime sentAt;
  final String? extraData;

  NotificationRecord({
    required this.id,
    required this.type,
    required this.sentAt,
    this.extraData,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'sentAt': sentAt.millisecondsSinceEpoch,
    'extraData': extraData,
  };

  factory NotificationRecord.fromMap(Map<String, dynamic> map) => NotificationRecord(
    id: map['id'] as String,
    type: NotificationType.values.firstWhere((e) => e.name == map['type']),
    sentAt: DateTime.fromMillisecondsSinceEpoch(map['sentAt'] as int),
    extraData: map['extraData'] as String?,
  );
}

/// 通知服务
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static const String _recordsKey = 'notification_records';

  /// 初始化通知
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // 不在初始化时请求，在设置页面请求
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // 用户点击通知的处理
      },
    );

    // 创建通知渠道（Android）
    await _createNotificationChannels();
  }

  /// 检查通知权限状态
  Future<bool> checkPermissionStatus() async {
    // Android 13+ 需要权限检查
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final enabled = await androidPlugin.areNotificationsEnabled();
      return enabled ?? false;
    }

    // iOS
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final settings = await iosPlugin.requestPermissions(
        alert: false,
        badge: false,
        sound: false,
      );
      return settings ?? false;
    }

    return false;
  }

  /// 请求通知权限
  Future<bool> requestPermission() async {
    // Android 13+ 需要请求权限
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    // iOS
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final settings = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return settings ?? false;
    }

    return false;
  }

  /// 创建通知渠道
  Future<void> _createNotificationChannels() async {
    final androidPlugin = AndroidFlutterLocalNotificationsPlugin();
    
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'birthday_channel',
        '生日提醒',
        description: '同学生日提醒通知',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'weekly_report_channel',
        '出勤率周报',
        description: '每周出勤率统计报告',
        importance: Importance.defaultImportance,
        playSound: true,
      ),
    );

    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        'attendance_alert_channel',
        '出勤率异常',
        description: '出勤率下降提醒',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  /// 检查今天是否已发送过某类通知
  Future<bool> hasSentToday(NotificationType type) async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList(_recordsKey) ?? [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final json in recordsJson) {
      try {
        final record = NotificationRecord.fromMap(
          Map<String, dynamic>.from(jsonDecode(json)),
        );
        if (record.type == type) {
          final recordDate = DateTime(
            record.sentAt.year,
            record.sentAt.month,
            record.sentAt.day,
          );
          if (recordDate.isAtSameMomentAs(today)) {
            return true;
          }
        }
      } catch (_) {}
    }
    return false;
  }

  /// 检查本周是否已发送过周报
  Future<bool> hasSentWeeklyReport() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList(_recordsKey) ?? [];
    final now = DateTime.now();

    for (final json in recordsJson) {
      try {
        final record = NotificationRecord.fromMap(
          Map<String, dynamic>.from(jsonDecode(json)),
        );
        if (record.type == NotificationType.weeklyReport) {
          // 检查是否是本周（周日到周六）
          final daysSinceRecord = now.difference(record.sentAt).inDays;
          if (daysSinceRecord < 7) {
            // 检查是否是同一周
            final recordWeekday = record.sentAt.weekday;
            final nowWeekday = now.weekday;
            // 周日=7，需要转换
            final recordSunday = record.sentAt.subtract(
              Duration(days: recordWeekday == 7 ? 0 : recordWeekday),
            );
            final nowSunday = now.subtract(
              Duration(days: nowWeekday == 7 ? 0 : nowWeekday),
            );
            if (recordSunday.isAtSameMomentAs(nowSunday)) {
              return true;
            }
          }
        }
      } catch (_) {}
    }
    return false;
  }

  /// 记录通知发送
  Future<void> _recordNotification(NotificationRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList(_recordsKey) ?? [];
    recordsJson.add(jsonEncode(record.toMap()));
    
    // 只保留最近100条记录
    if (recordsJson.length > 100) {
      recordsJson.removeAt(0);
    }
    
    await prefs.setStringList(_recordsKey, recordsJson);
  }

  /// 发送生日通知
  Future<void> sendBirthdayNotification(Member member) async {
    if (await hasSentToday(NotificationType.birthday)) return;

    final id = 'birthday_${member.id}_${DateTime.now().millisecondsSinceEpoch}';
    
    await _notifications.show(
      id.hashCode,
      '🎂 生日快乐！',
      '今天是 ${member.name} 的生日，记得送上祝福哦~',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'birthday_channel',
          '生日提醒',
          channelDescription: '同学生日提醒通知',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF6750A4),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    await _recordNotification(NotificationRecord(
      id: id,
      type: NotificationType.birthday,
      sentAt: DateTime.now(),
      extraData: member.id,
    ));
  }

  /// 发送出勤率周报
  Future<void> sendWeeklyReport({
    required double avgRate,
    required double prevAvgRate,
    required int totalSessions,
    required String trend,
  }) async {
    if (await hasSentWeeklyReport()) return;

    final id = 'weekly_${DateTime.now().millisecondsSinceEpoch}';
    
    String title;
    String body;
    
    if (trend == 'up') {
      title = '📈 出勤率上升！';
      body = '本周平均出勤率 ${avgRate.toStringAsFixed(1)}%，较上周有所提升，继续保持！';
    } else if (trend == 'down') {
      title = '📉 出勤率下降';
      body = '本周平均出勤率 ${avgRate.toStringAsFixed(1)}%，较上周有所下降，请注意关注。';
    } else {
      title = '📊 本周出勤报告';
      body = '本周平均出勤率 ${avgRate.toStringAsFixed(1)}%，共完成 $totalSessions 次点名。';
    }

    await _notifications.show(
      id.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_report_channel',
          '出勤率周报',
          channelDescription: '每周出勤率统计报告',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    await _recordNotification(NotificationRecord(
      id: id,
      type: NotificationType.weeklyReport,
      sentAt: DateTime.now(),
      extraData: jsonEncode({
        'avgRate': avgRate,
        'prevAvgRate': prevAvgRate,
        'trend': trend,
      }),
    ));
  }

  /// 发送出勤率下降提醒
  Future<void> sendAttendanceDropAlert({
    required double currentRate,
    required double previousRate,
    required double dropPercent,
  }) async {
    // 下降提醒可以重复，但间隔至少6小时
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList(_recordsKey) ?? [];
    final now = DateTime.now();

    for (final json in recordsJson.reversed) {
      try {
        final record = NotificationRecord.fromMap(
          Map<String, dynamic>.from(jsonDecode(json)),
        );
        if (record.type == NotificationType.attendanceDrop) {
          if (now.difference(record.sentAt).inHours < 6) {
            return; // 6小时内已发送过
          }
          break;
        }
      } catch (_) {}
    }

    final id = 'drop_${DateTime.now().millisecondsSinceEpoch}';

    await _notifications.show(
      id.hashCode,
      '⚠️ 出勤率异常下降',
      '本次出勤率 ${currentRate.toStringAsFixed(1)}%，较上次下降 ${dropPercent.toStringAsFixed(1)}%，请关注。',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'attendance_alert_channel',
          '出勤率异常',
          channelDescription: '出勤率下降提醒',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFE53935),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    await _recordNotification(NotificationRecord(
      id: id,
      type: NotificationType.attendanceDrop,
      sentAt: DateTime.now(),
      extraData: jsonEncode({
        'currentRate': currentRate,
        'previousRate': previousRate,
        'dropPercent': dropPercent,
      }),
    ));
  }

  /// 检查并发送生日通知（在App启动时调用）
  Future<void> checkAndSendBirthdayNotification(List<Member> members) async {
    if (await hasSentToday(NotificationType.birthday)) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final member in members) {
      if (member.birthday == null) continue;
      
      if (member.birthday!.month == now.month && 
          member.birthday!.day == now.day) {
        await sendBirthdayNotification(member);
        break; // 只发送第一个过生日的
      }
    }
  }

  /// 计算出勤率趋势
  /// 返回: { 'avgRate': double, 'prevAvgRate': double, 'trend': 'up'|'down'|'stable' }
  Map<String, dynamic> calculateAttendanceTrend(
    List<Session> sessions,
    List<CheckIn> checkIns,
  ) {
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));

    // 本周数据
    final thisWeekSessions = sessions.where((s) => 
      s.createdAt.isAfter(oneWeekAgo) && s.createdAt.isBefore(now)
    ).toList();

    // 上周数据
    final lastWeekSessions = sessions.where((s) => 
      s.createdAt.isAfter(twoWeeksAgo) && s.createdAt.isBefore(oneWeekAgo)
    ).toList();

    double thisWeekRate = _calculateAverageRate(thisWeekSessions, checkIns);
    double lastWeekRate = _calculateAverageRate(lastWeekSessions, checkIns);

    String trend;
    final diff = thisWeekRate - lastWeekRate;
    if (diff > 5) {
      trend = 'up';
    } else if (diff < -5) {
      trend = 'down';
    } else {
      trend = 'stable';
    }

    return {
      'avgRate': thisWeekRate,
      'prevAvgRate': lastWeekRate,
      'trend': trend,
      'totalSessions': thisWeekSessions.length,
    };
  }

  /// 检测出勤率异常下降（最近3次点名）
  /// 返回: null 表示无异常，否则返回异常信息
  Map<String, dynamic>? detectAttendanceDrop(
    List<Session> sessions,
    List<CheckIn> checkIns,
  ) {
    // 获取最近3次完成的点名
    final completedSessions = sessions
      .where((s) => s.status == 'archived')
      .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (completedSessions.length < 3) return null;

    final recent3 = completedSessions.take(3).toList();
    
    // 计算每次的出勤率
    final rates = recent3.map((session) {
      final sessionCheckIns = checkIns.where((c) => c.sessionId == session.id).toList();
      final total = session.memberIds.length;
      final arrived = sessionCheckIns.where((c) => c.statusId == 'tag_arrived').length;
      return total > 0 ? (arrived / total * 100) : 0.0;
    }).toList();

    // 检测模式：前两天正常，第三天突然下降
    if (rates.length >= 3) {
      final day1 = rates[2]; // 最早
      final day2 = rates[1]; // 中间
      final day3 = rates[0]; // 最近

      // 前两天平均
      final avgFirstTwo = (day1 + day2) / 2;
      
      // 第三天比前两天平均下降超过20%
      if (avgFirstTwo > 0 && day3 < avgFirstTwo * 0.8) {
        final dropPercent = avgFirstTwo - day3;
        return {
          'currentRate': day3,
          'previousRate': avgFirstTwo,
          'dropPercent': dropPercent,
        };
      }
    }

    return null;
  }

  double _calculateAverageRate(List<Session> sessions, List<CheckIn> checkIns) {
    if (sessions.isEmpty) return 0.0;

    double totalRate = 0;
    int count = 0;

    for (final session in sessions) {
      final sessionCheckIns = checkIns.where((c) => c.sessionId == session.id).toList();
      final total = session.memberIds.length;
      final arrived = sessionCheckIns.where((c) => c.statusId == 'tag_arrived').length;
      
      if (total > 0) {
        totalRate += (arrived / total * 100);
        count++;
      }
    }

    return count > 0 ? totalRate / count : 0.0;
  }

  /// 发送新版本通知
  Future<void> sendNewVersionNotification(String version, String releaseNotes) async {
    // 检查是否已通知过这个版本
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList(_recordsKey) ?? [];
    
    for (final json in recordsJson) {
      try {
        final record = NotificationRecord.fromMap(
          Map<String, dynamic>.from(jsonDecode(json)),
        );
        if (record.type == NotificationType.newVersion && 
            record.extraData == version) {
          return; // 已通知过这个版本
        }
      } catch (_) {}
    }

    final id = 'version_$version';

    await _notifications.show(
      id.hashCode,
      '🎉 新版本 $version 已发布',
      releaseNotes.isNotEmpty ? releaseNotes : '点击前往GitHub下载最新版本',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_report_channel',
          '出勤率周报',
          channelDescription: '每周出勤率统计报告',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    await _recordNotification(NotificationRecord(
      id: id,
      type: NotificationType.newVersion,
      sentAt: DateTime.now(),
      extraData: version,
    ));
  }

  /// 清除所有通知记录（调试用）
  Future<void> clearAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recordsKey);
  }

  /// 获取所有通知记录（调试用）
  Future<List<NotificationRecord>> getAllRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = prefs.getStringList(_recordsKey) ?? [];
    
    return recordsJson.map((json) {
      return NotificationRecord.fromMap(
        Map<String, dynamic>.from(jsonDecode(json)),
      );
    }).toList();
  }
}
