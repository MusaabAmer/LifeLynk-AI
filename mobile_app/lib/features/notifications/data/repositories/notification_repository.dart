import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';

/// ============================================================================
/// NOTIFICATION REPOSITORY
/// ============================================================================
///
/// Handles all database operations for notifications.
///
/// Responsibilities:
/// - Fetch notifications.
/// - Fetch a single notification.
/// - Fetch unread notification count.
/// - Mark notifications as read/unread.
/// - Mark all notifications as read.
/// - Delete notifications.
/// - Delete all read notifications.
/// - Listen for realtime notification changes.
///
/// This repository does NOT:
/// - Manage UI state.
/// - Show dialogs/snackbars.
/// - Depend on Flutter widgets.
/// - Store notification state.
///
/// Supabase `notifications` is the source of truth.
/// ============================================================================

class NotificationRepository {
  final SupabaseClient _supabase;

  static const String _tableName = 'notifications';

  NotificationRepository({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  // ==========================================================================
  // CURRENT USER
  // ==========================================================================

  String _requireUserId() {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final userId = user.id.trim();

    if (userId.isEmpty) {
      throw Exception('Authenticated user ID is invalid.');
    }

    return userId;
  }

  // ==========================================================================
  // FETCH NOTIFICATIONS
  // ==========================================================================

  Future<List<NotificationModel>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final userId = _requireUserId();

    final safeLimit = limit.clamp(1, 100);
    final safeOffset = offset < 0 ? 0 : offset;

    final response = await _supabase
        .from(_tableName)
        .select()
        .eq('user_id', userId)
        .order(
          'created_at',
          ascending: false,
        )
        .range(
          safeOffset,
          safeOffset + safeLimit - 1,
        );

    return response
        .map(
          (json) => NotificationModel.fromJson(
            Map<String, dynamic>.from(json as Map),
          ),
        )
        .toList();
  }

  // ==========================================================================
  // FETCH SINGLE NOTIFICATION
  // ==========================================================================

  Future<NotificationModel?> getNotificationById(
    String notificationId,
  ) async {
    final userId = _requireUserId();
    final normalizedId = notificationId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    final response = await _supabase
        .from(_tableName)
        .select()
        .eq('id', normalizedId)
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return NotificationModel.fromJson(
      Map<String, dynamic>.from(response),
    );
  }

  // ==========================================================================
  // UNREAD COUNT
  // ==========================================================================

  Future<int> getUnreadCount() async {
    final userId = _requireUserId();

    final response = await _supabase
        .from(_tableName)
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);

    return response.length;
  }

  // ==========================================================================
  // MARK AS READ
  // ==========================================================================

  Future<void> markAsRead(
    String notificationId,
  ) async {
    final userId = _requireUserId();
    final normalizedId = notificationId.trim();

    if (normalizedId.isEmpty) {
      throw Exception('Notification ID is required.');
    }

    await _supabase
        .from(_tableName)
        .update({
          'is_read': true,
        })
        .eq('id', normalizedId)
        .eq('user_id', userId);
  }

  // ==========================================================================
  // MARK AS UNREAD
  // ==========================================================================

  Future<void> markAsUnread(
    String notificationId,
  ) async {
    final userId = _requireUserId();
    final normalizedId = notificationId.trim();

    if (normalizedId.isEmpty) {
      throw Exception('Notification ID is required.');
    }

    await _supabase
        .from(_tableName)
        .update({
          'is_read': false,
        })
        .eq('id', normalizedId)
        .eq('user_id', userId);
  }

  // ==========================================================================
  // MARK ALL AS READ
  // ==========================================================================

  Future<void> markAllAsRead() async {
    final userId = _requireUserId();

    await _supabase
        .from(_tableName)
        .update({
          'is_read': true,
        })
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  // ==========================================================================
  // DELETE NOTIFICATION
  // ==========================================================================

  Future<void> deleteNotification(
    String notificationId,
  ) async {
    final userId = _requireUserId();
    final normalizedId = notificationId.trim();

    if (normalizedId.isEmpty) {
      throw Exception('Notification ID is required.');
    }

    await _supabase
        .from(_tableName)
        .delete()
        .eq('id', normalizedId)
        .eq('user_id', userId);
  }

  // ==========================================================================
  // DELETE ALL READ NOTIFICATIONS
  // ==========================================================================

  Future<void> deleteAllRead() async {
    final userId = _requireUserId();

    await _supabase
        .from(_tableName)
        .delete()
        .eq('user_id', userId)
        .eq('is_read', true);
  }

  // ==========================================================================
  // REALTIME NOTIFICATION STREAM
  // ==========================================================================

  /// Returns the authenticated user's notifications as a realtime stream.
  ///
  /// Supabase Realtime automatically updates this stream when rows belonging
  /// to the current user are inserted, updated, or deleted.
  Stream<List<NotificationModel>> watchNotifications() {
    final userId = _requireUserId();

    return _supabase
        .from(_tableName)
        .stream(
          primaryKey: ['id'],
        )
        .eq(
          'user_id',
          userId,
        )
        .order(
          'created_at',
          ascending: false,
        )
        .map(
          (rows) => rows
              .map(
                (json) => NotificationModel.fromJson(
                  Map<String, dynamic>.from(json),
                ),
              )
              .toList(),
        );
  }

  // ==========================================================================
  // REALTIME UNREAD COUNT
  // ==========================================================================

  Stream<int> watchUnreadCount() {
    return watchNotifications().map(
      (notifications) => notifications
          .where(
            (notification) => notification.isUnread,
          )
          .length,
    );
  }
}