import 'package:flutter/material.dart';

import '../../data/models/notification_model.dart';
import 'notification_card.dart';

/// ============================================================================
/// NOTIFICATION LIST
/// ============================================================================
///
/// Reusable UI component for displaying a list of notifications.
///
/// Responsibilities:
/// - Display multiple NotificationCard widgets.
/// - Handle loading state.
/// - Handle empty state.
/// - Forward tap and delete callbacks.
///
/// This widget does NOT:
/// - Query Supabase.
/// - Change notification state.
/// - Mark notifications as read.
/// - Delete notifications from the database.
/// ============================================================================

class NotificationList extends StatelessWidget {
  final List<NotificationModel> notifications;

  final bool isLoading;

  final VoidCallback? onRefresh;

  final void Function(NotificationModel notification)? onTap;

  final void Function(NotificationModel notification)? onDelete;

  const NotificationList({
    super.key,
    required this.notifications,
    this.isLoading = false,
    this.onRefresh,
    this.onTap,
    this.onDelete,
  });

  // ==========================================================================
  // EMPTY STATE
  // ==========================================================================

  Widget _buildEmptyState(
    BuildContext context,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(
                  alpha: 0.35,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 36,
                color: colors.primary,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'No notifications',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),

            const SizedBox(height: 6),

            Text(
              'You’re all caught up. New notifications will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),

            if (onRefresh != null) ...[
              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text(
                  'Refresh',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // LOADING STATE
  // ==========================================================================

  Widget _buildLoadingState(
    BuildContext context,
  ) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ),
    );
  }

  // ==========================================================================
  // NOTIFICATION ITEMS
  // ==========================================================================

  Widget _buildNotificationList(
    BuildContext context,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: notifications.length,
      separatorBuilder: (
        context,
        index,
      ) {
        return const SizedBox(height: 10);
      },
      itemBuilder: (
        context,
        index,
      ) {
        final notification = notifications[index];

        return NotificationCard(
          notification: notification,
          onTap: onTap == null
              ? null
              : () => onTap!(notification),
          onDelete: onDelete == null
              ? null
              : () => onDelete!(notification),
        );
      },
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (isLoading) {
      return _buildLoadingState(context);
    }

    if (notifications.isEmpty) {
      return _buildEmptyState(context);
    }

    return _buildNotificationList(context);
  }
}