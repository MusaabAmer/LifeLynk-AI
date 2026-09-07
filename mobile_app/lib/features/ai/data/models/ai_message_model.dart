import 'package:flutter/foundation.dart';

/// Represents a single message inside an AI conversation.
@immutable
class AiMessageModel {
  final String id;
  final String content;
  final AiMessageRole role;
  final DateTime createdAt;

  const AiMessageModel({
    required this.id,
    required this.content,
    required this.role,
    required this.createdAt,
  });

  /// Creates a user message.
  factory AiMessageModel.user({
    required String content,
    String? id,
  }) {
    return AiMessageModel(
      id: id ?? _generateId(),
      content: content,
      role: AiMessageRole.user,
      createdAt: DateTime.now(),
    );
  }

  /// Creates an AI assistant message.
  factory AiMessageModel.assistant({
    required String content,
    String? id,
  }) {
    return AiMessageModel(
      id: id ?? _generateId(),
      content: content,
      role: AiMessageRole.assistant,
      createdAt: DateTime.now(),
    );
  }

  /// Creates a model from JSON.
  factory AiMessageModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AiMessageModel(
      id: json['id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      role: AiMessageRole.fromString(
        json['role']?.toString(),
      ),
      createdAt: DateTime.tryParse(
            json['created_at']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  /// Converts the model to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role.value,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Creates a copy with modified values.
  AiMessageModel copyWith({
    String? id,
    String? content,
    AiMessageRole? role,
    DateTime? createdAt,
  }) {
    return AiMessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isUser => role == AiMessageRole.user;

  bool get isAssistant => role == AiMessageRole.assistant;

  @override
  String toString() {
    return 'AiMessageModel('
        'id: $id, '
        'role: ${role.value}, '
        'content: $content, '
        'createdAt: $createdAt'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AiMessageModel &&
        other.id == id &&
        other.content == content &&
        other.role == role &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      content,
      role,
      createdAt,
    );
  }

  static String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}

/// Defines who sent an AI message.
enum AiMessageRole {
  user,
  assistant;

  String get value {
    switch (this) {
      case AiMessageRole.user:
        return 'user';

      case AiMessageRole.assistant:
        return 'assistant';
    }
  }

  static AiMessageRole fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'assistant':
      case 'ai':
      case 'bot':
        return AiMessageRole.assistant;

      case 'user':
      default:
        return AiMessageRole.user;
    }
  }
}