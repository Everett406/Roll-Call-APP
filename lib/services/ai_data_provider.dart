import '../models/member.dart';
import '../models/session.dart';
import '../models/check_in.dart';
import 'storage_service.dart';

/// AI 工具调用的数据提供者
class AiDataProvider {
  /// 执行工具调用
  static Future<String> execute(String toolName, Map<String, dynamic> args) async {
    try {
      switch (toolName) {
        case 'query_members':
          return await _queryMembers(args);
        case 'query_member_detail':
          return await _queryMemberDetail(args);
        case 'query_sessions':
          return await _querySessions(args);
        case 'query_attendance_stats':
          return await _queryAttendanceStats(args);
        case 'query_absent_members':
          return await _queryAbsentMembers(args);
        case 'import_members':
          return await importMembers(args);
        case 'update_member':
          return await updateMember(args);
        case 'query_birthdays':
          return await queryBirthdays(args);
        default:
          return '未知工具：$toolName';
      }
    } catch (e) {
      return '查询出错：$e';
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
      info += ' [查看](rollcall://member/${m.id})';
      return info;
    }).join('\n');

    return '共 ${filtered.length} 位成员：\n$result';
  }

  static Future<String> _queryMemberDetail(Map<String, dynamic> args) async {
    final name = args['name'] as String?;
    if (name == null || name.isEmpty) {
      return '请提供成员姓名';
    }
    
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
      info += ' [查看详情](rollcall://session/${s.id})';
      return info;
    }).join('\n');

    return '最近 $limit 次点名记录：\n$result';
  }

  static Future<String> _queryAttendanceStats(Map<String, dynamic> args) async {
    final period = args['period'] as String? ?? 'all';
    final now = DateTime.now();
    final allCheckIns = StorageService.getAllCheckIns();
    final allSessions = StorageService.getAllSessions().where((s) => s.status == 'archived').toList();

    List<Session> sessions;
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
      totalMembers += (session.memberIds.length as num).toInt();
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

  /// 导入成员
  static Future<String> importMembers(Map<String, dynamic> args) async {
    final membersData = args['members'] as List<dynamic>?;
    if (membersData == null || membersData.isEmpty) {
      return '请提供成员数据';
    }

    int successCount = 0;
    final errors = <String>[];

    for (final data in membersData) {
      try {
        final name = data['name'] as String?;
        if (name == null || name.isEmpty) {
          errors.add('成员姓名不能为空');
          continue;
        }

        final studentId = data['studentId'] as String?;
        final birthdayStr = data['birthday'] as String?;
        final lunarBirthdayStr = data['lunarBirthday'] as String?;
        DateTime? birthday;
        if (birthdayStr != null && birthdayStr.isNotEmpty) {
          try {
            final parts = birthdayStr.split('/');
            if (parts.length == 3) {
              birthday = DateTime(
                int.parse(parts[0]),
                int.parse(parts[1]),
                int.parse(parts[2]),
              );
            }
          } catch (_) {
            // 忽略解析错误
          }
        }

        // 检查是否已存在
        final existing = StorageService.getAllMembers()
            .where((m) => m.name == name && (studentId == null || m.studentId == studentId))
            .toList();

        if (existing.isNotEmpty) {
          // 更新现有成员
          final updated = existing.first.copyWith(
            studentId: studentId,
            birthday: birthday,
            lunarBirthday: lunarBirthdayStr,
          );
          await StorageService.putMember(updated);
        } else {
          // 创建新成员
          final member = Member(
            id: 'member_${DateTime.now().millisecondsSinceEpoch}_$successCount',
            name: name,
            studentId: studentId,
            birthday: birthday,
            lunarBirthday: lunarBirthdayStr,
          );
          await StorageService.putMember(member);
        }
        successCount++;
      } catch (e) {
        errors.add('导入失败: $e');
      }
    }

    String result = '成功导入 $successCount 位成员';
    if (errors.isNotEmpty) {
      result += '\n错误：${errors.take(3).join(', ')}';
    }
    return result;
  }

  /// 更新成员信息
  static Future<String> updateMember(Map<String, dynamic> args) async {
    final memberId = args['memberId'] as String?;
    final name = args['name'] as String?;
    final newName = args['newName'] as String?;
    final studentId = args['studentId'] as String?;
    final birthdayStr = args['birthday'] as String?;
    final lunarBirthdayStr = args['lunarBirthday'] as String?;

    Member? targetMember;

    if (memberId != null && memberId.isNotEmpty) {
      final members = StorageService.getAllMembers();
      final found = members.where((m) => m.id == memberId).toList();
      if (found.isNotEmpty) {
        targetMember = found.first;
      }
    }

    if (targetMember == null && name != null && name.isNotEmpty) {
      final members = StorageService.getAllMembers();
      final byName = members.where((m) => m.name == name).toList();
      if (byName.isEmpty) return '未找到名为"$name"的成员';
      if (byName.length > 1) return '找到多个同名成员，请提供ID';
      targetMember = byName.first;
    }

    if (targetMember == null) return '未找到成员，请提供姓名';

    DateTime? birthday;
    if (birthdayStr != null && birthdayStr.isNotEmpty) {
      try {
        final parts = birthdayStr.split('/');
        if (parts.length == 3) {
          birthday = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      } catch (_) {}
    }

    final updated = targetMember.copyWith(
      name: newName,
      studentId: studentId,
      birthday: birthday,
      lunarBirthday: lunarBirthdayStr,
    );
    await StorageService.putMember(updated);

    return '已更新成员：${updated.name}';
  }

  /// 查询最近过生日的成员
  static Future<String> queryBirthdays(Map<String, dynamic> args) async {
    final days = (args['days'] as int?) ?? 7;
    final members = StorageService.getAllMembers();
    final now = DateTime.now();
    final results = <String>[];

    for (final member in members) {
      // 检查公历生日
      if (member.birthday != null) {
        DateTime birthdayThisYear = DateTime(now.year, member.birthday!.month, member.birthday!.day);
        if (birthdayThisYear.isBefore(now)) {
          birthdayThisYear = DateTime(now.year + 1, member.birthday!.month, member.birthday!.day);
        }
        final diff = birthdayThisYear.difference(now).inDays;
        if (diff >= 0 && diff <= days) {
          String info = '- ${member.name}：公历生日 ${member.birthday!.month}月${member.birthday!.day}日';
          if (diff == 0) info += '（今天！）';
          else if (diff == 1) info += '（明天）';
          else info += '（${diff}天后）';
          results.add(info);
        }
      }

      // 检查农历生日（如果有 lunarBirthday 字段）
      if (member.lunarBirthday != null && member.lunarBirthday!.isNotEmpty) {
        // 农历生日暂存提示信息（需要农历转换库才能精确计算）
        results.add('- ${member.name}：农历生日 ${member.lunarBirthday}（农历转换暂不支持精确日期计算）');
      }
    }

    if (results.isEmpty) return '最近 $days 天内没有成员过生日';
    results.sort();
    return '最近 $days 天内的生日：\n${results.join('\n')}';
  }
}
