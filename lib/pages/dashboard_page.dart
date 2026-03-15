import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import '../services/services.dart';

/// 数据看板页 - 正常打开App时显示
/// 
/// 包含：时间轴、占比环形图、间隔设置滑动条
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late double _intervalValue;
  // 记录哪些条目处于展开状态（用于轻触展开/收起）
  final Set<String> _expandedRecordIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _intervalValue = _db.settings.notificationIntervalMinutes.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = CupertinoColors.label.resolveFrom(context);
    final subTextColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: bgColor.withValues(alpha: 0.8),
        border: null,
        middle: Text('在干啥', style: TextStyle(fontWeight: FontWeight.w300, color: textColor, fontSize: 20)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _openSettings,
              child: Icon(CupertinoIcons.settings, color: subTextColor),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _goToQuickInput,
              child: Icon(CupertinoIcons.add_circled_solid, color: textColor),
            ),
          ],
        ),
      ),
      child: ValueListenableBuilder(
        valueListenable: _db.records.listenable(),
        builder: (context, _, __) {
          final todayRecords = _db.getTodayRecords();
          return CustomScrollView(
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () async {
                  setState(_loadData);
                },
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.of(context).padding.top + 44.0),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPieChart(todayRecords, isDark, textColor, subTextColor),
                      const SizedBox(height: 30),
                      _buildTimeline(todayRecords, isDark, textColor, subTextColor),
                      const SizedBox(height: 30),
                      _buildIntervalSlider(isDark, textColor, subTextColor),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 构建占比环形图
  Widget _buildPieChart(List<Record> todayRecords, bool isDark, Color textColor, Color subTextColor) {
    final categoryStats = _calculateCategoryStats(todayRecords);
    
    if (categoryStats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            '今天还没有记录',
            style: TextStyle(color: subTextColor, fontSize: 16),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今日概览',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            // 环形图
            SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(
                painter: PieChartPainter(categoryStats),
              ),
            ),
            const SizedBox(width: 30),
            // 图例
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: categoryStats.map((stat) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: stat.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          stat.name,
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                        const Spacer(),
                        Text(
                          '${stat.count}次',
                          style: TextStyle(color: subTextColor, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.of(context).pushNamed('/summary'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(CupertinoIcons.chart_pie, size: 18),
                SizedBox(width: 6),
                Text('查看 周/月/年 汇总'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 计算各分类统计
  List<CategoryStat> _calculateCategoryStats(List<Record> todayRecords) {
    final Map<String, CategoryStat> stats = {};
    
    for (final record in todayRecords) {
      if (stats.containsKey(record.categoryName)) {
        stats[record.categoryName]!.count++;
      } else {
        stats[record.categoryName] = CategoryStat(
          name: record.categoryName,
          count: 1,
          color: Color(int.parse(record.colorHex.replaceFirst('#', '0xFF'))),
        );
      }
    }
    
    final list = stats.values.toList();
    list.sort((a, b) => b.count.compareTo(a.count));
    return list;
  }

  /// 构建时间轴
  Widget _buildTimeline(List<Record> todayRecords, bool isDark, Color textColor, Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '时间轴',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 16),
        if (todayRecords.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              '暂无记录',
              style: TextStyle(color: subTextColor),
            ),
          )
        else
          ...(todayRecords.take(20).map((record) {
            final time = '${record.timestamp.hour.toString().padLeft(2, '0')}:${record.timestamp.minute.toString().padLeft(2, '0')}';
            final color = Color(int.parse(record.colorHex.replaceFirst('#', '0xFF')));
            
            // 组合显示文本：大类 · 动作 · 备注（用于渲染并在对话框中展示）
            final List<String> displayParts = [record.categoryName, record.actionName];
            if (record.note != null && record.note!.isNotEmpty) displayParts.add(record.note!);
            final displayText = displayParts.join(' · ');

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // 时间点
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 时间
                  Text(
                    time,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 单行：分类 · 动作 · 备注（超出缩略），点击查看全文/编辑
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        setState(() {
                          if (_expandedRecordIds.contains(record.id)) {
                            _expandedRecordIds.remove(record.id);
                          } else {
                            _expandedRecordIds.add(record.id);
                          }
                        });
                      },
                      child: AnimatedSize(
                        alignment: Alignment.topLeft,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: _expandedRecordIds.contains(record.id)
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(displayText, style: TextStyle(color: textColor, fontSize: 15)),
                                ],
                              )
                            : Text(displayText, style: TextStyle(color: textColor, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 编辑图标，便于快速进入详情编辑
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                    child: Icon(CupertinoIcons.pencil_outline, size: 18, color: subTextColor),
                    onPressed: () async {
                      await Navigator.of(context).pushNamed('/record_detail', arguments: record.id);
                      if (mounted) setState(_loadData);
                    },
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(32, 32),
                    child: Icon(CupertinoIcons.trash, size: 18, color: subTextColor),
                    onPressed: () => _confirmDeleteRecord(record.id),
                  ),
                ],
              ),
            );
          })),
      ],
    );
  }

  void _confirmDeleteRecord(String recordId) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条记录吗？'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () async {
              await _db.deleteRecord(recordId);
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  /// 构建间隔设置滑动条
  Widget _buildIntervalSlider(bool isDark, Color textColor, Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '提醒间隔',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
            ),
            const Spacer(),
            Text(
              '${_intervalValue.round()} 分钟',
              style: TextStyle(color: subTextColor, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        CupertinoSlider(
          value: _intervalValue,
          min: 15,
          max: 120,
          divisions: 7,
          onChanged: (value) {
            setState(() {
              _intervalValue = value;
            });
          },
          onChangeEnd: (value) async {
            final settings = _db.settings;
            settings.notificationIntervalMinutes = value.round();
            await _db.saveSettings(settings);
            await NotificationService().reloadNotifications();
          },
        ),
      ],
    );
  }

  /// 打开设置页
  Future<void> _openSettings() async {
    await Navigator.of(context).pushNamed('/settings');
    if (mounted) setState(_loadData);
  }

  /// 跳转到快速输入页
  Future<void> _goToQuickInput() async {
    await Navigator.of(context).pushNamed('/quick_input', arguments: {'fromNotification': false});
    if (mounted) setState(_loadData);
  }
}

/// 分类统计数据
class CategoryStat {
  final String name;
  int count;
  final Color color;

  CategoryStat({required this.name, required this.count, required this.color});
}

/// 环形图绘制器
class PieChartPainter extends CustomPainter {
  final List<CategoryStat> stats;
  
  PieChartPainter(this.stats);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final strokeWidth = 20.0;
    
    final total = stats.fold<int>(0, (sum, stat) => sum + stat.count);
    if (total == 0) return;
    
    double startAngle = -pi / 2; // 从顶部开始
    
    for (final stat in stats) {
      final sweepAngle = (stat.count / total) * 2 * pi;
      
      final paint = Paint()
        ..color = stat.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
