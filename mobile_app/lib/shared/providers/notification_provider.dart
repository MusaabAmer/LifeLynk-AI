import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/notification_model.dart';

class NotificationNotifier extends Notifier<List<NotificationModel>> {
  @override
  List<NotificationModel> build() {
    return [
      NotificationModel(
        id: 'notif-1',
        title: 'Reservation Approved!',
        message:
            'Your reservation for 2 units of O+ blood at Shaukat Khanum Hospital has been approved.',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        type: NotificationType.reservationApproved,
      ),
      NotificationModel(
        id: 'notif-2',
        title: 'Emergency Stock Alert',
        message: 'Urgent need for O- negative blood at Doctors Hospital Lahore.',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        type: NotificationType.emergencyAlert,
      ),
      NotificationModel(
        id: 'notif-3',
        title: 'Donation Reminder',
        message:
            'It has been 90 days since your last donation. You are eligible to donate again!',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        type: NotificationType.announcement,
        isRead: true,
      ),
    ];
  }

  void markAsRead(String id) {
    state = state.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
  }

  void deleteNotification(String id) {
    state = state.where((n) => n.id != id).toList();
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, List<NotificationModel>>(
  NotificationNotifier.new,
);
