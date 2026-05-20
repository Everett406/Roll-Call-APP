import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

class Group {
  final String id;
  final String name;
  final List<String> memberIds;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int colorIndex;

  Group({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.createdAt,
    this.updatedAt,
    this.colorIndex = 0,
  });

  Group copyWith({
    String? name,
    List<String>? memberIds,
    DateTime? updatedAt,
    int? colorIndex,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      memberIds: memberIds ?? this.memberIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'memberIds': memberIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'colorIndex': colorIndex,
    };
  }

  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      memberIds: (map['memberIds'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      colorIndex: map['colorIndex'] as int? ?? 0,
    );
  }

  factory Group.create({
    required String name,
    List<String> memberIds = const [],
    int colorIndex = 0,
  }) {
    return Group(
      id: _uuid.v4(),
      name: name,
      memberIds: memberIds,
      createdAt: DateTime.now(),
      colorIndex: colorIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Group &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
