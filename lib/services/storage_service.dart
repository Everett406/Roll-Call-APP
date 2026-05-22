import 'package:hive_flutter/hive_flutter.dart';
import '../models/member.dart';
import '../models/status_tag.dart';
import '../models/session.dart';
import '../models/check_in.dart';
import '../models/operation_log.dart';
import '../models/group.dart';

class StorageService {
  static const String _membersBox = 'members';
  static const String _tagsBox = 'statusTags';
  static const String _sessionsBox = 'sessions';
  static const String _checkInsBox = 'checkIns';
  static const String _logsBox = 'operationLogs';
  static const String _groupsBox = 'groups';
  static const String _configBoxName = 'config';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_membersBox);
    await Hive.openBox(_tagsBox);
    await Hive.openBox(_sessionsBox);
    await Hive.openBox(_checkInsBox);
    await Hive.openBox(_logsBox);
    await Hive.openBox(_groupsBox);
    await Hive.openBox(_configBoxName);
    await Hive.openBox(_randomPickBox);
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
          id: 'tag_absent',
          name: '未到',
          colorValue: 0xFFF44336,
          isBuiltIn: true,
          sortOrder: 1),
      StatusTag(
          id: 'tag_sick',
          name: '病假',
          colorValue: 0xFFFF9800,
          isBuiltIn: true,
          sortOrder: 2),
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

  /// Delete a single check-in
  static Future<void> deleteCheckIn(String id) async {
    await _checkInBox.delete(id);
  }

  /// Delete a single log
  static Future<void> deleteLog(String id) async {
    await _logBox.delete(id);
  }

  /// Delete all check-ins for a session
  static Future<int> deleteCheckInsForSession(String sessionId) async {
    final keysToDelete = <dynamic>[];
    for (final entry in _checkInBox.toMap().entries) {
      final data = entry.value as Map<dynamic, dynamic>;
      if (data['sessionId'] == sessionId) {
        keysToDelete.add(entry.key);
      }
    }
    for (final key in keysToDelete) {
      await _checkInBox.delete(key);
    }
    return keysToDelete.length;
  }

  /// Delete all operation logs for a session
  static Future<int> deleteLogsForSession(String sessionId) async {
    final keysToDelete = <dynamic>[];
    for (final entry in _logBox.toMap().entries) {
      final data = entry.value as Map<dynamic, dynamic>;
      if (data['sessionId'] == sessionId) {
        keysToDelete.add(entry.key);
      }
    }
    for (final key in keysToDelete) {
      await _logBox.delete(key);
    }
    return keysToDelete.length;
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

  // ==================== Groups ====================
  static Box get _groupBox => Hive.box(_groupsBox);

  static List<Group> getAllGroups() {
    return _groupBox.values
        .map((e) => Group.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  static Future<void> putGroup(Group group) async {
    await _groupBox.put(group.id, group.toMap());
  }

  static Future<void> deleteGroup(String id) async {
    await _groupBox.delete(id);
  }

  static Group? getGroup(String id) {
    final data = _groupBox.get(id);
    if (data == null) return null;
    return Group.fromMap(Map<String, dynamic>.from(data as Map));
  }

  // ==================== Attendance Config ====================
  static Box get _configBox => Hive.box(_configBoxName);

  static const String _attendanceTagIdsKey = 'attendanceTagIds';

  /// Get the list of tag IDs that count as "attended" (present).
  /// Defaults to ['tag_arrived'] if not configured.
  static List<String> getAttendanceTagIds() {
    final dynamic raw = _configBox.get(_attendanceTagIdsKey);
    if (raw == null || raw is! List || raw.isEmpty) {
      return ['tag_arrived'];
    }
    return raw.cast<String>();
  }

  static Future<void> setAttendanceTagIds(List<String> ids) async {
    await _configBox.put(_attendanceTagIdsKey, ids);
  }

  static const String _showPercentageKey = 'showPercentageOnCards';

  /// Whether to show percentage (true) or count (false) on session cards.
  /// Defaults to true (percentage).
  static bool getShowPercentageOnCards() {
    final dynamic raw = _configBox.get(_showPercentageKey);
    if (raw == null) return true;
    return raw as bool;
  }

  static Future<void> setShowPercentageOnCards(bool value) async {
    await _configBox.put(_showPercentageKey, value);
  }

  static const String _confettiEnabledKey = 'confettiEnabled';

  /// Whether confetti effects are enabled.
  /// Defaults to true.
  static bool getConfettiEnabled() {
    final dynamic raw = _configBox.get(_confettiEnabledKey);
    if (raw == null) return true;
    return raw as bool;
  }

  static Future<void> setConfettiEnabled(bool value) async {
    await _configBox.put(_confettiEnabledKey, value);
  }

  // ==================== Random Pick Records ====================
  static const String _randomPickBox = 'randomPicks';
  static Box? _randomPickBoxInstance;

  static Box get _randomPickBoxInstanceGetter {
    _randomPickBoxInstance ??= Hive.box(_randomPickBox);
    return _randomPickBoxInstance!;
  }

  static Future<void> initRandomPickBox() async {
    await Hive.openBox(_randomPickBox);
  }

  static Future<void> putRandomPickRecord(Map<String, dynamic> data) async {
    await _randomPickBoxInstanceGetter.put(data['id'], data);
  }

  static List<Map<String, dynamic>> getAllRandomPickRecords() {
    final box = _randomPickBoxInstanceGetter;
    return box.values
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList()
      ..sort((a, b) => DateTime.parse(b['pickedAt'] as String)
          .compareTo(DateTime.parse(a['pickedAt'] as String)));
  }

  static Future<void> deleteRandomPickRecord(String id) async {
    await _randomPickBoxInstanceGetter.delete(id);
  }

  static Future<void> clearRandomPickRecords() async {
    await _randomPickBoxInstanceGetter.clear();
  }

  // ==================== Confetti Config ====================
  static const String _confettiColorKey = 'confettiColor';
  static const String _confettiShapeKey = 'confettiShape';
  static const String _confettiModeKey = 'confettiMode';
  static const String _confettiIntensityKey = 'confettiIntensity';

  // Color: 0=primary, 1=secondary, 2=tertiary, 3=rainbow(default)
  static int getConfettiColor() => _configBox.get(_confettiColorKey) ?? 3;
  static Future<void> setConfettiColor(int value) async =>
      _configBox.put(_confettiColorKey, value);

  // Shape: 0=circle, 1=square, 2=mixed(default)
  static int getConfettiShape() => _configBox.get(_confettiShapeKey) ?? 2;
  static Future<void> setConfettiShape(int value) async =>
      _configBox.put(_confettiShapeKey, value);

  // Mode: 0=explosive(default), 1=rain, 2=side, 3=corner
  static int getConfettiMode() => _configBox.get(_confettiModeKey) ?? 0;
  static Future<void> setConfettiMode(int value) async =>
      _configBox.put(_confettiModeKey, value);

  // Intensity: 0.1~1.0, default 0.7
  static double getConfettiIntensity() {
    final v = _configBox.get(_confettiIntensityKey);
    return v != null ? (v as double) : 0.7;
  }
  static Future<void> setConfettiIntensity(double value) async =>
      _configBox.put(_confettiIntensityKey, value);

  static const String _rankingCountKey = 'rankingCount';

  /// How many people to show in ranking lists (3~20). Defaults to 5.
  static int getRankingCount() {
    final v = _configBox.get(_rankingCountKey);
    if (v == null) return 5;
    final i = v as int;
    return i.clamp(3, 20);
  }

  static Future<void> setRankingCount(int value) async =>
      _configBox.put(_rankingCountKey, value.clamp(3, 20));

  // ==================== Utility ====================
  static Future<void> clearAll() async {
    await _memberBox.clear();
    await _tagBox.clear();
    await _sessionBox.clear();
    await _checkInBox.clear();
    await _logBox.clear();
    await _groupBox.clear();
    await _configBox.clear();
    await _initDefaultTags();
  }
}
