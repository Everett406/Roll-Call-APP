import 'package:flutter/foundation.dart';
import '../models/member.dart';
import '../models/status_tag.dart';
import '../models/session.dart';
import '../models/check_in.dart';
import '../models/operation_log.dart';
import '../services/storage_service.dart';

class AppState extends ChangeNotifier {
  // ==================== Data ====================
  List<Member> _members = [];
  List<StatusTag> _tags = [];
  List<Session> _sessions = [];
  List<CheckIn> _checkIns = [];
  List<OperationLog> _logs = [];

  // ==================== Getters ====================
  List<Member> get members => _members;
  List<StatusTag> get tags => _tags;
  List<Session> get sessions => _sessions;
  List<CheckIn> get checkIns => _checkIns;
  List<OperationLog> get logs => _logs;

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

  Future<void> updateTag(StatusTag tag) async {
    final idx = _tags.indexWhere((t) => t.id == tag.id);
    if (idx != -1) {
      _tags[idx] = tag;
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
      orElse: => StatusTag(
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

  int getSessionCheckedCount(String sessionId) {
    return getSessionCheckIns(sessionId).length;
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
    final arrivedCount = memberCheckIns
        .where((c) => c.statusId == 'tag_arrived')
        .length;
    return arrivedCount / memberCheckIns.length;
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

    // Apply search filter
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      memberList = memberList.where((m) {
        return m.name.toLowerCase().contains(query) ||
            (m.studentId?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Apply status filter
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
    } else {
      // Default sort: unchecked first
      memberList.sort((a, b) {
        final aChecked = getActiveCheckIn(sessionId, a.id) != null;
        final bChecked = getActiveCheckIn(sessionId, b.id) != null;
        if (aChecked == bChecked) return 0;
        return aChecked ? 1 : -1;
      });
    }

    return memberList;
  }
}
