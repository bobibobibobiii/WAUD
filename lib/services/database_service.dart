import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'notification_service.dart';
import 'csv_exporter.dart';

/// 日/周/月/年周期枚举
enum Period { day, week, month, year }

/// 数据库服务 - 极简单例模式
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const String _categoryBox = 'categories';
  static const String _actionBox = 'actions';
  static const String _recordBox = 'records';
  static const String _settingsBox = 'settings';

  late Box<Category> categories;
  late Box<ActionItem> actions;
  late Box<Record> records;
  late Box<Settings> settingsBox;

  final _uuid = const Uuid();

  /// 初始化数据库
  Future<void> init() async {
    await Hive.initFlutter();

    // 注册适配器
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(ActionItemAdapter());
    Hive.registerAdapter(RecordAdapter());
    Hive.registerAdapter(SettingsAdapter());

    // 打开所有Box
    categories = await Hive.openBox<Category>(_categoryBox);
    actions = await Hive.openBox<ActionItem>(_actionBox);
    records = await Hive.openBox<Record>(_recordBox);
    settingsBox = await Hive.openBox<Settings>(_settingsBox);

    await _backfillUpdatedAtMillis();

    // 首次启动时创建默认数据
    if (categories.isEmpty) {
      await _createDefaultData();
    }
  }

  Future<void> _backfillUpdatedAtMillis() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final c in categories.values) {
      if (c.updatedAtMillis == 0) {
        c.updatedAtMillis = now;
        await categories.put(c.id, c);
      }
    }

    for (final a in actions.values) {
      if (a.updatedAtMillis == 0) {
        a.updatedAtMillis = now;
        await actions.put(a.id, a);
      }
    }

    for (final r in records.values) {
      if (r.updatedAtMillis == 0) {
        final updated = Record(
          id: r.id,
          timestamp: r.timestamp,
          actionName: r.actionName,
          categoryName: r.categoryName,
          colorHex: r.colorHex,
          note: r.note,
          updatedAtMillis: now,
          isDeleted: r.isDeleted,
          deletedAtMillis: r.deletedAtMillis,
        );
        await records.put(r.id, updated);
      }
    }
  }

  /// 创建默认数据
  Future<void> _createDefaultData() async {
    // 默认分类（莫兰迪色系）
    final defaultCategories = [
      Category(id: _uuid.v4(), name: '科研', colorHex: '#8B9DC3'),
      Category(id: _uuid.v4(), name: '休息', colorHex: '#A8D8B9'),
      Category(id: _uuid.v4(), name: '运动', colorHex: '#F4A261'),
      Category(id: _uuid.v4(), name: '娱乐', colorHex: '#E9C46A'),
      Category(id: _uuid.v4(), name: '生活', colorHex: '#CDB4DB'),
      Category(id: _uuid.v4(), name: '其他', colorHex: '#B5B5B5'),
    ];

    for (final cat in defaultCategories) {
      await categories.put(cat.id, cat);
    }

    // 默认行为
    final defaultActions = [
      ActionItem(id: _uuid.v4(), name: '跑代码', categoryId: defaultCategories[0].id, isPinned: true, sortOrder: 0),
      ActionItem(id: _uuid.v4(), name: '看论文', categoryId: defaultCategories[0].id, isPinned: true, sortOrder: 1),
      ActionItem(id: _uuid.v4(), name: '发呆', categoryId: defaultCategories[1].id, isPinned: true, sortOrder: 2),
      ActionItem(id: _uuid.v4(), name: '刷手机', categoryId: defaultCategories[3].id, isPinned: true, sortOrder: 3),
      ActionItem(id: _uuid.v4(), name: '吃饭', categoryId: defaultCategories[4].id, isPinned: true, sortOrder: 4),
      ActionItem(id: _uuid.v4(), name: '睡觉', categoryId: defaultCategories[1].id, isPinned: true, sortOrder: 5),
    ];

    for (final action in defaultActions) {
      await actions.put(action.id, action);
    }

    // 默认设置
    await settingsBox.put('default', Settings());
  }

  /// 获取设置
  Settings get settings => settingsBox.get('default') ?? Settings();

  /// 保存设置
  Future<void> saveSettings(Settings settings) async {
    await settingsBox.put('default', settings);
  }

  /// 获取所有分类
  List<Category> getAllCategories() => categories.values.where((c) => !c.isDeleted).toList();

  /// 根据ID获取分类
  Category? getCategoryById(String id) => categories.get(id);

  /// 添加/更新分类
  Future<void> saveCategory(Category category) async {
    category.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
    await categories.put(category.id, category);
  }

  /// 删除分类
  Future<void> deleteCategory(String id) async {
    final c = categories.get(id);
    if (c == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    c.isDeleted = true;
    c.deletedAtMillis = now;
    c.updatedAtMillis = now;
    await categories.put(id, c);
  }

  /// 获取所有行为
  List<ActionItem> getAllActions() => actions.values.where((a) => !a.isDeleted).toList();

  /// 获取置顶行为（用于快速输入页）
  List<ActionItem> getPinnedActions() {
    final pinned = actions.values.where((a) => a.isPinned && !a.isDeleted).toList();
    pinned.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return pinned;
  }

  /// 根据分类ID获取行为
  List<ActionItem> getActionsByCategory(String categoryId) {
    return actions.values.where((a) => a.categoryId == categoryId && !a.isDeleted).toList();
  }

  /// 添加/更新行为
  Future<void> saveAction(ActionItem action) async {
    action.updatedAtMillis = DateTime.now().millisecondsSinceEpoch;
    await actions.put(action.id, action);
  }

  /// 删除行为
  Future<void> deleteAction(String id) async {
    final a = actions.get(id);
    if (a == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    a.isDeleted = true;
    a.deletedAtMillis = now;
    a.updatedAtMillis = now;
    await actions.put(id, a);
  }

  /// 记录一条时间（快照存储），返回新记录的 id
  Future<String> addRecord(ActionItem action, {String? note, DateTime? at}) async {
    final category = getCategoryById(action.categoryId);
    final id = _uuid.v4();
    final record = Record(
      id: id,
      timestamp: at ?? DateTime.now(),
      actionName: action.name,
      categoryName: category?.name ?? '未知',
      colorHex: category?.colorHex ?? '#B5B5B5',
      note: note,
    );
    await records.put(record.id, record);
    
    // 每次记录后，重新排期提醒，相当于重置提醒 CD
    await NotificationService().reloadNotifications();
    
    return id;
  }

  /// 获取今日记录
  List<Record> getTodayRecords() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return records.values
        .where((r) => !r.isDeleted && r.timestamp.isAfter(today) && r.timestamp.isBefore(tomorrow))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // 倒序
  }

  /// 获取指定日期范围的记录
  List<Record> getRecordsByDateRange(DateTime start, DateTime end) {
    return records.values
        .where((r) => !r.isDeleted && r.timestamp.isAfter(start) && r.timestamp.isBefore(end))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// 删除记录
  Future<void> deleteRecord(String id) async {
    final r = records.get(id);
    if (r == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final updated = Record(
      id: r.id,
      timestamp: r.timestamp,
      actionName: r.actionName,
      categoryName: r.categoryName,
      colorHex: r.colorHex,
      note: r.note,
      updatedAtMillis: now,
      isDeleted: true,
      deletedAtMillis: now,
    );
    await records.put(id, updated);
  }

  /// 更新记录的备注字段（可设为 null 来删除备注）
  Future<void> updateRecordNote(String recordId, String? note) async {
    final old = records.get(recordId);
    if (old == null) return;
    final updated = Record(
      id: old.id,
      timestamp: old.timestamp,
      actionName: old.actionName,
      categoryName: old.categoryName,
      colorHex: old.colorHex,
      note: note,
      updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
      isDeleted: old.isDeleted,
      deletedAtMillis: old.deletedAtMillis,
    );
    await records.put(recordId, updated);
  }

  /// 返回指定周期（以 reference 为基点）内的汇总数据
  /// 返回结构示例：{ 'periodStart': DateTime, 'periodEnd': DateTime, 'total': int, 'byAction': `Map<String, int>`, 'byCategory': `Map<String, int>`, 'trend': `Map<DateTime, int>` }
  Future<Map<String, dynamic>> getSummary(Period period, DateTime reference) async {
    final range = _periodStartEnd(period, reference);
    final start = range['start'] as DateTime;
    final end = range['end'] as DateTime;

    final filtered = records.values.where((r) => !r.isDeleted && r.timestamp.isAfter(start) && r.timestamp.isBefore(end)).toList();

    final total = filtered.length;
    final byAction = <String, int>{};
    final byCategory = <String, int>{};
    for (final r in filtered) {
      byAction[r.actionName] = (byAction[r.actionName] ?? 0) + 1;
      byCategory[r.categoryName] = (byCategory[r.categoryName] ?? 0) + 1;
    }

    // trend：按日统计
    final trend = <DateTime, int>{};
    DateTime cursor = DateTime(start.year, start.month, start.day);
    while (cursor.isBefore(end)) {
      final next = cursor.add(const Duration(days: 1));
      final count = filtered.where((r) => r.timestamp.isAfter(cursor) && r.timestamp.isBefore(next)).length;
      trend[cursor] = count;
      cursor = next;
    }

    // also collect a map of categoryName -> colorHex for pie coloring
    final byCategoryColors = <String, String>{};
    for (final r in filtered) {
      if (r.categoryName.isNotEmpty && !byCategoryColors.containsKey(r.categoryName)) {
        byCategoryColors[r.categoryName] = r.colorHex;
      }
    }

    return {
      'periodStart': start,
      'periodEnd': end,
      'total': total,
      'byAction': byAction,
      'byCategory': byCategory,
      'byCategoryColors': byCategoryColors,
      'trend': trend,
    };
  }

  /// 计算周期起止时间
  Map<String, DateTime> _periodStartEnd(Period period, DateTime reference) {
    final r = DateTime(reference.year, reference.month, reference.day);
    if (period == Period.day) {
      final s = r;
      final e = s.add(const Duration(days: 1));
      return {'start': s, 'end': e};
    } else if (period == Period.week) {
      // 将周起点设为周一
      final start = r.subtract(Duration(days: r.weekday - 1));
      final s = DateTime(start.year, start.month, start.day);
      final e = s.add(const Duration(days: 7));
      return {'start': s, 'end': e};
    } else if (period == Period.month) {
      final s = DateTime(r.year, r.month, 1);
      final nextMonth = (r.month == 12) ? DateTime(r.year + 1, 1, 1) : DateTime(r.year, r.month + 1, 1);
      return {'start': s, 'end': nextMonth};
    } else {
      final s = DateTime(r.year, 1, 1);
      final e = DateTime(r.year + 1, 1, 1);
      return {'start': s, 'end': e};
    }
  }

  /// 生成新UUID
  String generateId() => _uuid.v4();

  /// 导出指定周期的汇总为 CSV，返回文件路径
  Future<String> exportSummaryCsv(Period period, DateTime reference) async {
    final summary = await getSummary(period, reference);
    final byAction = Map<String, int>.from(summary['byAction'] ?? {});
    final byCategory = Map<String, int>.from(summary['byCategory'] ?? {});
    final trend = Map<DateTime, int>.from(summary['trend'] ?? {});

    final buffer = StringBuffer();
    buffer.writeln('periodStart,${summary['periodStart']}');
    buffer.writeln('periodEnd,${summary['periodEnd']}');
    buffer.writeln('total,${summary['total']}');
    buffer.writeln('');
    buffer.writeln('By Action');
    buffer.writeln('action,count');
    for (final e in byAction.entries) {
      buffer.writeln('"${e.key}",${e.value}');
    }
    buffer.writeln('');
    buffer.writeln('By Category');
    buffer.writeln('category,count');
    for (final e in byCategory.entries) {
      buffer.writeln('"${e.key}",${e.value}');
    }
    buffer.writeln('');
    buffer.writeln('Trend (date,count)');
    buffer.writeln('date,count');
    final sortedTrend = trend.keys.toList()..sort();
    for (final d in sortedTrend) {
      final c = trend[d] ?? 0;
      buffer.writeln('${d.toIso8601String().split('T').first},$c');
    }
    final fileName = 'waud_summary_${period.name}_${reference.toIso8601String().split('T').first}.csv';
    return exportCsvText(fileName, buffer.toString());
  }
}
