import 'package:hive/hive.dart';

/// 行为分类（如：科研、休息、运动）
@HiveType(typeId: 0)
class Category extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String colorHex; // UI展示颜色，如 "#8B9DC3"

  @HiveField(3)
  int updatedAtMillis;

  @HiveField(4)
  bool isDeleted;

  @HiveField(5)
  int deletedAtMillis;

  Category({
    required this.id,
    required this.name,
    required this.colorHex,
    int? updatedAtMillis,
    bool? isDeleted,
    int? deletedAtMillis,
  })  : updatedAtMillis = updatedAtMillis ?? DateTime.now().millisecondsSinceEpoch,
        isDeleted = isDeleted ?? false,
        deletedAtMillis = deletedAtMillis ?? 0;

  /// 获取 Color 对象
  int get colorValue => int.parse(colorHex.replaceFirst('#', '0xFF'));
}
