import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/services.dart';

/// iOS 风格的汇总页 (Refactored)
/// 
/// 遵循极简、淡雅、卡片式的 iOS 原生风格。
class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  final DatabaseService _db = DatabaseService();
  Period _period = Period.month;
  DateTime _reference = DateTime.now();
  Map<String, dynamic>? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _db.getSummary(_period, _reference);
      if (mounted) setState(() => _summary = s);
    } catch (e) {
      if (mounted) setState(() => _summary = {});
    }
  }

  void _onPeriodChanged(Period p) {
    setState(() {
      _period = p;
      _summary = null;
    });
    _load();
  }

  Future<void> _pickReference() async {
    final picked = await showCupertinoModalPopup<DateTime?>(
      context: context,
      builder: (context) {
        DateTime temp = _reference;
        final bg = CupertinoColors.systemBackground.resolveFrom(context);
        
        return Container(
          height: 320,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  CupertinoButton(padding: EdgeInsets.zero, child: const Text('取消'), onPressed: () => Navigator.of(context).pop(null)),
                  CupertinoButton(padding: EdgeInsets.zero, child: const Text('完成'), onPressed: () => Navigator.of(context).pop(temp)),
                ]),
              ),
              Expanded(
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: CupertinoTheme.of(context).brightness,
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: _reference,
                    onDateTimeChanged: (d) => temp = d,
                  ),
                ),
              ),
            ]),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _reference = picked;
        _summary = null;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final cardColor = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: backgroundColor.withValues(alpha: 0.8),
        border: null,
        middle: const Text('汇总', style: TextStyle(fontWeight: FontWeight.w600)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _pickReference,
          child: const Icon(CupertinoIcons.calendar, size: 22),
        ),
      ),
      child: SafeArea(
        child: _summary == null
            ? const Center(child: CupertinoActivityIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. 顶部切换控件 (Top Navigation)
                    _PeriodSegmented(period: _period, onChanged: _onPeriodChanged),
                    const SizedBox(height: 20),

                    // 3. 核心数据卡片 (Key Metrics Cards)
                    _KeyMetrics(summary: _summary!, cardColor: cardColor),
                    const SizedBox(height: 24),

                    // 4. 极简优雅的图表 (Charts)
                    _ChartSection(period: _period, summary: _summary!, cardColor: cardColor),
                    const SizedBox(height: 24),

                    // 5. 详情列表 (Detailed List)
                    _DetailedListSection(summary: _summary!, cardColor: cardColor),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }
}

/// 2. 顶部切换控件 (Top Navigation)
class _PeriodSegmented extends StatelessWidget {
  final Period period;
  final ValueChanged<Period> onChanged;

  const _PeriodSegmented({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<Period>(
        groupValue: period,
        children: const {
          Period.day: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('日')),
          Period.week: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('周')),
          Period.month: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('月')),
          Period.year: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('年')),
        },
        onValueChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// 3. 核心数据卡片 (Key Metrics Cards)
class _KeyMetrics extends StatelessWidget {
  final Map<String, dynamic> summary;
  final Color cardColor;

  const _KeyMetrics({required this.summary, required this.cardColor});

