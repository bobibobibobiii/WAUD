import 'package:hive/hive.dart';

/// 应用设置
@HiveType(typeId: 3)
class Settings extends HiveObject {
  @HiveField(0)
  int notificationIntervalMinutes; // 通知间隔（分钟）

  @HiveField(1)
  int sleepStartHour; // 免打扰开始时间（小时）

  @HiveField(2)
  int sleepStartMinute; // 免打扰开始时间（分钟）

  @HiveField(3)
  int sleepEndHour; // 免打扰结束时间（小时）

  @HiveField(4)
  int sleepEndMinute; // 免打扰结束时间（分钟）

  @HiveField(5)
  bool isDarkMode; // 深色模式

  @HiveField(6)
  bool notificationsEnabled; // 是否启用通知

  Settings({
    this.notificationIntervalMinutes = 30,
    this.sleepStartHour = 23,
    this.sleepStartMinute = 0,
    this.sleepEndHour = 8,
    this.sleepEndMinute = 0,
    this.isDarkMode = false,
    this.notificationsEnabled = true,
  });
}
