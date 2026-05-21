import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../models/status_tag.dart';
import '../models/session.dart';
import '../models/check_in.dart';
import '../models/operation_log.dart';
import '../models/group.dart';
import '../models/time_period.dart';
import '../services/storage_service.dart';
import '../utils/search_helper.dart';

final appStateProvider = ChangeNotifierProvider<AppState>((ref) {
  return AppState();
});

class AppState extends ChangeNotifier {
  // ==================== Data ====================
  List<Member> _members = [];
  List<StatusTag> _tags = [];
  List<Session> _sessions = [];
  List<CheckIn> _checkIns = [];
  List<OperationLog> _logs = [];
  List<Group> _groups = [];
  List<String> _attendanceTagIds = [];
  bool _showPercentageOnCards = true;

  // ==================== Getters ====================
  List<Member> get members => _members;
  List<StatusTag> get tags => _tags;
  List<Session> get sessions => _sessions;
  List<CheckIn> get checkIns => _checkIns;
  List<OperationLog> get logs => _logs;
  List<Group> get groups => _groups;
  List<String> get attendanceTagIds => _attendanceTagIds;
  bool get showPercentageOnCards => _showPercentageOnCards;

  /// Check if a tag is considered as "attended" (present).
  bool isAttendanceTag(String tagId) => _attendanceTagIds.contains(tagId);

  List<Session> get ongoingSessions =>
      _sessions.where((s) => s.status == 'ongoing').toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Session> get archivedSessions =>
      _sessions.where((s) => s.status == 'archived').toList()
        ..sort((a, b) =>
            (b.endedAt ?? b.createdAt).compareTo(a.endedAt ?? a.createdAt));

  // ==================== Initialization ====================
  void loadData() {
    _members = StorageService.getAllMembers();
    _tags = StorageService.getAllTags();
    _sessions = StorageService.getAllSessions();
    _checkIns = StorageService.getAllCheckIns();
    _logs = StorageService.getAllLogs();
    _groups = StorageService.getAllGroups();
    _attendanceTagIds = StorageService.getAttendanceTagIds();
    _showPercentageOnCards = StorageService.getShowPercentageOnCards();
    notifyListeners();
  }

  // ==================== Attendance Config ====================
  Future<void> setAttendanceTagIds(List<String> ids) async {
    _attendanceTagIds = ids;
    await StorageService.setAttendanceTagIds(ids);
    notifyListeners();
  }

  Future<void> setShowPercentageOnCards(bool value) async {
    _showPercentageOnCards = value;
    await StorageService.setShowPercentageOnCards(value);
    notifyListeners();
  }

  // ==================== Member CRUD ====================
  Future<void> addMember(Member member) async {
    _members.add(member);
    await StorageService.putMember(member);
    notifyListeners();
  }

  Future<void> addMembers(List<Member> newMembers) async {
    _members.addAll(newMembers);
    for (final m in newMembers) {
      await StorageService.putMember(m);
    }
    notifyListeners();
  }

  Future<void> updateMember(Member member) async {
    final idx = _members.indexWhere((m) => m.id == member.id);
    if (idx != -1) {
      _members[idx] = member;
      await StorageService.putMember(member);
      notifyListeners();
    }
  }

  Future<void> deleteMember(String id) async {
    _members.removeWhere((m) => m.id == id);
    await StorageService.deleteMember(id);
    notifyListeners();
  }

