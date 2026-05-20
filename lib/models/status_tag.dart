import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class StatusTag {
  final String id;
  final String name;
  final int colorValue;
  final bool isBuiltIn;
  final int sortOrder;

  StatusTag({
    String? id,
    required this.name,
    required this.colorValue,
    this.isBuiltIn = false,
    this.sortOrder = 0,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'colorValue': colorValue,
      'isBuiltIn': isBuiltIn,
      'sortOrder': sortOrder,
    };
  }

  factory StatusTag.fromMap(Map<String, dynamic> map) {
    return StatusTag(
      id: map['id'] as String,
      name: map['name'] as String,
      colorValue: map['colorValue'] as int,
      isBuiltIn: map['isBuiltIn'] as bool? ?? false,
      sortOrder: map['sortOrder'] as int? ?? 0,
    );
  }

  StatusTag copyWith({
    String? name,
    int? colorValue,
    int? sortOrder,
  }) {
    return StatusTag(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      isBuiltIn: isBuiltIn,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StatusTag && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
