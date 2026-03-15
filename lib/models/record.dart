import 'package:hive/hive.dart';

/// 时间记录（采用快照存储，防止外键级联删除导致历史记录丢失）
@HiveType(typeId: 2)
class Record extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final String actionName; // 存文本快照，不存外键

  @HiveField(3)
  final String categoryName; // 存文本快照，不存外键

  @HiveField(4)
  final String colorHex; // 存颜色快照，用于UI展示

  @HiveField(5)
  final String? note; // 可选备注，允许后续编辑

  @HiveField(6)
  final int updatedAtMillis;

  @HiveField(7)
  final bool isDeleted;

  @HiveField(8)
  final int deletedAtMillis;

  Record({
    required this.id,
    required this.timestamp,
    required this.actionName,
    required this.categoryName,
    required this.colorHex,
    this.note,
    int? updatedAtMillis,
    bool? isDeleted,
    int? deletedAtMillis,
  })  : updatedAtMillis = updatedAtMillis ?? DateTime.now().millisecondsSinceEpoch,
        isDeleted = isDeleted ?? false,
        deletedAtMillis = deletedAtMillis ?? 0;
}
