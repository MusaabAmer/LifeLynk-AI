import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../shared/models/notification_model.dart';
import '../../shared/providers/notification_provider.dart';

class NotificationListScreen extends ConsumerWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    final notifier = ref.read(notificationProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications (${notifications.where((n) => !n.isRead).length} Unread)'),
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                IconData notifIcon = Icons.notifications;
                Color iconColor = AppColors.primary;

                switch (notif.type) {
                  case NotificationType.reservationApproved:
                    notifIcon = Icons.check_circle;
                    iconColor = AppColors.success;
                    break;
                  case NotificationType.reservationRejected:
                    notifIcon = Icons.cancel;
                    iconColor = AppColors.error;
                    break;
                  case NotificationType.emergencyAlert:
                    notifIcon = Icons.warning_amber_rounded;
                    iconColor = AppColors.warning;
                    break;
                  case NotificationType.lowStockAlert:
                    notifIcon = Icons.inventory_2;
                    iconColor = Colors.orange;
                    break;
                  case NotificationType.announcement:
                    notifIcon = Icons.campaign;
                    iconColor = AppColors.secondary;
                    break;
                }

                return Dismissible(
                  key: Key(notif.id),
                  onDismissed: (_) => notifier.deleteNotification(notif.id),
                  background: Container(
                    color: AppColors.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    color: notif.isRead ? null : AppColors.primary.withAlpha(10),
                    child: ListTile(
                      onTap: () => notifier.markAsRead(notif.id),
                      leading: CircleAvatar(
                        backgroundColor: iconColor.withAlpha(20),
                        child: Icon(notifIcon, color: iconColor),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notif.title,
                              style: TextStyle(
                                fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!notif.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(notif.message, style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            Formatters.formatTime(notif.timestamp),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
