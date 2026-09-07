import 'package:flutter/material.dart';

/// ============================================================================
/// NOTIFICATION EMPTY STATE
/// ============================================================================
///
/// Reusable UI component displayed when there are no notifications.
///
/// Responsibilities:
/// - Display an empty notification state.
/// - Provide an optional refresh action.
///
/// This widget does NOT:
/// - Query Supabase.
/// - Manage notification state.
/// - Perform database operations.
/// ============================================================================

class NotificationEmptyState extends StatelessWidget {
  final VoidCallback? onRefresh;

  const NotificationEmptyState({
    super.key,
    this.onRefresh,
  });

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 48,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ==================================================================
            // ICON
            // ==================================================================

            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(
                  alpha: 0.35,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: colors.primary,
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================================
            // TITLE
            // ==================================================================

            Text(
              'No notifications yet',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),

            const SizedBox(height: 8),

            // ==================================================================
            // DESCRIPTION
            // ==================================================================

            Text(
              'You’re all caught up. New notifications will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),

            // ==================================================================
            // REFRESH BUTTON
            // ==================================================================

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
}