import 'package:flutter/cupertino.dart';
import '../services/services.dart';
import '../models/models.dart';

/// 记录详情页 - 显示并允许编辑备注
class RecordDetailPage extends StatefulWidget {
  const RecordDetailPage({super.key});

  @override
  State<RecordDetailPage> createState() => _RecordDetailPageState();
}

class _RecordDetailPageState extends State<RecordDetailPage> {
  final DatabaseService _db = DatabaseService();
  Record? _record;
  final TextEditingController ctrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 通过路由参数传入 recordId
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String) {
      final r = _db.records.get(args);
      setState(() {
        _record = r;
        ctrl.text = r?.note ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final cardColor = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);

    if (_record == null) {
      return CupertinoPageScaffold(
        backgroundColor: backgroundColor,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: backgroundColor.withValues(alpha: 0.8),
          border: null,
          middle: const Text('记录详情'),
        ),
        child: const SafeArea(child: Center(child: Text('未找到记录'))),
      );
    }

    final dateStr = '${_record!.timestamp.year}年${_record!.timestamp.month}月${_record!.timestamp.day}日 ${_record!.timestamp.hour.toString().padLeft(2, '0')}:${_record!.timestamp.minute.toString().padLeft(2, '0')}';

    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: backgroundColor.withValues(alpha: 0.8),
        border: null,
        middle: const Text('编辑详情', style: TextStyle(fontWeight: FontWeight.w600)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('完成', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 顶部信息卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _parseColor(_record!.colorHex),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _record!.categoryName,
                          style: TextStyle(
                            color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _record!.actionName,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: CupertinoColors.secondaryLabel.resolveFrom(context),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // 备注输入区
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '备注',
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CupertinoTextField(
                  controller: ctrl,
                  maxLines: 8,
                  minLines: 5,
                  autofocus: false,
                  clearButtonMode: OverlayVisibilityMode.editing,
                  placeholder: '在这里添加详细备注...',
                  placeholderStyle: TextStyle(
                    color: CupertinoColors.placeholderText.resolveFrom(context),
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0x00000000),
                  ),
                  padding: const EdgeInsets.all(16),
                  style: TextStyle(
                    color: CupertinoColors.label.resolveFrom(context),
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 删除按钮
              SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onPressed: () => _confirmDelete(context),
                  child: const Text(
                    '删除这条记录',
                    style: TextStyle(
                      color: CupertinoColors.destructiveRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  void _confirmDelete(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条记录吗？此操作不可撤销。'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              await _db.deleteRecord(_record!.id);
              if (!context.mounted) return;
              Navigator.pop(context); // 关弹窗
              Navigator.pop(context); // 关详情页
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_record == null) return;
  await _db.updateRecordNote(_record!.id, ctrl.text.trim().isEmpty ? null : ctrl.text.trim());
    if (mounted) Navigator.of(context).pop();
  }
}
