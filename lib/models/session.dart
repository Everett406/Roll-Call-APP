import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Session {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? endedAt;
  final String status; // 'ongoing' or 'archived'
  final List<String> memberIds;
  // memberNames is stored as a snapshot for archived sessions.
  // When a session is archived, the member's name at that time is preserved
  // in case the member is later deleted or renamed.
  final List<String> memberNames;

  Session({
    String? id,
    required this.title,
    DateTime? createdAt,
    this.endedAt,
    this.status = 'ongoing',
    List<String>? memberIds,
    List<String>? memberNames,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        memberIds = memberIds ?? [],
        memberNames = memberNames ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'endedAt': endedAt?.millisecondsSinceEpoch,
      'status': status,
      'memberIds': memberIds,
      'memberNames': memberNames,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '未命名',
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      endedAt: map['endedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endedAt'] as int)
          : null,
      status: map['status'] as String? ?? 'ongoing',
      memberIds: List<String>.from(map['memberIds'] as List? ?? []),
      memberNames: List<String>.from(map['memberNames'] as List? ?? []),
    );
  }

  Session copyWith({
    String? title,
    DateTime? endedAt,
    String? status,
    List<String>? memberIds,
    List<String>? memberNames,
  }) {
    return Session(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      memberIds: memberIds ?? this.memberIds,
      memberNames: memberNames ?? this.memberNames,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Session && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
