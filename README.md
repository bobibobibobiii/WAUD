# 在干啥 (WAUD)

一个极简主义的时间记录 App，专注于被动式记录、懒人友好的设计理念。

## 🎯 核心理念

- **极简主义**：纯白/深黑配色，无多余装饰
- **被动式记录**：通知提醒你在做什么，而非主动打卡
- **懒人友好**：操作步骤 ≤ 2 步，一键记录
- **纯本地**：无网络请求，数据安全存储在本地

## 🔧 技术栈

- **框架**: Flutter (纯 StatefulWidget，无重型状态管理)
- **数据库**: Hive + hive_flutter (极速本地 Key-Value 存储)
- **通知**: flutter_local_notifications + timezone

## 📦 项目结构

```
lib/
├── main.dart                 # 入口文件，路由劫持
├── models/                   # 数据模型
│   ├── category.dart         # 行为分类
│   ├── action.dart           # 具体行为
│   ├── record.dart           # 时间记录（快照存储）
│   └── settings.dart         # 应用设置
├── services/                 # 服务层
│   ├── database_service.dart # 数据库服务
│   └── notification_service.dart # 通知引擎（弹夹排期）
└── pages/                    # 页面
    ├── quick_input_page.dart     # 极简输入页（通知唤醒）
    ├── dashboard_page.dart       # 数据看板页
    ├── settings_page.dart        # 设置页
    ├── manage_categories_page.dart # 分类管理
    └── manage_actions_page.dart    # 行为管理
```

## 🚀 核心功能

### 1. 动态通知引擎（弹夹排期逻辑）

由于系统限制无法实现任意间隔循环通知，采用"弹夹排期"：
- 用户设置提醒间隔（15~120 分钟）
- 一次性预排 60 个未来通知
- 每次记录后重新排期
- 自动过滤免打扰时间段

### 2. 极简记录流

点击通知 → App 秒开 → 全屏大按钮 → 一键点击 → 震动反馈 → 自动保存 → 提示退出

### 3. 数据看板

- 📊 今日占比环形图
- 📋 时间轴倒序排列
- 🎚️ 间隔设置滑动条

## 🏃 运行项目

```bash
# 安装依赖
flutter pub get

# 运行 (连接设备后)
flutter run

# 运行 Web（开发）
flutter run -d chrome

# 构建 APK
flutter build apk

# 构建 iOS
flutter build ios

# 构建 Web（产物在 build/web）
flutter build web --release
```

## 🌐 网页版（用于 PakePlus 打包）

部署说明见 [web_deploy.md](docs/web_deploy.md)。

## 📱 权限说明

### Android
- `POST_NOTIFICATIONS` - 发送通知
- `RECEIVE_BOOT_COMPLETED` - 开机后恢复通知
- `VIBRATE` - 震动反馈
- `SCHEDULE_EXACT_ALARM` - 精确定时通知

### iOS
- 通知权限（Alert/Badge/Sound）

## 🎨 UI 规范

- **配色**: 纯白背景 / 深色模式纯黑
- **强调色**: 莫兰迪色系（低饱和度蓝、绿、灰等）
- **字体**: 极其克制的黑灰字体
- **交互**: 操作步骤永远 ≤ 2 步，杜绝任何弹窗确认

## 📝 数据模型设计

采用**快照存储**防止外键级联删除导致历史记录丢失：

```dart
// Record 存储的是文本快照，而非外键引用
Record(
  actionName: "跑代码",      // 快照
  categoryName: "科研",     // 快照
  colorHex: "#8B9DC3",     // 快照
)
```

## 📄 License

MIT License