  Member? getMemberById(String id) {
    try {
      return _members.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  // ==================== Tag CRUD ====================
  Future<void> addTag(StatusTag tag) async {
    _tags.add(tag);
    await StorageService.putTag(tag);
    notifyListeners();
  }

  Future<void> addTagWithParams(String name, int colorValue) async {
    final tag = StatusTag(
      id: 'tag_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      colorValue: colorValue,
      isBuiltIn: false,
      sortOrder: _tags.length,
    );
    _tags.add(tag);
    await StorageService.putTag(tag);
    notifyListeners();
  }

  Future<void> updateTag(StatusTag tag) async {
    final index = _tags.indexWhere((t) => t.id == tag.id);
    if (index >= 0) {
      _tags[index] = tag;
      await StorageService.putTag(tag);
      notifyListeners();
    }
  }

  Future<void> deleteTag(String id) async {
    _tags.removeWhere((t) => t.id == id);
    await StorageService.deleteTag(id);
    notifyListeners();
  }

  StatusTag? getTagById(String id) {
    try {
      return _tags.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  StatusTag get arrivedTag {
    return _tags.firstWhere(
      (t) => t.id == 'tag_arrived',
      orElse: () => StatusTag(
        id: 'tag_arrived',
        name: '已到达',
        colorValue: 0xFF4CAF50,
        isBuiltIn: true,
      ),
    );
  }

  // ==================== Session Management ====================
  Future<Session> createSession({
    required String title,
    required List<String> memberIds,
    required List<String> memberNames,
  }) async {
    final session = Session(
      title: title,
      memberIds: memberIds,
      memberNames: memberNames,
    );
    _sessions.add(session);
    await StorageService.putSession(session);
    notifyListeners();
    return session;
  }

  Future<void> archiveSession(String sessionId) async {
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      _sessions[idx] = _sessions[idx].copyWith(
        status: 'archived',
        endedAt: DateTime.now(),
      );
      await StorageService.putSession(_sessions[idx]);
      notifyListeners();
    }
  }

  Future<void> deleteSession(String sessionId) async {
    // Cascade delete: also remove check-ins and logs for this session
    await StorageService.deleteCheckInsForSession(sessionId);
    await StorageService.deleteLogsForSession(sessionId);
    _checkIns.removeWhere((c) => c.sessionId == sessionId);
    _logs.removeWhere((l) => l.sessionId == sessionId);
    _sessions.removeWhere((s) => s.id == sessionId);
    await StorageService.deleteSession(sessionId);
    notifyListeners();
  }

  Session? getSessionById(String id) {
    try {
      return _sessions.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  // ==================== CheckIn Operations ====================
  Future<void> checkIn({
    required String sessionId,
    required String memberId,
    required String statusId,
    String? note,
  }) async {
    // Mark previous check-in as undone if exists
    final existing = _checkIns.where(
      (c) => c.sessionId == sessionId && c.memberId == memberId && !c.isUndone,
    );
    for (final c in existing) {
      final updated = c.copyWith(isUndone: true);
      final idx = _checkIns.indexOf(c);
      _checkIns[idx] = updated;
      await StorageService.putCheckIn(updated);
    }

    final checkIn = CheckIn(
      sessionId: sessionId,
      memberId: memberId,
      statusId: statusId,
      note: note,
    );
    _checkIns.add(checkIn);
    await StorageService.putCheckIn(checkIn);

    // Create operation log
    final log = OperationLog(
      sessionId: sessionId,
      type: 'check_in',
      targetMemberId: memberId,
      newStatusId: statusId,
      note: note,
    );
    _logs.add(log);
    await StorageService.putLog(log);

    notifyListeners();
  }

  Future<void> undoLastAction(String sessionId) async {
    final sessionLogs = _logs
        .where((l) => l.sessionId == sessionId && l.isUndoable)
        .toList();

    if (sessionLogs.isEmpty) return;

    final lastLog = sessionLogs.first;

    // Find and undo the check-in
    final targetCheckIns = _checkIns.where(
      (c) =>
          c.sessionId == sessionId &&
          c.memberId == lastLog.targetMemberId &&
          c.statusId == lastLog.newStatusId &&
          !c.isUndone,
    );

    for (final c in targetCheckIns) {
      final updated = c.copyWith(isUndone: true);
      final idx = _checkIns.indexOf(c);
      _checkIns[idx] = updated;
      await StorageService.putCheckIn(updated);
    }

    // Mark log as undone by adding an undo log
    final undoLog = OperationLog(
      sessionId: sessionId,
      type: 'undo',
      targetMemberId: lastLog.targetMemberId,
      prevStatusId: lastLog.newStatusId,
      timestamp: DateTime.now(),
    );
    _logs.add(undoLog);
    await StorageService.putLog(undoLog);

    notifyListeners();
  }

  Future<void> editCheckInNote({
    required String sessionId,
    required String memberId,
    required String note,
  }) async {
    final active = _checkIns.where(
      (c) => c.sessionId == sessionId && c.memberId == memberId && !c.isUndone,
    );
    for (final c in active) {
      final updated = c.copyWith(note: note);
      final idx = _checkIns.indexOf(c);
      _checkIns[idx] = updated;
      await StorageService.putCheckIn(updated);
    }

    final log = OperationLog(
      sessionId: sessionId,
      type: 'edit_note',
      targetMemberId: memberId,
      note: note,
    );
    _logs.add(log);
    await StorageService.putLog(log);

    notifyListeners();
  }

  /// Mark all unchecked members in a session as arrived
  /// Returns the count of newly marked members
  Future<int> markAllAsArrived(String sessionId) async {
    final session = getSessionById(sessionId);
    if (session == null) return 0;

    final arrivedTag = this.arrivedTag;
    var count = 0;

    for (final memberId in session.memberIds) {
      final existing = getActiveCheckIn(sessionId, memberId);
      if (existing != null && existing.statusId == arrivedTag.id) {
        continue; // Already marked as arrived
      }

      final now = DateTime.now();
      if (existing != null) {
        final updated = existing.copyWith(
          statusId: arrivedTag.id,
          statusName: arrivedTag.name,
          colorValue: arrivedTag.colorValue,
          checkedAt: now,
        );
        final idx = _checkIns.indexOf(existing);
        _checkIns[idx] = updated;
        await StorageService.putCheckIn(updated);
      } else {
        final member = getMemberById(memberId);
        final checkIn = CheckIn(
          sessionId: sessionId,
          memberId: memberId,
          memberName: member?.name ?? '未知',
          statusId: arrivedTag.id,
          statusName: arrivedTag.name,
          colorValue: arrivedTag.colorValue,
          checkedAt: now,
        );
        _checkIns.add(checkIn);
        await StorageService.putCheckIn(checkIn);
      }

      final log = OperationLog(
        sessionId: sessionId,
        type: 'check_in',
        targetMemberId: memberId,
        newStatusId: arrivedTag.id,
        prevStatusId: existing?.statusId,
      );
      _logs.add(log);
      await StorageService.putLog(log);
      count++;
    }

    if (count > 0) notifyListeners();
    return count;
  }

  // ==================== Query Helpers ====================
  CheckIn? getActiveCheckIn(String sessionId, String memberId) {
    try {
      return _checkIns
          .where((c) =>
              c.sessionId == sessionId &&
              c.memberId == memberId &&
              !c.isUndone)
          .reduce((a, b) => a.checkedAt.isAfter(b.checkedAt) ? a : b);
    } catch (_) {
      return null;
    }
  }

  List<CheckIn> getSessionCheckIns(String sessionId) {
    return _checkIns
        .where((c) => c.sessionId == sessionId && !c.isUndone)
        .toList();
  }

  List<CheckIn> getMemberCheckIns(String memberId) {
    return _checkIns
        .where((c) => c.memberId == memberId && !c.isUndone)
        .toList();
  }

  OperationLog? getLastUndoableLog(String sessionId) {
    final sessionLogs = _logs
        .where((l) => l.sessionId == sessionId && l.isUndoable)
        .toList();
    if (sessionLogs.isEmpty) return null;
    return sessionLogs.first;
  }

  // ==================== Statistics ====================
  Map<String, int> getSessionStatusCounts(String sessionId) {
    final sessionCheckIns = getSessionCheckIns(sessionId);
    final counts = <String, int>{};
    for (final ci in sessionCheckIns) {
      if (ci.statusId != null) {
        counts[ci.statusId!] = (counts[ci.statusId!] ?? 0) + 1;
      }
    }
    return counts;
  }

  int getSessionArrivedCount(String sessionId) {
    return getSessionCheckIns(sessionId)
        .where((c) => c.statusId == 'tag_arrived')
        .length;
  }

  int getSessionCheckedCount(String sessionId) {
    return getSessionCheckIns(sessionId).length;
  }

  bool isSessionComplete(String sessionId) {
    final session = getSessionById(sessionId);
    if (session == null) return true;
    final totalMembers = session.memberIds.length;
    final checkedCount = getSessionCheckedCount(sessionId);
    return checkedCount >= totalMembers;
  }

  Map<String, int> getMemberStatusCounts(String memberId) {
    final memberCheckIns = getMemberCheckIns(memberId);
    final counts = <String, int>{};
    for (final ci in memberCheckIns) {
      if (ci.statusId != null) {
        counts[ci.statusId!] = (counts[ci.statusId!] ?? 0) + 1;
      }
    }
    return counts;
  }

  double getMemberAttendanceRate(String memberId) {
    final memberCheckIns = getMemberCheckIns(memberId);
    if (memberCheckIns.isEmpty) return 0.0;
    final attendedCount = memberCheckIns
        .where((c) => _attendanceTagIds.contains(c.statusId))
        .length;
    return attendedCount / memberCheckIns.length;
  }

  List<MapEntry<String, double>> getAbsentRateRanking() {
    final result = <String, double>{};
    for (final member in _members) {
      final rate = getMemberAbsentRate(member.id);
      result[member.id] = rate;
    }
    final entries = result.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  double getMemberAbsentRate(String memberId) {
    final memberCheckIns = getMemberCheckIns(memberId);
    if (memberCheckIns.isEmpty) return 0.0;
    final absentCount = memberCheckIns
        .where((c) => c.statusId == 'tag_absent')
        .length;
    return absentCount / memberCheckIns.length;
  }

  Map<String, int> getGlobalStatusCounts() {
    final counts = <String, int>{};
    for (final ci in _checkIns.where((c) => !c.isUndone)) {
      if (ci.statusId != null) {
        counts[ci.statusId!] = (counts[ci.statusId!] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Get sorted members for a session: unchecked first, then checked
  List<Member> getSortedSessionMembers(
    String sessionId, {
    String? filterStatusId,
    String? searchQuery,
  }) {
    final session = getSessionById(sessionId);
    if (session == null) return [];

    var memberList = <Member>[];
    for (int i = 0; i < session.memberIds.length; i++) {
      final member = getMemberById(session.memberIds[i]);
      if (member != null) {
        memberList.add(member);
      }
    }

    // Apply search filter with pinyin support
    if (searchQuery != null && searchQuery.isNotEmpty) {
      memberList = memberList.where((m) {
        // Search by name with pinyin
        final nameMatch = PinyinSearchHelper.matches(m.name, searchQuery);
        // Search by studentId
        final studentIdMatch = m.studentId != null &&
            m.studentId!.toLowerCase().contains(searchQuery.toLowerCase());
        return nameMatch || studentIdMatch;
      }).toList();
    }

    // When no filter (showing all), sort by studentId but keep position fixed after marking.
    // When filtering, sort unchecked first, then by studentId.
    memberList.sort((a, b) {
      if (filterStatusId == null) {
        // Showing all: sort by studentId only, no status-based reordering
        final aId = a.studentId ?? a.name;
        final bId = b.studentId ?? b.name;
        return aId.compareTo(bId);
      } else {
        // Filtering: unchecked first, then by studentId
        final aChecked = getActiveCheckIn(sessionId, a.id) != null;
        final bChecked = getActiveCheckIn(sessionId, b.id) != null;
        if (aChecked != bChecked) return aChecked ? 1 : -1;
        final aId = a.studentId ?? a.name;
        final bId = b.studentId ?? b.name;
        return aId.compareTo(bId);
      }
    });

    if (filterStatusId != null) {
      if (filterStatusId == 'unchecked') {
        memberList = memberList.where((m) {
          final ci = getActiveCheckIn(sessionId, m.id);
          return ci == null;
        }).toList();
      } else {
        memberList = memberList.where((m) {
          final ci = getActiveCheckIn(sessionId, m.id);
          return ci?.statusId == filterStatusId;
        }).toList();
      }
    }

    return memberList;
  }

  /// Search members globally
  List<Member> searchMembers(String query) {
    if (query.isEmpty) return [..._members];
    return _members.where((m) {
      final nameMatch = PinyinSearchHelper.matches(m.name, query);
      final studentIdMatch = m.studentId != null &&
          m.studentId!.toLowerCase().contains(query.toLowerCase());
      return nameMatch || studentIdMatch;
    }).toList();
  }

  /// Get checkins for a specific time period
  List<CheckIn> getCheckInsForPeriod(TimePeriod period, {String? sessionId}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime startDate;
    DateTime endDate = now;

    switch (period) {
      case TimePeriod.today:
        startDate = today;
        break;
      case TimePeriod.lastWeek:
        // 最近7天
        startDate = today.subtract(const Duration(days: 7));
        break;
      case TimePeriod.lastMonth:
        // 最近30天
        startDate = today.subtract(const Duration(days: 30));
        break;
    }

    // Only include check-ins from sessions that currently exist
    final validSessionIds = _sessions.map((s) => s.id).toSet();
    return _checkIns.where((ci) {
      if (ci.isUndone) return false;
      if (!validSessionIds.contains(ci.sessionId)) return false;
      return ci.checkedAt.isAfter(startDate) &&
          ci.checkedAt.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();
  }

  /// Get weekly heatmap data: list of (weekday 1-7, attendanceRate)
  /// Each entry represents one day's overall attendance rate
  List<MapEntry<int, double>> getWeeklyHeatmapData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));

    final validSessionIds = _sessions.map((s) => s.id).toSet();
    final result = <MapEntry<int, double>>[];

    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final dayCheckIns = _checkIns.where((ci) {
        if (ci.isUndone) return false;
        if (!validSessionIds.contains(ci.sessionId)) return false;
        final ciDate = DateTime(ci.checkedAt.year, ci.checkedAt.month, ci.checkedAt.day);
        return ciDate == date;
      }).toList();

      if (dayCheckIns.isEmpty) {
        result.add(MapEntry(i + 1, -1.0)); // -1 means no data
      } else {
        final attended = dayCheckIns.where((c) => _attendanceTagIds.contains(c.statusId)).length;
        result.add(MapEntry(i + 1, attended / dayCheckIns.length));
      }
    }
    return result;
  }

  /// Get member attendance stats for a time period
  List<Map<String, dynamic>> getMemberAbsenteeismRanking(TimePeriod period) {
    final checkIns = getCheckInsForPeriod(period);

    final memberStats = <String, Map<String, int>>{};

    for (final ci in checkIns) {
      if (!memberStats.containsKey(ci.memberId)) {
        memberStats[ci.memberId] = {'total': 0, 'absent': 0};
      }
      memberStats[ci.memberId]!['total'] = memberStats[ci.memberId]!['total']! + 1;
      // A check-in is "absent" if its tag is NOT in the attendance tag list
      if (ci.statusId != null && !_attendanceTagIds.contains(ci.statusId)) {
        memberStats[ci.memberId]!['absent'] = memberStats[ci.memberId]!['absent']! + 1;
      }
    }

    final result = <Map<String, dynamic>>[];
    memberStats.forEach((memberId, stats) {
      final member = getMemberById(memberId);
      if (member != null) {
        final absentRate = stats['total']! > 0 ? stats['absent']! / stats['total']! : 0.0;
        result.add({
          'member': member,
          'total': stats['total'],
          'absent': stats['absent'],
          'absentRate': absentRate,
        });
      }
    });

    result.sort((a, b) => (b['absentRate'] as double).compareTo(a['absentRate'] as double));

    return result;
  }

  /// Get daily attendance rates for trend chart
  /// Returns list of (date, attendanceRate) sorted by date ascending
  List<MapEntry<DateTime, double>> getDailyAttendanceRates(TimePeriod period) {
    final checkIns = getCheckInsForPeriod(period);
    final validSessionIds = _sessions.map((s) => s.id).toSet();

    // Group check-ins by date (normalized to day start)
    final dailyCheckIns = <DateTime, List<CheckIn>>{};
    for (final ci in checkIns) {
      final date = DateTime(ci.checkedAt.year, ci.checkedAt.month, ci.checkedAt.day);
      dailyCheckIns.putIfAbsent(date, () => []);
      dailyCheckIns[date]!.add(ci);
    }

    // Fill in missing dates with 0% attendance
    final now = DateTime.now();
    DateTime startDate;
    switch (period) {
      case TimePeriod.today:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case TimePeriod.lastWeek:
        startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
        break;
      case TimePeriod.lastMonth:
        startDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
        break;
    }

    final result = <MapEntry<DateTime, double>>[];
    for (int i = 0; i <= now.difference(startDate).inDays; i++) {
      final date = startDate.add(Duration(days: i));
      final dayCheckIns = dailyCheckIns[date] ?? [];
      if (dayCheckIns.isEmpty) {
        result.add(MapEntry(date, 0.0));
      } else {
        final attended = dayCheckIns.where((c) => _attendanceTagIds.contains(c.statusId)).length;
        result.add(MapEntry(date, attended / dayCheckIns.length));
      }
    }
    return result;
  }

  /// Get period-over-period comparison data
  /// Returns map with current period stats and change percentages
  Map<String, dynamic> getPeriodComparison(TimePeriod period) {
    // Calculate previous period date range
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime currentStart;
    DateTime previousStart;
    DateTime previousEnd;

    switch (period) {
      case TimePeriod.today:
        currentStart = today;
        previousStart = today.subtract(const Duration(days: 1));
        previousEnd = today.subtract(const Duration(seconds: 1));
        break;
      case TimePeriod.lastWeek:
        currentStart = today.subtract(const Duration(days: 7));
        previousStart = today.subtract(const Duration(days: 14));
        previousEnd = today.subtract(const Duration(days: 8));
        break;
      case TimePeriod.lastMonth:
        currentStart = today.subtract(const Duration(days: 30));
        previousStart = today.subtract(const Duration(days: 60));
        previousEnd = today.subtract(const Duration(days: 31));
        break;
    }

    final validSessionIds = _sessions.map((s) => s.id).toSet();

    // Helper to get stats for a date range
    Map<String, int> getRangeStats(DateTime start, DateTime end) {
      final rangeCheckIns = _checkIns.where((ci) {
        if (ci.isUndone) return false;
        if (!validSessionIds.contains(ci.sessionId)) return false;
        return ci.checkedAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
            ci.checkedAt.isBefore(end.add(const Duration(days: 1)));
      }).toList();

      final total = rangeCheckIns.length;
      final attended = rangeCheckIns.where((c) => _attendanceTagIds.contains(c.statusId)).length;
      return {'total': total, 'attended': attended};
    }

    final currentStats = getRangeStats(currentStart, now);
    final previousStats = getRangeStats(previousStart, previousEnd);

    final currentRate = currentStats['total']! > 0
        ? currentStats['attended']! / currentStats['total']! : 0.0;
    final previousRate = previousStats['total']! > 0
        ? previousStats['attended']! / previousStats['total']! : 0.0;

    return {
      'currentRate': currentRate,
      'previousRate': previousRate,
      'currentCount': currentStats['total'],
      'previousCount': previousStats['total'],
      'rateChange': currentRate - previousRate,
      'countChange': currentStats['total']! - previousStats['total']!,
    };
  }

  /// Get status counts for a time period
  Map<String, int> getStatusCountsForPeriod(TimePeriod period, {String? sessionId}) {
    final checkIns = getCheckInsForPeriod(period, sessionId: sessionId);
    final counts = <String, int>{};
    for (final ci in checkIns) {
      if (ci.statusId != null) {
        counts[ci.statusId!] = (counts[ci.statusId!] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Get arrived count for a time period
  int getArrivedCountForPeriod(TimePeriod period, {String? sessionId}) {
    final checkIns = getCheckInsForPeriod(period, sessionId: sessionId);
    return checkIns.where((ci) => ci.statusId == 'tag_arrived').length;
  }

  // ==================== Group CRUD ====================
  Future<void> addGroup(Group group) async {
    _groups.add(group);
    await StorageService.putGroup(group);
    notifyListeners();
  }

  Future<void> updateGroup(Group group) async {
    final idx = _groups.indexWhere((g) => g.id == group.id);
    if (idx != -1) {
      _groups[idx] = group.copyWith(updatedAt: DateTime.now());
      await StorageService.putGroup(_groups[idx]);
      notifyListeners();
    }
  }

  Future<void> deleteGroup(String id) async {
    _groups.removeWhere((g) => g.id == id);
    await StorageService.deleteGroup(id);
    notifyListeners();
  }

  Group? getGroupById(String id) {
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Group> getGroupsForMember(String memberId) {
    return _groups.where((g) => g.memberIds.contains(memberId)).toList();
  }

  Future<void> addMemberToGroup(String groupId, String memberId) async {
    final group = getGroupById(groupId);
    if (group == null) return;
    if (group.memberIds.contains(memberId)) return;

    final updatedGroup = group.copyWith(
      memberIds: [...group.memberIds, memberId],
    );
    await updateGroup(updatedGroup);
  }

  Future<void> removeMemberFromGroup(String groupId, String memberId) async {
    final group = getGroupById(groupId);
    if (group == null) return;
    if (!group.memberIds.contains(memberId)) return;

    final updatedGroup = group.copyWith(
      memberIds: group.memberIds.where((id) => id != memberId).toList(),
    );
    await updateGroup(updatedGroup);
  }

  /// 检查超时的进行中点名
  /// 返回需要自动归档的和需要提醒的
  ({List<Session> toArchive, List<Session> toRemind}) checkSessionTimeouts() {
    final now = DateTime.now();
    final toArchive = <Session>[];
    final toRemind = <Session>[];

    for (final session in _sessions) {
      if (session.status != 'ongoing') continue;

      final elapsed = now.difference(session.createdAt);

      if (elapsed.inHours >= 24) {
        toArchive.add(session);
      } else if (elapsed.inHours >= 12) {
        toRemind.add(session);
      }
    }

    return (toArchive: toArchive, toRemind: toRemind);
  }

  /// Copy check-in records from one session to another
  Future<void> copyCheckInsFromSession(String fromSessionId, String toSessionId) async {
    final sourceCheckIns = StorageService.getCheckInsForSession(fromSessionId);
    for (final ci in sourceCheckIns) {
      final newCi = CheckIn(
        sessionId: toSessionId,
        memberId: ci.memberId,
        statusId: ci.statusId,
        note: ci.note,
      );
      _checkIns.add(newCi);
      await StorageService.putCheckIn(newCi);
    }
    notifyListeners();
  }

  /// Clear all data
  Future<void> clearAllData() async {
    await StorageService.clearAll();
    notifyListeners();
  }

  // ==================== Color Generation ====================

  /// 计算两个颜色的差异度（0-1，越大差异越大）
  double _colorDifference(Color c1, Color c2) {
    final dr = (c1.red - c2.red) / 255.0;
    final dg = (c1.green - c2.green) / 255.0;
    final db = (c1.blue - c2.blue) / 255.0;
    return (dr * dr + dg * dg + db * db) / 3.0;
  }

  /// 生成与现有标签颜色有足够差异的随机颜色
  int generateDistinctColor() {
    final random = Random();
    final existingColors = _tags.map((t) => Color(t.colorValue)).toList();

    const minDifference = 0.15; // 最小差异阈值

    for (int attempt = 0; attempt < 100; attempt++) {
      // 生成 HSL 颜色，确保饱和度足够
      final hue = random.nextInt(360);
      final saturation = 0.6 + random.nextDouble() * 0.4; // 0.6-1.0
      final lightness = 0.4 + random.nextDouble() * 0.3; // 0.4-0.7

      final newColor = HSLColor.fromAHSL(1.0, hue.toDouble(), saturation, lightness).toColor();

      // 检查与现有颜色的差异
      bool isDistinct = true;
      for (final existing in existingColors) {
        if (_colorDifference(newColor, existing) < minDifference) {
          isDistinct = false;
          break;
        }
      }

      if (isDistinct) {
        return newColor.value;
      }
    }

    // 如果找不到足够不同的颜色，返回随机颜色
    return Color.fromRGBO(
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
      1.0,
    ).value;
  }
}
