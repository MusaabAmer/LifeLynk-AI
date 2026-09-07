import 'package:flutter/foundation.dart';

import 'ai_message_model.dart';

/// Represents a complete AI chat conversation.
@immutable
class AiConversationModel {
  final String id;
  final String title;
  final List<AiMessageModel> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiConversationModel({
    required this.id,
    required this.title,
    this.messages = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a new empty conversation.
  factory AiConversationModel.create({
    String? id,
    String? title,
  }) {
    final now = DateTime.now();

    return AiConversationModel(
      id: id ?? _generateId(),
      title: title ?? 'New Conversation',
      messages: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Creates a conversation from JSON.
  factory AiConversationModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final messagesJson = json['messages'];

    final messages = messagesJson is List
        ? messagesJson
            .whereType<Map<String, dynamic>>()
            .map(AiMessageModel.fromJson)
            .toList()
        : <AiMessageModel>[];

    final createdAt = DateTime.tryParse(
          json['created_at']?.toString() ?? '',
        ) ??
        DateTime.now();

    final updatedAt = DateTime.tryParse(
          json['updated_at']?.toString() ?? '',
        ) ??
        createdAt;

    return AiConversationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'New Conversation',
      messages: messages,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Converts the conversation to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages
          .map((message) => message.toJson())
          .toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Creates a copy with modified values.
  AiConversationModel copyWith({
    String? id,
    String? title,
    List<AiMessageModel>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AiConversationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Adds a message and updates the conversation timestamp.
  AiConversationModel addMessage(
    AiMessageModel message,
  ) {
    return copyWith(
      messages: [
        ...messages,
        message,
      ],
      updatedAt: DateTime.now(),
    );
  }

  /// Removes all messages from the conversation.
  AiConversationModel clearMessages() {
    return copyWith(
      messages: const [],
      updatedAt: DateTime.now(),
    );
  }

  /// Returns the most recent message.
  AiMessageModel? get lastMessage {
    if (messages.isEmpty) {
      return null;
    }

    return messages.last;
  }

  /// Returns whether the conversation contains messages.
  bool get hasMessages => messages.isNotEmpty;

  /// Number of messages in the conversation.
  int get messageCount => messages.length;

  /// Automatically generates a useful title from the first
  /// user message when the conversation still has the default title.
  AiConversationModel generateTitleFromFirstMessage() {
    if (title != 'New Conversation') {
      return this;
    }

    final firstUserMessage = messages.cast<AiMessageModel?>().firstWhere(
          (message) => message?.isUser == true,
          orElse: () => null,
        );

    if (firstUserMessage == null ||
        firstUserMessage.content.trim().isEmpty) {
      return this;
    }

    final content = firstUserMessage.content.trim();

    final generatedTitle = content.length > 40
        ? '${content.substring(0, 40).trim()}...'
        : content;

    return copyWith(
      title: generatedTitle,
    );
  }

  @override
  String toString() {
    return 'AiConversationModel('
        'id: $id, '
        'title: $title, '
        'messages: ${messages.length}, '
        'createdAt: $createdAt, '
        'updatedAt: $updatedAt'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AiConversationModel &&
        other.id == id &&
        other.title == title &&
        listEquals(other.messages, messages) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      Object.hashAll(messages),
      createdAt,
      updatedAt,
    );
  }

  static String _generateId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}