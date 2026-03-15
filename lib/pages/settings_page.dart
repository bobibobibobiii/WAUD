import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/services.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final DatabaseService _db = DatabaseService();
  late Settings _settings;

  @override
  void initState() {
    super.initState();
    _settings = _db.settings;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = CupertinoColors.label.resolveFrom(context);
    final subTextColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGroupedBackground.withValues(alpha: 0.8),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back),
        ),
        middle: const Text('设置'),
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!kIsWeb) ...[
              _buildSectionTitle('通知设置', textColor),
              _buildSwitchTile(
                '启用提醒',
                '定时提醒你记录当前状态',
                _settings.notificationsEnabled,
                (value) async {
                  setState(() => _settings.notificationsEnabled = value);
                  await _saveSettings();
                  await NotificationService().reloadNotifications();
                },
                _settings.isDarkMode,
                textColor,
                subTextColor,
              ),
              const SizedBox(height: 30),
              _buildSectionTitle('免打扰时间', textColor),
              _buildTimeTile(
                '开始时间',
                _settings.sleepStartHour,
                _settings.sleepStartMinute,
                (h, m) async {
                  setState(() {
                    _settings.sleepStartHour = h;
                    _settings.sleepStartMinute = m;
                  });
                  await _saveSettings();
                  await NotificationService().reloadNotifications();
                },
                _settings.isDarkMode,
                textColor,
                subTextColor,
              ),
              _buildTimeTile(
                '结束时间',
                _settings.sleepEndHour,
                _settings.sleepEndMinute,
                (h, m) async {
                  setState(() {
                    _settings.sleepEndHour = h;
                    _settings.sleepEndMinute = m;
                  });
                  await _saveSettings();
                  await NotificationService().reloadNotifications();
                },
                _settings.isDarkMode,
                textColor,
                subTextColor,
              ),
              const SizedBox(height: 30),
            ] else ...[
              _buildSectionTitle('通知设置', textColor),
              Text('网页版不支持系统级定时通知（打包为手机 App 后可用原生通知能力补齐）。', style: TextStyle(color: subTextColor, fontSize: 13)),
              const SizedBox(height: 30),
            ],

            // 外观设置
            _buildSectionTitle('外观', textColor),
            _buildSwitchTile(
              '深色模式',
              '使用深色背景',
              _settings.isDarkMode,
              (value) async {
                setState(() => _settings.isDarkMode = value);
                await _saveSettings();
              },
              _settings.isDarkMode,
              textColor,
              subTextColor,
            ),

            const SizedBox(height: 30),

            _buildSectionTitle('账户与同步', textColor),
            _buildActionTile(
              '登录与同步',
              '游客本地使用，登录后多端同步',
              CupertinoIcons.person_crop_circle,
              () => Navigator.pushNamed(context, '/account'),
              _settings.isDarkMode,
              textColor,
              subTextColor,
            ),

            const SizedBox(height: 30),

            // 数据管理
            _buildSectionTitle('数据管理', textColor),
            _buildActionTile(
              '管理分类',
              '添加或编辑行为分类',
              CupertinoIcons.square_list,
              () => Navigator.pushNamed(context, '/manage_categories'),
              _settings.isDarkMode,
              textColor,
              subTextColor,
            ),
            _buildActionTile(
              '管理行为',
              '添加或编辑快捷行为',
              CupertinoIcons.hand_point_right,
              () => Navigator.pushNamed(context, '/manage_actions'),
              _settings.isDarkMode,
              textColor,
              subTextColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textColor)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 13)),
              ],
            ),
          ),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildTimeTile(
    String title,
    int hour,
    int minute,
    Function(int, int) onChanged,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    final timeStr = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () async {
        final picked = await showCupertinoModalPopup<DateTime?>(
          context: context,
          builder: (context) {
            DateTime temp = DateTime(0, 0, 0, hour, minute);
            final bg = CupertinoColors.systemBackground.resolveFrom(context);
            
            return Container(
              height: 300,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    // 顶部按钮栏
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Text('取消'),
                            onPressed: () => Navigator.of(context).pop(null),
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Text('完成'),
                            onPressed: () => Navigator.of(context).pop(temp),
                          ),
                        ],
                      ),
                    ),
                    // 选择器
                    Expanded(
                      child: CupertinoTheme(
                        data: CupertinoThemeData(
                          brightness: isDark ? Brightness.dark : Brightness.light,
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.time,
                          initialDateTime: temp,
                          use24hFormat: true,
                          onDateTimeChanged: (dt) => temp = dt,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        if (picked != null) onChanged(picked.hour, picked.minute);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(title, style: TextStyle(color: textColor))),
            Text(timeStr, style: TextStyle(color: subTextColor, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
    Color textColor,
    Color subTextColor,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: subTextColor),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: textColor)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 13))])),
            const SizedBox(width: 12),
            const Icon(CupertinoIcons.chevron_forward, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    await _db.saveSettings(_settings);
  }
}
