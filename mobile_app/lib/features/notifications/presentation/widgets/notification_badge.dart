import 'package:flutter/material.dart';

/// ============================================================================
/// NOTIFICATION BADGE
/// ============================================================================
///
/// Reusable badge for displaying an unread notification count.
///
/// Responsibilities:
/// - Display unread notification count.
/// - Hide itself when the count is zero.
/// - Keep the badge visually compact.
///
/// This widget does NOT:
/// - Query Supabase.
/// - Load notifications.
/// - Modify notification state.
/// ============================================================================

class NotificationBadge extends StatelessWidget {
  final int count;

  final Widget child;

  final Color? backgroundColor;

  final Color? textColor;

  const NotificationBadge({
    super.key,
    required this.count,
    required this.child,
    this.backgroundColor,
    this.textColor,
  });

  // ==========================================================================
  // BADGE TEXT
  // ==========================================================================

  String _badgeText() {
    if (count > 99) {
      return '99+';
    }

    return count.toString();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    // No unread notifications.
    if (count <= 0) {
      return child;
    }

    final badgeBackground =
        backgroundColor ?? colors.error;

    final badgeTextColor =
        textColor ?? colors.onError;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,

        // ====================================================================
        // BADGE
        // ====================================================================

        Positioned(
          top: -4,
          right: -4,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colors.surface,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _badgeText(),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(
                    color: badgeTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}