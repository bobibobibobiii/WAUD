import 'package:hive/hive.dart';
import 'record.dart';

class RecordAdapter extends TypeAdapter<Record> {
  @override
  final int typeId = 2;

  @override
  Record read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Record(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      actionName: fields[2] as String,
      categoryName: fields[3] as String,
      colorHex: fields[4] as String,
      note: fields[5] as String?,
      updatedAtMillis: fields[6] as int? ?? 0,
      isDeleted: fields[7] as bool? ?? false,
      deletedAtMillis: fields[8] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, Record obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.actionName)
      ..writeByte(3)
      ..write(obj.categoryName)
      ..writeByte(4)
      ..write(obj.colorHex)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.updatedAtMillis)
      ..writeByte(7)
      ..write(obj.isDeleted)
      ..writeByte(8)
      ..write(obj.deletedAtMillis);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
