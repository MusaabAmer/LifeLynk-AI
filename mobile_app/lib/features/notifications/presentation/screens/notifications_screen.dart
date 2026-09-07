import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/notification_provider.dart';
import '../widgets/notification_badge.dart';
import '../widgets/notification_empty_state.dart';
import '../widgets/notification_list.dart';
import '../widgets/notification_loading.dart';

/// ============================================================================
/// NOTIFICATIONS SCREEN
/// ============================================================================
///
/// Main screen for displaying the authenticated user's notifications.
///
/// Responsibilities:
/// - Display notification header.
/// - Display unread notification count.
/// - Display notification list.
/// - Forward user actions to NotificationProvider.
///
/// This screen does NOT:
/// - Query Supabase directly.
/// - Contain repository logic.
/// - Perform database operations directly.
/// ============================================================================

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
  });

  // ==========================================================================
  // APP BAR
  // ==========================================================================

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    NotificationProvider provider,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return AppBar(
      title: Row(
        children: [
          NotificationBadge(
            count: provider.unreadCount,
            child: Icon(
              Icons.notifications_rounded,
              color: colors.primary,
              size: 26,
            ),
          ),

          const SizedBox(width: 12),

          const Text('Notifications'),
        ],
      ),
      actions: [
        IconButton(
          onPressed:
              provider.loading || provider.refreshing
                  ? null
                  : provider.refreshNotifications,
          tooltip: 'Refresh notifications',
          icon: const Icon(
            Icons.refresh_rounded,
          ),
        ),

        const SizedBox(width: 4),
      ],
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  Widget _buildHeader(
    BuildContext context,
    NotificationProvider provider,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    final unreadCount =
        provider.unreadCount;

    if (unreadCount <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(
          alpha: 0.35,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.mark_email_unread_rounded,
            size: 20,
            color: colors.primary,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              unreadCount == 1
                  ? 'You have 1 unread notification.'
                  : 'You have $unreadCount unread notifications.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (
        context,
        provider,
        child,
      ) {
        return Scaffold(
          appBar: _buildAppBar(
            context,
            provider,
          ),
          body: Column(
            children: [
              _buildHeader(
                context,
                provider,
              ),

              const SizedBox(height: 8),

              Expanded(
                child: _buildBody(
                  context,
                  provider,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================================
  // BODY
  // ==========================================================================

  Widget _buildBody(
    BuildContext context,
    NotificationProvider provider,
  ) {
    // ========================================================================
    // INITIAL LOADING
    // ========================================================================

    if (provider.loading &&
        provider.notifications.isEmpty) {
      return const NotificationLoading(
        message: 'Loading notifications...',
      );
    }

    // ========================================================================
    // ERROR
    // ========================================================================

    if (provider.error != null &&
        provider.notifications.isEmpty) {
      return _buildErrorState(
        context,
        provider,
      );
    }

    // ========================================================================
    // EMPTY
    // ========================================================================

    if (provider.notifications.isEmpty) {
      return NotificationEmptyState(
        onRefresh:
            provider.refreshNotifications,
      );
    }

    // ========================================================================
    // LIST
    // ========================================================================

    return NotificationList(
      notifications:
          provider.notifications,
      isLoading:
          provider.loading ||
              provider.refreshing,
      onRefresh:
          provider.refreshNotifications,
      onTap: (notification) {
        if (notification.isUnread) {
          provider.markAsRead(
            notification.id,
          );
        }
      },
      onDelete: (notification) {
        provider.deleteNotification(
          notification.id,
        );
      },
    );
  }

  // ==========================================================================
  // ERROR STATE
  // ==========================================================================

  Widget _buildErrorState(
    BuildContext context,
    NotificationProvider provider,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_rounded,
              size: 52,
              color: colors.error,
            ),

            const SizedBox(height: 16),

            Text(
              'Unable to load notifications',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
            ),

            const SizedBox(height: 8),

            Text(
              provider.error ??
                  'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color:
                        colors.onSurfaceVariant,
                  ),
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed:
                  provider.loadNotifications,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}