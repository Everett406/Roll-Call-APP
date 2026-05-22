import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Member {
  final String id;
  final String name;
  final String? studentId;
  final DateTime? birthday; // 生日（月日）
  final DateTime createdAt;

  Member({
    String? id,
    required this.name,
    this.studentId,
    this.birthday,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'studentId': studentId,
      'birthday': birthday?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      name: map['name'] as String,
      studentId: map['studentId'] as String?,
      birthday: map['birthday'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['birthday'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    );
  }

  Member copyWith({
    String? name,
    String? studentId,
    DateTime? birthday,
  }) {
    return Member(
      id: id,
      name: name ?? this.name,
      studentId: studentId ?? this.studentId,
      birthday: birthday ?? this.birthday,
      createdAt: createdAt,
    );
  }

  /// 从身份证号解析生日
  /// 支持 15 位和 18 位身份证号
  static DateTime? parseBirthdayFromIdCard(String idCard) {
    if (idCard.length == 18) {
      // 18位身份证：第7-14位是出生日期YYYYMMDD
      final year = int.tryParse(idCard.substring(6, 10));
      final month = int.tryParse(idCard.substring(10, 12));
      final day = int.tryParse(idCard.substring(12, 14));
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    } else if (idCard.length == 15) {
      // 15位身份证：第7-12位是出生日期YYMMDD
      final yearStr = idCard.substring(6, 8);
      final year = int.tryParse('19$yearStr'); // 15位都是19XX年
      final month = int.tryParse(idCard.substring(8, 10));
      final day = int.tryParse(idCard.substring(10, 12));
      if (year != null && month != null && day != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Member && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
