import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class OperationLog {
  final String id;
  final String sessionId;
  final String type; // 'check_in', 'undo', 'edit_note'
  final String targetMemberId;
  final String? prevStatusId;
  final String? newStatusId;
  final DateTime timestamp;
  final String? note;

  OperationLog({
    String? id,
    required this.sessionId,
    required this.type,
    required this.targetMemberId,
    this.prevStatusId,
    this.newStatusId,
    DateTime? timestamp,
    this.note,
  })  : id = id ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'type': type,
      'targetMemberId': targetMemberId,
      'prevStatusId': prevStatusId,
      'newStatusId': newStatusId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'note': note,
    };
  }

  factory OperationLog.fromMap(Map<String, dynamic> map) {
    return OperationLog(
      id: map['id'] as String,
      sessionId: map['sessionId'] as String,
      type: map['type'] as String,
      targetMemberId: map['targetMemberId'] as String,
      prevStatusId: map['prevStatusId'] as String?,
      newStatusId: map['newStatusId'] as String?,
      timestamp:
          DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      note: map['note'] as String?,
    );
  }

  bool get isUndoable {
    if (type != 'check_in') return false;
    return DateTime.now().difference(timestamp).inHours < 72;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OperationLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
