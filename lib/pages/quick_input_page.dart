import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/services.dart';

/// 极简输入页 - 通知唤醒后显示
/// 
/// 设计理念：
/// - 全屏铺排4-6个巨大的置顶行为按钮
/// - 一键点击 -> 震动反馈 -> 自动保存 -> 提示退出
class QuickInputPage extends StatefulWidget {
  const QuickInputPage({super.key});

  @override
  State<QuickInputPage> createState() => _QuickInputPageState();
}

class _QuickInputPageState extends State<QuickInputPage> {
  final DatabaseService _db = DatabaseService();
  bool _recorded = false;
  String _recordedAction = '';
  String? _lastRecordId;
  bool _fromNotification = false;
  bool _argsLoaded = false;
  DateTime _selectedTime = DateTime.now();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    _argsLoaded = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final fromNoti = args['fromNotification'];
      if (fromNoti is bool) _fromNotification = fromNoti;
      final millis = args['initialTimeMillis'];
      if (millis is int) _selectedTime = DateTime.fromMillisecondsSinceEpoch(millis);
      if (millis is num) _selectedTime = DateTime.fromMillisecondsSinceEpoch(millis.toInt());
      return;
    }
    _fromNotification = false;
    _selectedTime = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    // 已记录状态：显示成功提示
    if (_recorded) {
      return _buildSuccessView();
    }

    // 输入状态：显示大按钮
    return _buildInputView();
  }

  /// 输入界面
  Widget _buildInputView() {
    final pinnedActions = _db.getPinnedActions();
    final subTextColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.withValues(alpha: 0.8),
        border: null,
        middle: const Text('在干啥'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭', style: TextStyle(color: CupertinoColors.activeBlue)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 顶部提示
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 30),
                child: Text(
                  '现在在干啥？',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    color: subTextColor,
                  ),
                ),
              ),
              if (!_fromNotification) ...[
                _buildTimeRow(subTextColor),
                const SizedBox(height: 16),
              ],
              // 大按钮网格
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: pinnedActions.length,
                  itemBuilder: (context, index) {
                    return _buildActionButton(pinnedActions[index]);
                  },
                ),
              ),
              // 底部：跳过按钮
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _goToDashboard,
                child: Text('查看记录', style: TextStyle(color: subTextColor, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建单个行为按钮
  Widget _buildActionButton(ActionItem action) {
    final category = _db.getCategoryById(action.categoryId);
    final colorHex = category?.colorHex ?? '#B5B5B5';
  final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

    return CupertinoButton(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      color: color.withAlpha((255 * 0.85).round()),
      onPressed: () => _onActionTap(action),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              action.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: CupertinoColors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              category?.name ?? '',
              style: TextStyle(
                fontSize: 14,
                color: const Color.fromRGBO(255, 255, 255, 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 点击行为按钮
  Future<void> _onActionTap(ActionItem action) async {
    // 1. 触发震动反馈
    HapticFeedback.mediumImpact();

    // 2. 快速记录（备注非必选，后续可在成功页添加）
    final id = await _db.addRecord(action, at: _selectedTime);

    // 3. 重新加载通知（记录后重置弹夹）
    NotificationService().reloadNotifications();

    // 4. 显示成功状态并记下新记录 id
    setState(() {
      _recorded = true;
      _recordedAction = action.name;
      _lastRecordId = id;
    });

    // 5. 0.5秒后对界面做微调整（保留展现）
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() {});
  }

  Widget _buildTimeRow(Color subTextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text('记录时间', style: TextStyle(color: subTextColor, fontSize: 13)),
          const Spacer(),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _pickTime,
            child: Text(
              _formatTime(_selectedTime),
              style: const TextStyle(color: CupertinoColors.activeBlue, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  void _pickTime() {
    final initial = _selectedTime;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) {
        return Container(
          height: 320,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  border: Border(
                    bottom: BorderSide(color: CupertinoColors.separator.resolveFrom(context)),
                  ),
                ),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: initial,
                  use24hFormat: true,
                  onDateTimeChanged: (dt) {
                    setState(() {
                      _selectedTime = dt;
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 成功界面
  Widget _buildSuccessView() {
    final textColor = CupertinoColors.label.resolveFrom(context);
    final subTextColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final tertiaryTextColor = CupertinoColors.tertiaryLabel.resolveFrom(context);
    final TextEditingController noteController = TextEditingController();
    // preload existing note if any
    if (_lastRecordId != null) {
      final r = _db.records.get(_lastRecordId);
      noteController.text = r?.note ?? '';
    }
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemBackground.withValues(alpha: 0.8),
        border: null,
        middle: const Text('已记录'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('关闭', style: TextStyle(color: CupertinoColors.activeBlue)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      size: 96,
                      color: subTextColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '已记录',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _recordedAction,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        color: subTextColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 48),
                    // 退出提示
                    Text(
                      '请上划退回桌面',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: tertiaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 或者查看记录
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: [
                          // 备注输入（简洁）
                          CupertinoTextField(
                            controller: noteController,
                            maxLines: 3,
                            autofocus: true,
                            clearButtonMode: OverlayVisibilityMode.editing,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            placeholder: '添加备注（可选）',
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  onPressed: _goToDashboard,
                                  color: CupertinoColors.systemGrey.withAlpha((255 * 0.1).round()),
                                  child: Text('查看今日记录', style: TextStyle(color: CupertinoColors.systemGrey)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CupertinoButton.filled(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                onPressed: () async {
                                  if (_lastRecordId == null) return;
                                  final note = noteController.text.trim().isEmpty ? null : noteController.text.trim();
                                  await _db.updateRecordNote(_lastRecordId!, note);
                                  if (!context.mounted) return;
                                  // 简洁提示：使用 CupertinoDialog
                                  showCupertinoDialog<void>(
                                    context: context,
                                    builder: (context) => CupertinoAlertDialog(
                                      content: const Text('备注已保存'),
                                      actions: [
                                        CupertinoDialogAction(
                                          child: const Text('确定'),
                                          onPressed: () => Navigator.of(context).pop(),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('保存备注'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              color: CupertinoColors.systemGrey.withAlpha((255 * 0.1).round()),
                              onPressed: _confirmDeleteLastRecord,
                              child: const Text('删除本次记录', style: TextStyle(color: CupertinoColors.destructiveRed)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 跳转到数据看板
  void _goToDashboard() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _confirmDeleteLastRecord() {
    final id = _lastRecordId;
    if (id == null) return;
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除刚才这条记录吗？'),
        actions: [
          CupertinoDialogAction(
            child: const Text('取消'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('删除'),
            onPressed: () async {
              await _db.deleteRecord(id);
              if (!context.mounted) return;
              Navigator.of(context).pop();
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
