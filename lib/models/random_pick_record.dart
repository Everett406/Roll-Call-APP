import 'dart:convert';

/// Record of a random pick operation
class RandomPickRecord {
  final String id;
  final String memberId;
  final String memberName;
  final String? studentId;
  final DateTime pickedAt;

  RandomPickRecord({
    required this.id,
    required this.memberId,
    required this.memberName,
    this.studentId,
    required this.pickedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'memberId': memberId,
        'memberName': memberName,
        'studentId': studentId,
        'pickedAt': pickedAt.toIso8601String(),
      };

  factory RandomPickRecord.fromJson(Map<String, dynamic> json) =>
      RandomPickRecord(
        id: json['id'] as String,
        memberId: json['memberId'] as String,
        memberName: json['memberName'] as String,
        studentId: json['studentId'] as String?,
        pickedAt: DateTime.parse(json['pickedAt'] as String),
      );

  String toRawJson() => jsonEncode(toJson());
  factory RandomPickRecord.fromRawJson(String raw) =>
      RandomPickRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
