import 'package:hive/hive.dart';

/// 具体行为（如：跑代码、发呆、跑步）
@HiveType(typeId: 1)
class ActionItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String categoryId; // 关联的分类ID

  @HiveField(3)
  bool isPinned; // 是否在首屏大按钮置顶

  @HiveField(4)
  int sortOrder; // 排序顺序

  @HiveField(5)
  int updatedAtMillis;

  @HiveField(6)
  bool isDeleted;

  @HiveField(7)
  int deletedAtMillis;

  ActionItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.isPinned = false,
    this.sortOrder = 0,
    int? updatedAtMillis,
    bool? isDeleted,
    int? deletedAtMillis,
  })  : updatedAtMillis = updatedAtMillis ?? DateTime.now().millisecondsSinceEpoch,
        isDeleted = isDeleted ?? false,
        deletedAtMillis = deletedAtMillis ?? 0;
}
