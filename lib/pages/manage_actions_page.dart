import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show ReorderableListView, Material;
import '../models/models.dart';
import '../services/services.dart';

/// 行为管理页面
class ManageActionsPage extends StatefulWidget {
  const ManageActionsPage({super.key});

  @override
  State<ManageActionsPage> createState() => _ManageActionsPageState();
}

class _ManageActionsPageState extends State<ManageActionsPage> {
  final DatabaseService _db = DatabaseService();
  late List<ActionItem> _actions;
  late List<Category> _categories;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _actions = _db.getAllActions();
    _categories = _db.getAllCategories();
    _actions.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Widget build(BuildContext context) {
    final textColor = CupertinoColors.label.resolveFrom(context);
    final subTextColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: bgColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: bgColor.withValues(alpha: 0.8),
        border: null,
        middle: Text('管理行为', style: TextStyle(color: textColor, fontWeight: FontWeight.w300, fontSize: 20)),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add),
          onPressed: () => _showEditDialog(null),
        ),
      ),
      child: SafeArea(
        child: Material(
          color: const Color(0x00000000),
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _actions.length,
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final action = _actions[index];
              final category = _db.getCategoryById(action.categoryId);
              final color = category != null
                  ? Color(int.parse(category.colorHex.replaceFirst('#', '0xFF')))
                  : CupertinoColors.systemGrey;
  
              return Container(
                key: ValueKey(action.id),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(action.name, style: TextStyle(color: textColor, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(category?.name ?? '无分类', style: TextStyle(color: subTextColor, fontSize: 12)),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.all(6),
                          minimumSize: Size.zero,
                          child: Icon(CupertinoIcons.pencil, color: subTextColor, size: 20),
                          onPressed: () => _showEditDialog(action),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.all(6),
                          minimumSize: Size.zero,
                          child: Icon(CupertinoIcons.delete, color: subTextColor, size: 20),
                          onPressed: () => _confirmDelete(action),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    
    final item = _actions.removeAt(oldIndex);
    _actions.insert(newIndex, item);
    
    // 更新所有排序
    for (int i = 0; i < _actions.length; i++) {
      _actions[i].sortOrder = i;
      await _db.saveAction(_actions[i]);
    }
    
    setState(() {});
  }

  void _showEditDialog(ActionItem? action) {
    final isNew = action == null;
    final nameController = TextEditingController(text: action?.name ?? '');
    String? selectedCategoryId = action?.categoryId ?? _categories.firstOrNull?.id;
    final isDark = _db.settings.isDarkMode;
    final focusNode = FocusNode();
    var didRequestFocus = false;

    showCupertinoDialog(
      context: context,
      builder: (context) {
        if (!didRequestFocus) {
          didRequestFocus = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (focusNode.canRequestFocus) focusNode.requestFocus();
          });
        }
        return StatefulBuilder(
          builder: (context, setDialogState) => CupertinoAlertDialog(
          title: Text(isNew ? '新建行为' : '编辑行为', style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: nameController,
                placeholder: '行为名称',
                focusNode: focusNode,
                textInputAction: TextInputAction.done,
                clearButtonMode: OverlayVisibilityMode.editing,
                style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.black),
              ),
              const SizedBox(height: 12),
              Text('所属分类', style: TextStyle(color: isDark ? CupertinoColors.white.withAlpha(179) : CupertinoColors.inactiveGray, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((cat) {
                  final color = Color(int.parse(cat.colorHex.replaceFirst('#', '0xFF')));
                  final isSelected = selectedCategoryId == cat.id;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedCategoryId = cat.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? color : const Color(0x00000000),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color),
                        ),
                        child: Text(
                          cat.name,
                          style: TextStyle(
                            color: isSelected ? CupertinoColors.white : (isDark ? CupertinoColors.white.withAlpha(217) : CupertinoColors.inactiveGray),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                }).toList(),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.pop(context);
                focusNode.dispose();
              },
              child: Text('取消', style: TextStyle(color: isDark ? CupertinoColors.white.withAlpha(204) : CupertinoColors.inactiveGray)),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                if (nameController.text.trim().isEmpty || selectedCategoryId == null) return;

                final navigator = Navigator.of(context);

                if (isNew) {
                  await _db.saveAction(ActionItem(
                    id: _db.generateId(),
                    name: nameController.text.trim(),
                    categoryId: selectedCategoryId!,
                    isPinned: true, // 默认置顶以便在快速输入页显示
                    sortOrder: _actions.length,
                  ));
                } else {
                  action.name = nameController.text.trim();
                  action.categoryId = selectedCategoryId!;
                  await _db.saveAction(action);
                }

                if (!mounted) return;
                navigator.pop();
                focusNode.dispose();
                setState(_loadData);
              },
              child: Text('保存', style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.black)),
            ),
          ],
          ),
        );
      },
    );
  }

  void _confirmDelete(ActionItem action) {
    final isDark = _db.settings.isDarkMode;
    
    showCupertinoDialog(
      context: context,
        builder: (context) => CupertinoAlertDialog(
        title: Text('删除行为', style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.black)),
        content: Text('确定删除「${action.name}」吗？历史记录不会受影响。', style: TextStyle(color: isDark ? CupertinoColors.white.withAlpha(204) : CupertinoColors.inactiveGray)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: isDark ? CupertinoColors.white.withAlpha(204) : CupertinoColors.inactiveGray)),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _db.deleteAction(action.id);
              if (!mounted) return;
              navigator.pop();
              setState(_loadData);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
