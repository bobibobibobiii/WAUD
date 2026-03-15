import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'database_service.dart';
import '../models/models.dart';

/// 通知服务 - 弹夹排期逻辑
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  static Function(String?)? onNotificationTap;

  Future<void> init() async {
    tz_data.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  static void _onNotificationResponse(NotificationResponse response) {
    onNotificationTap?.call(response.payload);
  }

  Future<bool> requestPermission() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  Future<void> reloadNotifications() async {
    final db = DatabaseService();
    final settings = db.settings;
    
    if (!settings.notificationsEnabled) {
      await cancelAll();
      return;
    }

    final intervalMinutes = settings.notificationIntervalMinutes;
    
    await cancelAll();

    final now = tz.TZDateTime.now(tz.local);
    
    int scheduledCount = 0;
    int checkIndex = 0;
    const maxCheck = 200;
    
    while (scheduledCount < 60 && checkIndex < maxCheck) {
      final scheduleTime = now.add(Duration(minutes: intervalMinutes * (checkIndex + 1)));
      
      if (!_isInSleepTime(scheduleTime, settings)) {
        await _scheduleNotification(
          id: scheduledCount,
          scheduledTime: scheduleTime,
        );
        scheduledCount++;
      }
      
      checkIndex++;
    }
  }

  bool _isInSleepTime(tz.TZDateTime time, Settings settings) {
    final hour = time.hour;
    final minute = time.minute;
    final currentMinutes = hour * 60 + minute;
    
    final sleepStart = settings.sleepStartHour * 60 + settings.sleepStartMinute;
    final sleepEnd = settings.sleepEndHour * 60 + settings.sleepEndMinute;
    
    if (sleepStart > sleepEnd) {
      return currentMinutes >= sleepStart || currentMinutes < sleepEnd;
    } else {
      if (sleepStart == sleepEnd) return false;
      return currentMinutes >= sleepStart && currentMinutes < sleepEnd;
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required tz.TZDateTime scheduledTime,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'waud_reminder',
      '在干啥提醒',
      channelDescription: '定时提醒你记录当前在做什么',
      importance: Importance.high,
      priority: Priority.high,
      ticker: '在干啥',
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      '在干啥？',
      '点击记录你现在正在做的事',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'quick_record',
      matchDateTimeComponents: null,
    );
  }

  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  Future<String?> getInitialNotificationPayload() async {
    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp ?? false) {
      return details?.notificationResponse?.payload;
    }
    return null;
  }
}
