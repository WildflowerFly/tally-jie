# 开发与架构说明

## 支持范围与目录约定

应用只支持 Android 和 iOS。Flutter 工程根目录保留 `pubspec.yaml`、`.metadata`、静态检查配置和 `lib/main.dart`，以便直接使用标准 Flutter 命令，避免修改 Android Gradle / iOS Xcode 的默认工程定位。

- `android/`：Android 原生代码、Manifest、资源与 Gradle 配置。
- `ios/`：iOS 原生代码、Info.plist、资源与 Xcode 工程。
- `core/`：名为 `tallyjie_core` 的本地 Flutter 包，两端共用的应用入口、UI、业务逻辑、数据库、字体和测试均在此维护。
- `docs/`：除根目录 `README.md` 以外的 Markdown 文档统一放在这里；不要在原生资源目录新增文档。

根工程通过 `path: core` 依赖共用包。`lib/main.dart` 仅委托 `package:tallyjie_core/main.dart`，不放业务逻辑。`core/lib/core/` 是包内部的基础设施分层，并非另一个独立包。

## 共用代码分层

| 路径 | 职责 |
| --- | --- |
| `core/lib/main.dart` | 初始化主题、字体、字号与图片缓存，启动应用 |
| `core/lib/app/router.dart` | 三个主页面的路由与导航状态 |
| `core/lib/app/constants.dart` | 应用常量与数据库版本 |
| `core/lib/app/theme/` | 主题、颜色、字体、字号、圆角与阴影 |
| `core/lib/core/database/database_helper.dart` | SQLite 建表、种子数据与迁移 |
| `core/lib/core/services/local_data_api.dart` | 日记、账单、预算与备份接口 |
| `core/lib/core/models/` | 基础数据模型 |
| `core/lib/core/utils/` | 日期与金额工具 |
| `core/lib/core/widgets/` | 图片缓存、胶囊导航等共用组件 |
| `core/lib/features/` | diary、ledger、statistics、settings 功能 |
| `core/assets/fonts/` | 两端共用的中文字体 |
| `core/test/` | 共用代码的单元测试与 Widget 测试 |

导航使用 `StatefulShellRoute.indexedStack` 保留各主页面状态，支持点击与左右滑动切换。设置通过弹窗打开。页面的私有组件目前主要与对应页面放在同一个 Dart 文件中。

## 依赖与资源

- UI：Flutter、flutter_riverpod、go_router、flutter_animate。
- 数据：sqflite、shared_preferences、path、intl、uuid。
- 设备功能：image_picker、geolocator、geocoding。
- 备份：archive、file_selector、path_provider。

共用业务依赖在 `core/pubspec.yaml` 声明，根工程仅依赖 Flutter 和本地共用包。实际解析版本由根目录 `pubspec.lock` 锁定。Flutter 插件可能传递依赖其他平台的实现包，这不代表本项目支持或保留对应平台工程，不应手工删除这些插件的依赖项。

字体在共用包中声明，使用 `packages/tallyjie_core/<字体名>` 引用。后续新增包内图片等资源时也要正确使用包资源路径或 `package: 'tallyjie_core'`。

`sqflite_common_ffi` 仅作为 `core/` 的开发依赖，供宿主机上的测试使用；它不是桌面应用支持代码。

## 数据存储

两端统一使用 SQLite 数据库 `tallyjie.db`，当前版本为 **4**。`DatabaseHelper` 负责首次创建和旧版本迁移，不再提供 Web 内存存储分支。

| 数据域 | 数据表 |
| --- | --- |
| 日记 | `diary_entries`、`diary_attachments` |
| 记账 | `ledger_categories`、`ledger_accounts`、`ledger_transactions`、`transaction_attachments` |
| 预算 | `monthly_budgets` |
| 设置 | `theme_settings`、`app_settings` |
| 预留能力 | `daily_tasks`、`auto_detected_bills`（当前 UI 未开放） |
| 备份记录 | `backup_records` |

日记和账单采用软删除，保留 `server_id`、`sync_status`、`synced_at`、`revision` 等字段，当前没有云端账号或自动同步。主题、字体和字号使用 SharedPreferences 保存。

备份格式为 `tallyjie.backup.v1`：

```text
TallyJie_backup_YYYYMMDD_HHMM.zip
├── tallyjie_backup.json     # 表数据、附件映射和元信息
└── assets/                  # 日记图片与账单凭证
```

导入会替换本地数据。修改数据库结构时递增 `AppConstants.dbVersion` 并补充 `DatabaseHelper._onUpgrade`；新增备份数据表时同步维护 `core/lib/core/services/local_data_api.dart` 中的表清单及导入、删除顺序。

## 开发与验证命令

以下命令在仓库根目录执行：

```bash
flutter doctor
flutter pub get
flutter analyze
dart format lib core/lib core/test
flutter devices
flutter run -d <android-or-ios-device-id>
flutter build apk --release
flutter build appbundle --release
# 需要 macOS 和 Xcode
flutter build ios --release
```

共用包独立安装测试依赖并检查：

```bash
cd core
flutter pub get
flutter analyze
flutter test
```

当前测试包含应用启动 Smoke Test，SQLite 使用测试专用 FFI 实现。修改数据库、备份恢复、金额或日期逻辑时应补充测试；发布前仍需在 Android / iOS 设备上验收持久化、附件、权限和备份导入导出。

## 权限与提交规范

- 定位：日记中记录当前位置并反向解析地名。
- 相册：选择日记图片、账单凭证。
- 相机：拍摄账单凭证。

Android 权限位于 `android/app/src/main/AndroidManifest.xml`，iOS 使用说明位于 `ios/Runner/Info.plist`。

不要提交本地数据库、备份、构建产物或包含个人信息的附件。不要为本项目重新生成非移动平台目录；如确需重新生成工程，请显式指定 `flutter create --platforms=android,ios .`，并检查其对现有原生定制的影响。
