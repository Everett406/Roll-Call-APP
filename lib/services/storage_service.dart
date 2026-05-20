import 'package:hive_flutter/hive_flutter.dart';
import '../models/member.dart';
import '../models/status_tag.dart';
import '../models/session.dart';
import '../models/check_in.dart';
import '../models/operation_log.dart';

class StorageService {
  static const String _membersBox = 'members';
  static const String _tagsBox = 'statusTags';
  static const String _sessionsBox = 'sessions';
  static const String _checkInsBox = 'checkIns';
  static const String _logsBox = 'operationLogs';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_membersBox);
    await Hive.openBox(_tagsBox);
    await Hive.openBox(_sessionsBox);
    await Hive.openBox(_checkInsBox);
    await Hive.openBox(_logsBox);
    await _initDefaultTags();
  }

  static Future<void> _initDefaultTags() async {
    final box = Hive.box(_tagsBox);
    if (box.isNotEmpty) return;

    final defaultTags = [
      StatusTag(
          id: 'tag_arrived',
          name: '已到达',
          colorValue: 0xFF4CAF50,
          isBuiltIn: true,
          sortOrder: 0),
      StatusTag(
          id: 'tag_sick',
          name: '病假',
          colorValue: 0xFFFF9800,
          isBuiltIn: true,
          sortOrder: 1),
      StatusTag(
          id: 'tag_retake',
          name: '重修',
          colorValue: 0xFF9C27B0,
          isBuiltIn: true,
          sortOrder: 2),
      StatusTag(
          id: 'tag_chorus',
          name: '合唱',
          colorValue: 0xFF2196F3,
          isBuiltIn: true,
          sortOrder: 3),
      StatusTag(
          id: 'tag_duty',
          name: '上岗',
          colorValue: 0xFF009688,
          isBuiltIn: true,
          sortOrder: 4),
      StatusTag(
          id: 'tag_absent',
          name: '未到',
          colorValue: 0xFFF44336,
          isBuiltIn: true,
          sortOrder: 5),
    ];

    for (final tag in defaultTags) {
      await box.put(tag.id, tag.toMap());
    }
  }

  // ==================== Members ====================
  static Box get _memberBox => Hive.box(_membersBox);

  static List<Member> getAllMembers() {
    return _memberBox.values
        .map((e) => Member.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> putMember(Member member) async {
    await _memberBox.put(member.id, member.toMap());
  }

  static Future<void> deleteMember(String id) async {
    await _memberBox.delete(id);
  }

  static Member? getMember(String id) {
    final data = _memberBox.get(id);
    if (data == null) return null;
    return Member.fromMap(Map<String, dynamic>.from(data as Map));
  }

  // ==================== StatusTags ====================
  static Box get _tagBox => Hive.box(_tagsBox);

  static List<StatusTag> getAllTags() {
    return _tagBox.values
        .map((e) => StatusTag.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  static Future<void> putTag(StatusTag tag) async {
    await _tagBox.put(tag.id, tag.toMap());
  }

  static Future<void> deleteTag(String id) async {
    await _tagBox.delete(id);
  }

  static StatusTag? getTag(String id) {
    final data = _tagBox.get(id);
    if (data == null) return null;
    return StatusTag.fromMap(Map<String, dynamic>.from(data as Map));
  }

  // ==================== Sessions ====================
  static Box get _sessionBox => Hive.box(_sessionsBox);

  static List<Session> getAllSessions() {
    return _sessionBox.values
        .map((e) => Session.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static List<Session> getOngoingSessions() {
    return getAllSessions()
        .where((s) => s.status == 'ongoing')
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static List<Session> getArchivedSessions() {
    return getAllSessions()
        .where((s) => s.status == 'archived')
        .toList()
      ..sort((a, b) => (b.endedAt ?? b.createdAt).compareTo(a.endedAt ?? a.createdAt));
  }

  static Future<void> putSession(Session session) async {
    await _sessionBox.put(session.id, session.toMap());
  }

  static Future<void> deleteSession(String id) async {
    await _sessionBox.delete(id);
  }

  static Session? getSession(String id) {
    final data = _sessionBox.get(id);
    if (data == null) return null;
    return Session.fromMap(Map<String, dynamic>.from(data as Map));
  }

  // ==================== CheckIns ====================
  static Box get _checkInBox => Hive.box(_checkInsBox);

  static List<CheckIn> getAllCheckIns() {
    return _checkInBox.values
        .map((e) => CheckIn.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static List<CheckIn> getCheckInsForSession(String sessionId) {
    return getAllCheckIns()
        .where((c) => c.sessionId == sessionId && !c.isUndone)
        .toList();
  }

  static List<CheckIn> getCheckInsForMember(String memberId) {
    return getAllCheckIns()
        .where((c) => c.memberId == memberId)
        .toList();
  }

  static CheckIn? getActiveCheckIn(String sessionId, String memberId) {
    final list = getAllCheckIns()
        .where((c) =>
            c.sessionId == sessionId &&
            c.memberId == memberId &&
            !c.isUndone)
        .toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
    return list.first;
  }

  static Future<void> putCheckIn(CheckIn checkIn) async {
    await _checkInBox.put(checkIn.id, checkIn.toMap());
  }

  // ==================== OperationLogs ====================
  static Box get _logBox => Hive.box(_logsBox);

  static List<OperationLog> getAllLogs() {
    return _logBox.values
        .map((e) =>
            OperationLog.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static List<OperationLog> getLogsForSession(String sessionId) {
    return getAllLogs()
        .where((l) => l.sessionId == sessionId)
        .toList();
  }

  static Future<void> putLog(OperationLog log) async {
    await _logBox.put(log.id, log.toMap());
  }

  // ==================== Utility ====================
  static Future<void> clearAll() async {
    await _memberBox.clear();
    await _tagBox.clear();
    await _sessionBox.clear();
    await _checkInBox.clear();
    await _logBox.clear();
    await _initDefaultTags();
  }
}
