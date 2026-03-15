class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static Function(String?)? onNotificationTap;

  Future<void> init() async {}

  Future<bool> requestPermission() async => false;

  Future<void> reloadNotifications() async {}

  Future<void> cancelAll() async {}

  Future<String?> getInitialNotificationPayload() async => null;
}
