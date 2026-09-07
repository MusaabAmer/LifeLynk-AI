import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/notification_model.dart';
import '../../data/repositories/notification_repository.dart';

/// ============================================================================
/// NOTIFICATION PROVIDER
/// ============================================================================
///
/// Presentation-layer state manager for notifications.
///
/// Responsibilities:
/// - Load notifications.
/// - Refresh notifications.
/// - Track unread notifications.
/// - Mark notifications read/unread.
/// - Mark all notifications read.
/// - Delete notifications.
/// - Listen to Supabase Realtime.
/// - React to authentication changes.
/// - Clean up realtime/auth subscriptions.
///
/// Database operations are delegated to NotificationRepository.
/// ============================================================================

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repository;

  NotificationProvider({
    NotificationRepository? repository,
  }) : _repository = repository ?? NotificationRepository();

  // ==========================================================================
  // STATE
  // ==========================================================================

  List<NotificationModel> _notifications = [];

  bool _loading = false;
  bool _refreshing = false;
  bool _markingAsRead = false;
  bool _deleting = false;
  bool _realtimeStarted = false;
  bool _initializing = false;

  String? _error;

  StreamSubscription<List<NotificationModel>>?
      _notificationSubscription;

  StreamSubscription<AuthState>? _authSubscription;

  // ==========================================================================
  // GETTERS
  // ==========================================================================

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  bool get loading => _loading;

  bool get refreshing => _refreshing;

  bool get markingAsRead => _markingAsRead;

  bool get deleting => _deleting;

  bool get realtimeStarted => _realtimeStarted;

  String? get error => _error;

  int get unreadCount {
    return _notifications
        .where(
          (notification) => notification.isUnread,
        )
        .length;
  }

  bool get hasNotifications =>
      _notifications.isNotEmpty;

  bool get hasUnreadNotifications =>
      unreadCount > 0;

  // ==========================================================================
  // AUTH-AWARE INITIALIZATION
  // ==========================================================================

  Future<void> initializeForCurrentUser() async {
    if (_initializing) {
      return;
    }

    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      await stopRealtimeListener();
      clearNotifications();
      return;
    }

    _initializing = true;

    try {
      await stopRealtimeListener();

      await loadNotifications();

      if (Supabase.instance.client.auth.currentUser?.id ==
          user.id) {
        startRealtimeListener();
      }
    } finally {
      _initializing = false;
    }
  }

  // ==========================================================================
  // AUTH STATE LISTENER
  // ==========================================================================

  void startAuthListener() {
    _authSubscription?.cancel();

    _authSubscription = Supabase
        .instance
        .client
        .auth
        .onAuthStateChange
        .listen(
      (authState) async {
        final event = authState.event;
        final session = authState.session;

        if (session != null &&
            (event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.initialSession)) {
          await initializeForCurrentUser();
          return;
        }

        if (event == AuthChangeEvent.tokenRefreshed) {
          final currentUser =
              Supabase.instance.client.auth.currentUser;

          if (currentUser != null &&
              !_realtimeStarted) {
            startRealtimeListener();
          }

          return;
        }

        if (event == AuthChangeEvent.signedOut) {
          await stopRealtimeListener();
          clearNotifications();
        }
      },
    );
  }

  // ==========================================================================
  // LOAD NOTIFICATIONS
  // ==========================================================================

  Future<void> loadNotifications() async {
    if (_loading) {
      return;
    }

    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      await stopRealtimeListener();
      clearNotifications();
      return;
    }

    _loading = true;
    _error = null;

    if (hasListeners) {
      notifyListeners();
    }

    try {
      final notifications =
          await _repository.getNotifications();

      if (Supabase.instance.client.auth.currentUser?.id ==
          user.id) {
        _notifications = notifications;
      }
    } catch (e) {
      _error = _cleanError(e);
    } finally {
      _loading = false;

      if (hasListeners) {
        notifyListeners();
      }
    }
  }

  // ==========================================================================
  // REFRESH
  // ==========================================================================

  Future<void> refreshNotifications() async {
    if (_refreshing) {
      return;
    }

    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      await stopRealtimeListener();
      clearNotifications();
      return;
    }

    _refreshing = true;
    _error = null;

    if (hasListeners) {
      notifyListeners();
    }

    try {
      final notifications =
          await _repository.getNotifications();

      if (Supabase.instance.client.auth.currentUser?.id ==
          user.id) {
        _notifications = notifications;
      }
    } catch (e) {
      _error = _cleanError(e);
    } finally {
      _refreshing = false;

      if (hasListeners) {
        notifyListeners();
      }
    }
  }

  // ==========================================================================
  // MARK AS READ
  // ==========================================================================

  Future<bool> markAsRead(
    String notificationId,
  ) async {
    if (_markingAsRead) {
      return false;
    }

    final index = _notifications.indexWhere(
      (notification) =>
          notification.id == notificationId,
    );

    if (index == -1) {
      return false;
    }

    final notification = _notifications[index];

    if (notification.isRead) {
      return true;
    }

    _markingAsRead = true;
    _error = null;

    if (hasListeners) {
      notifyListeners();
    }

    try {
      await _repository.markAsRead(notificationId);

      _notifications[index] = notification.copyWith(
        isRead: true,
      );

      return true;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _markingAsRead = false;

      if (hasListeners) {
        notifyListeners();
      }
    }
  }

  // ==========================================================================
  // MARK AS UNREAD
  // ==========================================================================

  Future<bool> markAsUnread(
    String notificationId,
  ) async {
    if (_markingAsRead) {
      return false;
    }

    final index = _notifications.indexWhere(
      (notification) =>
          notification.id == notificationId,
    );

    if (index == -1) {
      return false;
    }

    final notification = _notifications[index];

    if (notification.isUnread) {
      return true;
    }

    _markingAsRead = true;
    _error = null;

    if (hasListeners) {
      notifyListeners();
    }

    try {
      await _repository.markAsUnread(notificationId);

      _notifications[index] = notification.copyWith(
        isRead: false,
      );

      return true;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _markingAsRead = false;

      if (hasListeners) {
        notifyListeners();
      }
    }
  }

  // ==========================================================================
  // MARK ALL AS READ
  // ==========================================================================

  Future<bool> markAllAsRead() async {
    if (_markingAsRead) {
      return false;
    }

    if (!hasUnreadNotifications) {
      return true;
    }

    _markingAsRead = true;
    _error = null;

    if (hasListeners) {
      notifyListeners();
    }

    try {
      await _repository.markAllAsRead();

      _notifications = _notifications
          .map(
            (notification) => notification.copyWith(
              isRead: true,
            ),
          )
          .toList();

      return true;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _markingAsRead = false;

      if (hasListeners) {
        notifyListeners();
      }
    }
  }

  // ==========================================================================
  // DELETE NOTIFICATION
  // ==========================================================================

  Future<bool> deleteNotification(
    String notificationId,
  ) async {
    if (_deleting) {
      return false;
    }

    final exists = _notifications.any(
      (notification) =>
          notification.id == notificationId,
    );

    if (!exists) {
      return false;
    }

    _deleting = true;
    _error = null;

    if (hasListeners) {
      notifyListeners();
    }

    try {
      await _repository.deleteNotification(
        notificationId,
      );

      _notifications.removeWhere(
        (notification) =>
            notification.id == notificationId,
      );

      return true;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _deleting = false;

      if (hasListeners) {
        notifyListeners();
      }
    }
  }

  // ==========================================================================
  // DELETE ALL READ
  // ==========================================================================

  Future<bool> deleteAllRead() async {
    if (_deleting) {
      return false;
    }

    final hasReadNotifications =
        _notifications.any(
      (notification) => notification.isRead,
    );

    if (!hasReadNotifications) {
      return true;
    }

    _deleting = true;
    _error = null;

    if (hasListeners) {
      notifyListeners();
    }

    try {
      await _repository.deleteAllRead();

      _notifications.removeWhere(
        (notification) => notification.isRead,
      );

      return true;
    } catch (e) {
      _error = _cleanError(e);
      return false;
    } finally {
      _deleting = false;

      if (hasListeners) {
        notifyListeners();
      }
    }
  }

  // ==========================================================================
  // REALTIME LISTENER
  // ==========================================================================

  void startRealtimeListener() {
    if (_realtimeStarted) {
      return;
    }

    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _error = 'User is not authenticated.';

      if (hasListeners) {
        notifyListeners();
      }

      return;
    }

    _notificationSubscription?.cancel();
    _notificationSubscription = null;

    try {
      _realtimeStarted = true;

      _notificationSubscription = _repository
          .watchNotifications()
          .listen(
        (notifications) {
          final currentUser =
              Supabase.instance.client.auth.currentUser;

          if (currentUser == null ||
              currentUser.id != user.id) {
            return;
          }

          _notifications = notifications;
          _error = null;

          if (hasListeners) {
            notifyListeners();
          }
        },
        onError: (error) {
          _error = _cleanError(error);

          if (hasListeners) {
            notifyListeners();
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      _realtimeStarted = false;
      _error = _cleanError(e);

      if (hasListeners) {
        notifyListeners();
      }
    }
  }

  // ==========================================================================
  // STOP REALTIME LISTENER
  // ==========================================================================

  Future<void> stopRealtimeListener() async {
    final subscription =
        _notificationSubscription;

    _notificationSubscription = null;
    _realtimeStarted = false;

    if (subscription != null) {
      await subscription.cancel();
    }

    if (hasListeners) {
      notifyListeners();
    }
  }

  // ==========================================================================
  // RESTART REALTIME LISTENER
  // ==========================================================================

  Future<void> restartRealtimeListener() async {
    await stopRealtimeListener();

    final user =
        Supabase.instance.client.auth.currentUser;

    if (user != null) {
      startRealtimeListener();
    }
  }

  // ==========================================================================
  // CLEAR NOTIFICATIONS
  // ==========================================================================

  void clearNotifications() {
    _notifications = [];
    _error = null;

    if (hasListeners) {
      notifyListeners();
    }
  }

  // ==========================================================================
  // CLEAR ERROR
  // ==========================================================================

  void clearError() {
    if (_error == null) {
      return;
    }

    _error = null;

    if (hasListeners) {
      notifyListeners();
    }
  }

  // ==========================================================================
  // ERROR HANDLING
  // ==========================================================================

  String _cleanError(Object error) {
    final message = error.toString().trim();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message.isEmpty
        ? 'An unexpected error occurred.'
        : message;
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _authSubscription?.cancel();

    _notificationSubscription = null;
    _authSubscription = null;

    _realtimeStarted = false;

    super.dispose();
  }
}