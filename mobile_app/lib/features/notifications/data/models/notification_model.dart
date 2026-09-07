
/// ============================================================================
/// NOTIFICATION MODEL
/// ============================================================================
///
/// Maps directly to the Supabase `notifications` table.
///
/// Database columns:
/// - id
/// - user_id
/// - title
/// - message
/// - notification_type
/// - is_read
/// - created_at
///
/// This model contains no database logic.
/// ============================================================================

library;

class NotificationModel {
  // ==========================================================================
  // FIELDS
  // ==========================================================================

  final String id;
  final String userId;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final DateTime createdAt;

  // ==========================================================================
  // CONSTRUCTOR
  // ==========================================================================

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.isRead,
    required this.createdAt,
  });

  // ==========================================================================
  // FROM JSON
  // ==========================================================================

  factory NotificationModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawCreatedAt = json['created_at'];

    DateTime createdAt;

    if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt.toLocal();
    } else {
      final createdAtString = rawCreatedAt?.toString() ?? '';

      createdAt = DateTime.tryParse(createdAtString)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      notificationType:
          json['notification_type']?.toString() ?? '',
      isRead: json['is_read'] == true,
      createdAt: createdAt,
    );
  }

  // ==========================================================================
  // TO JSON
  // ==========================================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'message': message,
      'notification_type': notificationType,
      'is_read': isRead,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  // ==========================================================================
  // COPY WITH
  // ==========================================================================

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? notificationType,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      notificationType:
          notificationType ?? this.notificationType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  bool get isUnread => !isRead;

  // ==========================================================================
  // EQUALITY
  // ==========================================================================

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is NotificationModel &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.message == message &&
        other.notificationType == notificationType &&
        other.isRead == isRead &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      userId,
      title,
      message,
      notificationType,
      isRead,
      createdAt,
    );
  }

  // ==========================================================================
  // DEBUG
  // ==========================================================================

  @override
  String toString() {
    return 'NotificationModel('
        'id: $id, '
        'userId: $userId, '
        'title: $title, '
        'message: $message, '
        'notificationType: $notificationType, '
        'isRead: $isRead, '
        'createdAt: $createdAt'
        ')';
  }
}