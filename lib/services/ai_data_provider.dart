import '../models/member.dart';
import '../models/session.dart';
import '../models/check_in.dart';
import 'storage_service.dart';

/// AI 工具调用的数据提供者
class AiDataProvider {
  /// 执行工具调用
  static Future<String> execute(String toolName, Map<String, dynamic> args) async {
    switch (toolName) {
      case 'query_members':
        return _queryMembers(args);
      case 'query_member_detail':
        return _queryMemberDetail(args);
      case 'query_sessions':
        return _querySessions(args);
      case 'query_attendance_stats':
        return _queryAttendanceStats(args);
      case 'query_absent_members':
        return _queryAbsentMembers(args);
      default:
        return '未知工具：$toolName';
    }
  }

  static Future<String> _queryMembers(Map<String, dynamic> args) async {
    final members = StorageService.getAllMembers();
    final keyword = args['keyword'] as String?;

    List<Member> filtered = members;
    if (keyword != null && keyword.isNotEmpty) {
      filtered = members.where((m) => m.name.contains(keyword)).toList();
    }

    if (filtered.isEmpty) return '未找到匹配的成员';

    final result = filtered.map((m) {
      String info = '- ${m.name}';
      if (m.studentId != null) info += '（${m.studentId}）';
      if (m.birthday != null) {
        info += '，生日：${m.birthday!.month}/${m.birthday!.day}';
      }
      return info;
    }).join('\n');

    return '共 ${filtered.length} 位成员：\n$result';
  }

  static Future<String> _queryMemberDetail(Map<String, dynamic> args) async {
    final name = args['name'] as String;
    final members = StorageService.getAllMembers();
    final member = members.where((m) => m.name == name).toList();

    if (member.isEmpty) return '未找到名为"$name"的成员';
    if (member.length > 1) return '找到 ${member.length} 个同名成员，请提供更多信息';

    final m = member.first;
    final checkIns = StorageService.getCheckInsForMember(m.id);
    final sessions = StorageService.getAllSessions().where((s) => s.status == 'archived').toList();
    final totalSessions = sessions.length;

    // 计算出勤率
    int arrived = 0;
    for (final ci in checkIns) {
      if (ci.statusId == 'tag_arrived') arrived++;
    }
    final rate = totalSessions > 0 ? (arrived / totalSessions * 100).toStringAsFixed(1) : 'N/A';

    String info = '成员：${m.name}\n';
    if (m.studentId != null) info += '学号：${m.studentId}\n';
    if (m.birthday != null) info += '生日：${m.birthday!.year}/${m.birthday!.month}/${m.birthday!.day}\n';
    info += '参与点名次数：$totalSessions\n';
    info += '出勤次数：$arrived\n';
    info += '出勤率：$rate%';

    return info;
  }

  static Future<String> _querySessions(Map<String, dynamic> args) async {
    final limit = (args['limit'] as int?) ?? 10;
    final sessions = StorageService.getArchivedSessions().take(limit).toList();

    if (sessions.isEmpty) return '暂无点名记录';

    final result = sessions.map((s) {
      String info = '- ${s.title}';
      if (s.endedAt != null) {
        info += '（${s.endedAt!.month}/${s.endedAt!.day}）';
      }
      info += '，参与 ${s.memberIds.length} 人';
      return info;
    }).join('\n');

    return '最近 $limit 次点名记录：\n$result';
  }

  static Future<String> _queryAttendanceStats(Map<String, dynamic> args) async {
    final period = args['period'] as String;
    final now = DateTime.now();
    final allCheckIns = StorageService.getAllCheckIns();
    final allSessions = StorageService.getAllSessions().where((s) => s.status == 'archived').toList();

    List sessions;
    if (period == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      sessions = allSessions.where((s) => s.createdAt.isAfter(weekAgo)).toList();
    } else if (period == 'month') {
      sessions = allSessions.where((s) =>
        s.createdAt.month == now.month && s.createdAt.year == now.year
      ).toList();
    } else {
      sessions = allSessions;
    }

    if (sessions.isEmpty) return '该时段暂无点名记录';

    int totalArrived = 0;
    int totalMembers = 0;
    for (final session in sessions) {
      final sessionCheckIns = allCheckIns.where((c) => c.sessionId == session.id && !c.isUndone).toList();
      final arrived = sessionCheckIns.where((c) => c.statusId == 'tag_arrived').length;
      totalArrived += arrived;
      totalMembers += session.memberIds.length as int;
    }

    final avgRate = totalMembers > 0 ? (totalArrived / totalMembers * 100).toStringAsFixed(1) : '0';

    String periodText = period == 'week' ? '本周' : period == 'month' ? '本月' : '全部';
    return '''${periodText}出勤统计：
- 点名次数：${sessions.length}
- 总人次：$totalMembers
- 出勤人次：$totalArrived
- 平均出勤率：$avgRate%''';
  }

  static Future<String> _queryAbsentMembers(Map<String, dynamic> args) async {
    final limit = (args['limit'] as int?) ?? 5;
    final members = StorageService.getAllMembers();
    final allCheckIns = StorageService.getAllCheckIns();
    final allSessions = StorageService.getAllSessions().where((s) => s.status == 'archived').toList();

    // 计算每个成员的缺勤次数
    final absentCount = <String, int>{};
    for (final member in members) {
      int absent = 0;
      for (final session in allSessions) {
        if (!session.memberIds.contains(member.id)) continue;
        final sessionCheckIns = allCheckIns.where((c) => c.sessionId == session.id && c.memberId == member.id && !c.isUndone).toList();
        if (sessionCheckIns.isEmpty || !sessionCheckIns.any((c) => c.statusId == 'tag_arrived')) {
          absent++;
        }
      }
      if (absent > 0) {
        absentCount[member.name] = absent;
      }
    }

    if (absentCount.isEmpty) return '暂无缺勤记录';

    final sorted = absentCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(limit);

    final result = top.map((e) => '- ${e.key}：缺勤 ${e.value} 次').join('\n');
    return '缺勤排行（前$limit名）：\n$result';
  }
}