  @override
  Widget build(BuildContext context) {
    final total = summary['total'] as int? ?? 0;
    final byAction = Map<String, int>.from(summary['byAction'] ?? {});
    final topAction = byAction.isEmpty ? '-' : byAction.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    return Row(
      children: [
        Expanded(child: _MetricCard(title: '总次数', value: '$total', label: '次', cardColor: cardColor)),
        const SizedBox(width: 12),
        Expanded(child: _MetricCard(title: '最常进行', value: topAction, label: '', cardColor: cardColor, isSmallValue: topAction.length > 4)),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String label;
  final Color cardColor;
  final bool isSmallValue;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.label,
    required this.cardColor,
    this.isSmallValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    color: CupertinoColors.activeBlue,
                    fontSize: isSmallValue ? 24 : 32,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (label.isNotEmpty)
                Text(' $label', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 4. 极简优雅的图表 (Charts)
class _ChartSection extends StatefulWidget {
  final Period period;
  final Map<String, dynamic> summary;
  final Color cardColor;

  const _ChartSection({required this.period, required this.summary, required this.cardColor});

  @override
  State<_ChartSection> createState() => _ChartSectionState();
}

class _ChartSectionState extends State<_ChartSection> {
  bool _showCategory = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showCategory ? '分类占比' : '动作占比',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => setState(() => _showCategory = !_showCategory),
                child: Text(
                  _showCategory ? '看动作' : '看分类',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: Row(
              children: [
                // 分类饼图
                Expanded(
                  flex: _showCategory ? 3 : 1,
                  child: GestureDetector(
                    onTap: () => setState(() => _showCategory = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      child: _CategoryPieChart(
                        summary: widget.summary,
                        isExpanded: _showCategory,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // 动作饼图
                Expanded(
                  flex: _showCategory ? 1 : 3,
                  child: GestureDetector(
                    onTap: () => setState(() => _showCategory = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      child: _ActionPieChart(
                        summary: widget.summary,
                        isExpanded: !_showCategory,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final Map<String, dynamic> summary;
  final bool isExpanded;

  const _CategoryPieChart({required this.summary, required this.isExpanded});

  @override
  Widget build(BuildContext context) {
    final byCategory = Map<String, int>.from(summary['byCategory'] ?? {});
    final byCategoryColors = Map<String, String>.from(summary['byCategoryColors'] ?? {});
    
    if (byCategory.isEmpty) {
      return const Center(child: Text('无', style: TextStyle(color: CupertinoColors.systemGrey)));
    }

    final total = byCategory.values.fold<int>(0, (sum, val) => sum + val);

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: isExpanded ? 40 : 20,
        sections: byCategory.entries.map((entry) {
          final colorHex = byCategoryColors[entry.key] ?? '#B5B5B5';
          final originalColor = _parseColor(colorHex);
          // 转换为饱和度较低的莫兰迪色系
          final color = _toMorandi(originalColor);
          final percentage = (entry.value / total * 100).toStringAsFixed(0);
          
          return PieChartSectionData(
            color: color,
            value: entry.value.toDouble(),
            title: (isExpanded && entry.value / total > 0.08) ? '$percentage%' : '',
            radius: isExpanded ? 50 : 25,
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.white,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActionPieChart extends StatelessWidget {
  final Map<String, dynamic> summary;
  final bool isExpanded;

  const _ActionPieChart({required this.summary, required this.isExpanded});

  @override
  Widget build(BuildContext context) {
    final byAction = Map<String, int>.from(summary['byAction'] ?? {});
    
    if (byAction.isEmpty) {
      return const Center(child: Text('无', style: TextStyle(color: CupertinoColors.systemGrey)));
    }

    final total = byAction.values.fold<int>(0, (sum, val) => sum + val);
    final sortedActions = byAction.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    // 生成一些原生感的动作颜色
    final List<Color> actionColors = [
      CupertinoColors.systemBlue,
      CupertinoColors.systemIndigo,
      CupertinoColors.systemPurple,
      CupertinoColors.systemTeal,
      CupertinoColors.systemGreen,
      CupertinoColors.systemOrange,
      CupertinoColors.systemPink,
    ];

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: isExpanded ? 40 : 20,
        sections: List.generate(sortedActions.length, (i) {
          final entry = sortedActions[i];
          final originalColor = actionColors[i % actionColors.length];
          // 统一使用莫兰迪色系，降低饱和度
          final color = _toMorandi(originalColor);
          final percentage = (entry.value / total * 100).toStringAsFixed(0);
          
          return PieChartSectionData(
            color: color.withValues(alpha: isExpanded ? 1.0 : 0.6),
            value: entry.value.toDouble(),
            title: (isExpanded && entry.value / total > 0.08) ? '$percentage%' : '',
            radius: isExpanded ? 50 : 25,
            titleStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: CupertinoColors.white,
            ),
          );
        }),
      ),
    );
  }
}

Color _toMorandi(Color color) {
  final hsl = HSLColor.fromColor(color);
  // 莫兰迪色系的特点是低饱和度（通常在 0.15 - 0.35 之间）
  return hsl.withSaturation((hsl.saturation * 0.4).clamp(0.15, 0.35)).toColor();
}

Color _parseColor(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

/// 5. 详情列表 (Detailed List)
class _DetailedListSection extends StatelessWidget {
  final Map<String, dynamic> summary;
  final Color cardColor;

  const _DetailedListSection({required this.summary, required this.cardColor});

  @override
  Widget build(BuildContext context) {
    final byAction = Map<String, int>.from(summary['byAction'] ?? {});
    final byCategory = Map<String, int>.from(summary['byCategory'] ?? {});

    return Column(
      children: [
        _GroupedList(title: '按动作统计', data: byAction, cardColor: cardColor),
        const SizedBox(height: 24),
        _GroupedList(title: '按分类统计', data: byCategory, cardColor: cardColor),
      ],
    );
  }
}

class _GroupedList extends StatelessWidget {
  final String title;
  final Map<String, int> data;
  final Color cardColor;

  const _GroupedList({required this.title, required this.data, required this.cardColor});

  @override
  Widget build(BuildContext context) {
    final sortedEntries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 14)),
        ),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: List.generate(sortedEntries.length, (index) {
              final entry = sortedEntries[index];
              final isLast = index == sortedEntries.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key, style: const TextStyle(fontSize: 16)),
                        Text('${entry.value} 次', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 16)),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Container(height: 0.5, color: CupertinoColors.systemGrey5),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
