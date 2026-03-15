import 'package:hive/hive.dart';
import 'settings.dart';

class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 3;

  @override
  Settings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Settings(
      notificationIntervalMinutes: fields[0] as int? ?? 30,
      sleepStartHour: fields[1] as int? ?? 23,
      sleepStartMinute: fields[2] as int? ?? 0,
      sleepEndHour: fields[3] as int? ?? 8,
      sleepEndMinute: fields[4] as int? ?? 0,
      isDarkMode: fields[5] as bool? ?? false,
      notificationsEnabled: fields[6] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.notificationIntervalMinutes)
      ..writeByte(1)
      ..write(obj.sleepStartHour)
      ..writeByte(2)
      ..write(obj.sleepStartMinute)
      ..writeByte(3)
      ..write(obj.sleepEndHour)
      ..writeByte(4)
      ..write(obj.sleepEndMinute)
      ..writeByte(5)
      ..write(obj.isDarkMode)
      ..writeByte(6)
      ..write(obj.notificationsEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
