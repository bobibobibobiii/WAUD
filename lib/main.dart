/*
 * @Author: twx 3086080053@qq.com
 * @Date: 2026-03-12 18:21:30
 * @LastEditors: twx 3086080053@qq.com
 * @LastEditTime: 2026-03-13 18:50:35
 * @FilePath: \WAUD\lib\main.dart
 * @Description: 
 * 
 * Copyright (c) 2026 by ${git_name_email}, All Rights Reserved. 
 */
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/services.dart';
import 'pages/pages.dart';
import 'models/models.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化数据库
  await DatabaseService().init();
  
  await CloudAuthService().init();
  
  var launchedFromNotification = false;
  if (!kIsWeb) {
    await NotificationService().init();
    await NotificationService().requestPermission();
    final payload = await NotificationService().getInitialNotificationPayload();
    launchedFromNotification = payload == 'quick_record';
    await NotificationService().reloadNotifications();
  }
  
  runApp(WaudApp(launchedFromNotification: launchedFromNotification));
}

class WaudApp extends StatefulWidget {
  final bool launchedFromNotification;
  
  const WaudApp({super.key, required this.launchedFromNotification});

  @override
  State<WaudApp> createState() => _WaudAppState();
}

class _WaudAppState extends State<WaudApp> {
  late bool _showQuickInput;
  bool _handledInitialQuickInput = false;
  
  @override
  void initState() {
    super.initState();
    _showQuickInput = widget.launchedFromNotification;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_showQuickInput && !_handledInitialQuickInput) {
        _handledInitialQuickInput = true;
        _openQuickInput(fromNotification: true);
      }
    });
    
    // 设置通知点击回调（App运行时点击通知）
    NotificationService.onNotificationTap = (payload) {
      if (payload == 'quick_record' && mounted) {
        _openQuickInput(fromNotification: true);
      }
    };
  }

  void _openQuickInput({required bool fromNotification}) {
    final args = {
      'fromNotification': fromNotification,
      'initialTimeMillis': DateTime.now().millisecondsSinceEpoch,
    };
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    Navigator.of(context).pushNamed('/quick_input', arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    // 监听 Hive 中设置的变化，切换深色/浅色模式时立即重建 App
    return ValueListenableBuilder(
      valueListenable: DatabaseService().settingsBox.listenable(),
      builder: (context, box, _) {
        final settings = DatabaseService().settingsBox.get('default') ?? Settings();
        final isDark = settings.isDarkMode;

        return CupertinoApp(
          title: '在干啥',
          debugShowCheckedModeBanner: false,
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          theme: CupertinoThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            scaffoldBackgroundColor: CupertinoColors.systemBackground,
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const DashboardPage(),
            '/quick_input': (context) => const QuickInputPage(),
            '/record_detail': (context) => const RecordDetailPage(),
            '/summary': (context) => const SummaryPage(),
            '/settings': (context) => const SettingsPage(),
            '/manage_categories': (context) => const ManageCategoriesPage(),
            '/manage_actions': (context) => const ManageActionsPage(),
            '/account': (context) => const AccountPage(),
          },
        );
      },
    );
  }
}
