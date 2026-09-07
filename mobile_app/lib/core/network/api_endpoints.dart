class ApiEndpoints {
  ApiEndpoints._();

  static const String health = '/api/v1/health';

  static const String me = '/api/v1/me';
  static const String myProfile = '/api/v1/me/profile';

  static const String organizations = '/api/v1/organizations';

  static const String hospitals = '/api/v1/hospitals';
  static const String bloodBanks = '/api/v1/blood-banks';
  static const String inventory = '/api/v1/inventory';

  static const String donors = '/api/v1/donors';
  static const String myDonor = '/api/v1/donors/me';
  static const String myDonorAvailability =
      '/api/v1/donors/me/availability';

  static const String bloodRequests =
      '/api/v1/blood-requests';
  static const String myBloodRequests =
      '/api/v1/blood-requests/mine';
  static const String organizationBloodRequests =
      '/api/v1/blood-requests/organization';

  static const String sos = '/api/v1/sos';
  static const String activeSos = '/api/v1/sos/active';

  static const String notifications =
      '/api/v1/notifications';
  static const String unreadNotificationCount =
      '/api/v1/notifications/unread-count';
  static const String readAllNotifications =
      '/api/v1/notifications/read-all';
}
