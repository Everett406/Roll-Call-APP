import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class CheckIn {
  final String id;
  final String sessionId;
  final String memberId;
  final String? statusId;
  final DateTime checkedAt;
  final String? note;
  final bool isUndone;

  CheckIn({
    String? id,
    required this.sessionId,
    required this.memberId,
    this.statusId,
    DateTime? checkedAt,
    this.note,
    this.isUndone = false,
  })  : id = id ?? _uuid.v4(),
        checkedAt = checkedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'memberId': memberId,
      'statusId': statusId,
      'checkedAt': checkedAt.millisecondsSinceEpoch,
      'note': note,
      'isUndone': isUndone,
    };
  }

  factory CheckIn.fromMap(Map<String, dynamic> map) {
    return CheckIn(
      id: map['id'] as String,
      sessionId: map['sessionId'] as String,
      memberId: map['memberId'] as String,
      statusId: map['statusId'] as String?,
      checkedAt:
          DateTime.fromMillisecondsSinceEpoch(map['checkedAt'] as int),
      note: map['note'] as String?,
      isUndone: map['isUndone'] as bool? ?? false,
    );
  }

  CheckIn copyWith({
    String? statusId,
    String? note,
    bool? isUndone,
  }) {
    return CheckIn(
      id: id,
      sessionId: sessionId,
      memberId: memberId,
      statusId: statusId ?? this.statusId,
      checkedAt: checkedAt,
      note: note ?? this.note,
      isUndone: isUndone ?? this.isUndone,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckIn && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
