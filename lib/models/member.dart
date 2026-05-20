import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Member {
  final String id;
  final String name;
  final String? studentId;
  final DateTime createdAt;

  Member({
    String? id,
    required this.name,
    this.studentId,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'studentId': studentId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      name: map['name'] as String,
      studentId: map['studentId'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  Member copyWith({
    String? name,
    String? studentId,
  }) {
    return Member(
      id: id,
      name: name ?? this.name,
      studentId: studentId ?? this.studentId,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Member && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
