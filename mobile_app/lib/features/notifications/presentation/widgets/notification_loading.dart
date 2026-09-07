import 'package:flutter/material.dart';

/// ============================================================================
/// NOTIFICATION LOADING
/// ============================================================================
///
/// Reusable loading state for the notification module.
///
/// Responsibilities:
/// - Display a loading indicator while notifications are being loaded.
///
/// This widget does NOT:
/// - Query Supabase.
/// - Manage notification state.
/// - Perform database operations.
/// ============================================================================

class NotificationLoading extends StatelessWidget {
  final String? message;

  const NotificationLoading({
    super.key,
    this.message,
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
            // LOADING INDICATOR
            // ==================================================================

            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colors.primary,
              ),
            ),

            // ==================================================================
            // MESSAGE
            // ==================================================================

            if (message != null) ...[
              const SizedBox(height: 16),

              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}