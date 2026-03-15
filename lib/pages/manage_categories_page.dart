import 'package:flutter/cupertino.dart';
import '../models/models.dart';
import '../services/services.dart';

/// 分类管理页面
class ManageCategoriesPage extends StatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  final DatabaseService _db = DatabaseService();
  late List<Category> _categories;

  // 莫兰迪色系颜色选项
  static const List<String> _colorOptions = [
    '#8B9DC3', '#A8D8B9', '#F4A261', '#E9C46A', 
    '#CDB4DB', '#B5B5B5', '#E76F51', '#2A9D8F',
    '#264653', '#E9967A', '#DDA0DD', '#87CEEB',
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    _categories = _db.getAllCategories();
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
        middle: Text('管理分类', style: TextStyle(color: textColor, fontWeight: FontWeight.w300, fontSize: 20)),
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
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final color = Color(int.parse(category.colorHex.replaceFirst('#', '0xFF')));

            return Container(
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
                    child: Text(category.name, style: TextStyle(color: textColor, fontSize: 16)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.all(6),
                        minimumSize: Size.zero,
                        child: Icon(CupertinoIcons.pencil, color: subTextColor, size: 20),
                        onPressed: () => _showEditDialog(category),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(6),
                        minimumSize: Size.zero,
                        child: Icon(CupertinoIcons.delete, color: subTextColor, size: 20),
                        onPressed: () => _confirmDelete(category),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEditDialog(Category? category) {
    final isNew = category == null;
    final nameController = TextEditingController(text: category?.name ?? '');
    String selectedColor = category?.colorHex ?? _colorOptions[0];
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
          title: Text(isNew ? '新建分类' : '编辑分类', style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: nameController,
                placeholder: '分类名称',
                focusNode: focusNode,
                textInputAction: TextInputAction.done,
                clearButtonMode: OverlayVisibilityMode.editing,
                style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.black),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colorOptions.map((colorHex) {
                  final color = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                  final isSelected = selectedColor == colorHex;
                  return GestureDetector(
                    onTap: () => setDialogState(() => selectedColor = colorHex),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: isDark ? CupertinoColors.white : CupertinoColors.black, width: 2) : null,
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
              child: Text('取消', style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.inactiveGray)),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                final navigator = Navigator.of(context);

                if (isNew) {
                  await _db.saveCategory(Category(
                    id: _db.generateId(),
                    name: nameController.text.trim(),
                    colorHex: selectedColor,
                  ));
                } else {
                  category.name = nameController.text.trim();
                  category.colorHex = selectedColor;
                  await _db.saveCategory(category);
                }

                if (!mounted) return;
                navigator.pop();
                focusNode.dispose();
                setState(_loadCategories);
              },
              child: Text('保存', style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.black)),
            ),
          ],
          ),
        );
      },
    );
  }

  void _confirmDelete(Category category) {
    final isDark = _db.settings.isDarkMode;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('删除分类', style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.black)),
        content: Text('确定删除「${category.name}」吗？关联的行为不会被删除。', style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.inactiveGray)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text('取消', style: TextStyle(color: isDark ? CupertinoColors.white : CupertinoColors.inactiveGray)),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _db.deleteCategory(category.id);
              if (!mounted) return;
              navigator.pop();
              setState(_loadCategories);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
