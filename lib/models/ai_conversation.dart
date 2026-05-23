import 'dart:convert';

/// AI 对话模型
class AiConversation {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<Map<String, dynamic>> messages;

  AiConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  factory AiConversation.create({String? title}) {
    final now = DateTime.now();
    return AiConversation(
      id: 'conv_${now.millisecondsSinceEpoch}',
      title: title ?? '新对话',
      createdAt: now,
      updatedAt: now,
      messages: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'messages': messages,
    };
  }

  factory AiConversation.fromJson(Map<String, dynamic> json) {
    return AiConversation(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      messages: (json['messages'] as List).cast<Map<String, dynamic>>(),
    );
  }

  AiConversation copyWith({
    String? title,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? messages,
  }) {
    return AiConversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }
}
