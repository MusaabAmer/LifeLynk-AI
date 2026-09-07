import 'package:flutter/material.dart';

import '../../data/models/notification_model.dart';

/// ============================================================================
/// NOTIFICATION CARD
/// ============================================================================
///
/// Reusable UI component for displaying a single notification.
///
/// Responsibilities:
/// - Display notification information.
/// - Visually distinguish read/unread notifications.
/// - Provide tap and delete callbacks.
///
/// This widget does NOT:
/// - Query Supabase.
/// - Change database state.
/// - Manage notification state.
/// ============================================================================

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;

  final VoidCallback? onTap;

  final VoidCallback? onDelete;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onDelete,
  });

  // ==========================================================================
  // NOTIFICATION ICON
  // ==========================================================================

  IconData _notificationIcon(
    String type,
  ) {
    switch (type.toLowerCase().trim()) {
      case 'emergency':
      case 'sos':
        return Icons.emergency_rounded;

      case 'blood':
      case 'blood_request':
      case 'blood_available':
        return Icons.bloodtype_rounded;

      case 'donation':
      case 'donor':
        return Icons.volunteer_activism_rounded;

      case 'reservation':
        return Icons.event_available_rounded;

      case 'hospital':
        return Icons.local_hospital_rounded;

      case 'system':
        return Icons.notifications_active_rounded;

      case 'success':
        return Icons.check_circle_rounded;

      case 'warning':
        return Icons.warning_rounded;

      case 'error':
        return Icons.error_rounded;

      default:
        return Icons.notifications_rounded;
    }
  }

  // ==========================================================================
  // NOTIFICATION COLOR
  // ==========================================================================

  Color _notificationColor(
    BuildContext context,
    String type,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    switch (type.toLowerCase().trim()) {
      case 'emergency':
      case 'sos':
      case 'error':
        return colors.error;

      case 'blood':
      case 'blood_request':
      case 'blood_available':
        return Colors.red;

      case 'donation':
      case 'donor':
        return Colors.teal;

      case 'reservation':
        return colors.primary;

      case 'hospital':
        return Colors.blue;

      case 'success':
        return Colors.green;

      case 'warning':
        return Colors.orange;

      default:
        return colors.primary;
    }
  }

  // ==========================================================================
  // TIME FORMAT
  // ==========================================================================

  String _formatTime(
    DateTime dateTime,
  ) {
    final now = DateTime.now();

    final difference =
        now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      final minutes =
          difference.inMinutes;

      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }

    if (difference.inHours < 24) {
      final hours =
          difference.inHours;

      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    final day =
        dateTime.day.toString().padLeft(2, '0');

    final month =
        dateTime.month.toString().padLeft(2, '0');

    final year =
        dateTime.year.toString();

    return '$day/$month/$year';
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    final notificationColor =
        _notificationColor(
      context,
      notification.notificationType,
    );

    final icon =
        _notificationIcon(
      notification.notificationType,
    );

    return Material(
      color: notification.isRead
          ? colors.surface
          : colors.primaryContainer
              .withValues(alpha: 0.30),
      borderRadius:
          BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(18),
        child: Padding(
          padding:
              const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ==============================================================
              // ICON
              // ==============================================================

              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: notificationColor
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: notificationColor,
                  size: 22,
                ),
              ),

              const SizedBox(width: 12),

              // ==============================================================
              // CONTENT
              // ==============================================================

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight:
                                      notification.isRead
                                          ? FontWeight.w600
                                          : FontWeight.w800,
                                ),
                          ),
                        ),

                        if (!notification.isRead)
                          Container(
                            margin:
                                const EdgeInsets.only(
                              left: 8,
                              top: 5,
                            ),
                            width: 8,
                            height: 8,
                            decoration:
                                BoxDecoration(
                              color:
                                  notificationColor,
                              shape:
                                  BoxShape.circle,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow:
                          TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color:
                                colors.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color:
                              colors.onSurfaceVariant,
                        ),

                        const SizedBox(width: 4),

                        Flexible(
                          child: Text(
                            _formatTime(
                              notification.createdAt,
                            ),
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: colors
                                          .onSurfaceVariant,
                                      fontWeight:
                                          FontWeight.w500,
                                    ),
                          ),
                        ),

                        if (onDelete != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: onDelete,
                            visualDensity:
                                VisualDensity.compact,
                            padding:
                                EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            tooltip:
                                'Delete notification',
                            icon: Icon(
                              Icons
                                  .delete_outline_rounded,
                              size: 18,
                              color: colors
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

