# 随记 (MyNotes)

高性能本地笔记应用，基于 Flutter 构建。支持富文本编辑、文件夹分类、坚果云 WebDAV 云同步。

## 功能

- **富文本编辑** — 基于 flutter_quill 11.x，支持加粗、斜体、下划线、删除线、标题、列表、引用
- **文件夹管理** — 8 色可选，左侧抽屉导航
- **左滑操作** — 置顶、加锁、删除、移动到文件夹
- **回收站** — 30 天自动清理，支持批量恢复/删除
- **云同步** — 通过坚果云 WebDAV 接口同步笔记到云端
- **多格式兼容** — 支持 Delta JSON（flutter_quill）和旧 Markdown 格式
- **暗色模式** — 跟随系统自动切换
- **搜索** — 全文搜索笔记标题和内容

## 技术栈

- Flutter 3.38+ / Dart 3.10+
- [flutter_quill](https://pub.dev/packages/flutter_quill) 11.5.0 — 富文本编辑器
- [sqflite](https://pub.dev/packages/sqflite) — 本地 SQLite 数据库
- [provider](https://pub.dev/packages/provider) — 状态管理
- [flutter_slidable](https://pub.dev/packages/flutter_slidable) — 左滑操作
- [webdav_client](https://pub.dev/packages/webdav_client) — 坚果云 WebDAV 同步

## 快速开始

### 环境要求

- Flutter SDK >= 3.38
- Android SDK（minSdk 由 Flutter 决定）
- 一台 Android 设备或模拟器

### 构建

```bash
# 安装依赖
flutter pub get

# Debug 运行
flutter run

# Release 构建（仅 arm64，APK 约 20MB）
flutter build apk --release --target-platform android-arm64
```

> **注意**：如果你在国内，Gradle 下载依赖可能需要代理。在 `android/gradle.properties` 中取消代理配置的注释即可。

### 坚果云同步配置

1. 注册坚果云账号，在「账户信息 → 安全选项」中生成**第三方应用密码**
2. 在 App 中进入「云同步」设置页面
3. 填入坚果云账号（邮箱）和应用密码
4. 点击「验证并启用同步」

## 项目结构

```
lib/
├── main.dart              # 应用入口
├── app.dart               # MaterialApp 主题配置
├── models/
│   ├── note_model.dart     # 笔记数据模型
│   └── folder_model.dart   # 文件夹模型
├── services/
│   ├── database_service.dart    # SQLite 数据库
│   ├── file_service.dart        # 文件系统管理
│   └── nutstore_sync_service.dart  # 坚果云 WebDAV 同步
├── providers/
│   └── notes_provider.dart      # 状态管理
├── screens/
│   ├── home_screen.dart         # 首页 + 左侧抽屉
│   ├── editor_screen.dart       # 富文本编辑器
│   ├── trash_screen.dart        # 回收站
│   └── nutstore_settings_screen.dart  # 云同步设置
└── widgets/
    └── note_card.dart           # 笔记卡片组件
```

## 数据存储

笔记正文以 Delta JSON 格式存储在设备外部存储的 `MyNotes/contents/` 目录下，SQLite 数据库存储元数据。可选迁移到公共目录（`/storage/emulated/0/MyNotes/`）以便其他应用（如夸克）备份。

## License

MIT
