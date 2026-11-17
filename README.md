# TallyJie

> 记录生活，而不是记录数字。

TallyJie 是一款本地优先生活记录应用。Android 和 iOS 使用 Flutter 开发；`harmony/` 提供独立的 **HarmonyOS 原生版（ArkTS + ArkUI）**，运行方式与当前功能差异见 [鸿蒙端开发说明](docs/harmony-development.md)。

## HarmonyOS 原生端（本轮重构）

Harmony 现按本地个人账本实现，默认记账，五入口为统计、明细、记账、存款、我的：

- 动态账户/分类、初始余额、收支编辑删除；仅信用卡账户允许负余额。
- 组合检索与游标分页展示、周/月/年/自定义统计及列表下钻、总/分类预算。
- 账户滑动卡片、余额及最近记录、独立转账和信用卡还款。
- CSV自定义列映射、无损关联表、JSON预览合并及包含附件/旧归档的可移植备份；规范见[数据交换说明](docs/harmony-import-export.md)。
- 日记/外观设置不再提供；旧迁移源文件保留，不自动删除。

**状态：Implementing，非已验收发行版。** 数据库索引分页/差量写入、图表点选、扇叠卡片及完整备份已补齐代码与主机回归；设备故障、视觉交互与性能验收仍待执行，详见[实施计划](docs/harmony-implementation-plan.md)及[验收记录](docs/harmony-acceptance.md)。当前产物未签名，本机API26模拟器已安装并通过8项平台测试；不代表实体机可安装或已满足上线验收。

## Flutter Android / iOS 主要功能

- **日记**：按日期浏览、多篇日记、心情与天气、定位、多图附件、编辑与删除。
- **记账**：收入与支出、分类与账户、消费凭证、月度预算与超支提醒。
- **统计**：账单筛选与搜索、收支趋势、分类占比、分类账单明细。
- **个性化**：3 套主题、4 档字号、系统字体与 3 种内置中文字体。
- **本地备份**：导出 ZIP 备份，恢复 TallyJie ZIP/JSON 数据与附件。

> [!WARNING]
> Flutter 导入备份会替换当前本地数据，请先导出现有数据。Harmony 新账本交换采用预览合并，协议与 Flutter 备份不同，不可混用。

## 项目结构

```text
TallyJie/
├── android/                 # Android 原生工程、权限和平台集成
├── ios/                     # iOS 原生工程、权限和平台集成
├── core/                    # Android / iOS 共用的 Flutter 本地包
│   ├── lib/
│   │   ├── app/             # 路由、主题、字体和应用配置
│   │   ├── core/            # 数据库、模型、数据服务、工具和共享组件
│   │   ├── features/        # 日记、记账、统计、设置
│   │   └── main.dart        # 共用的应用启动逻辑
│   ├── assets/fonts/        # 共用字体资源
│   ├── test/                # 共用代码测试
│   ├── analysis_options.yaml
│   └── pubspec.yaml         # 共用代码的依赖与资源声明
├── harmony/                 # HarmonyOS 原生工程（ArkTS + ArkUI）
├── docs/                    # 除本 README 外的所有 Markdown 文档
├── lib/main.dart            # Flutter 工程所需的薄入口，仅调用 core
├── pubspec.yaml             # 移动端宿主配置，依赖本地 core 包
└── pubspec.lock             # 应用依赖锁定文件
```

`lib/main.dart` 和根目录配置用于保持 Flutter 标准构建方式，不承载业务实现。两端的共用代码放在 `core/`，平台专属代码分别放在 `android/` 和 `ios/`。仓库不再包含桌面端和 Web 工程，也不保留 Web 内存数据实现。

## 快速开始

环境要求：Flutter 3.44.6 stable（Dart SDK `^3.12.2`）；Android 需要 Android SDK 和 Java 17；iOS 需要 macOS 与 Xcode。

```bash
git clone https://github.com/WildFlowerRed/TallyJie.git
cd TallyJie
flutter pub get
flutter analyze
flutter devices
flutter run -d <android-or-ios-device-id>
```

在仓库根目录运行共用代码测试：

```bash
flutter test core/test
```

也可在 `core/` 中独立执行 `flutter pub get`、`flutter analyze` 和 `flutter test`。

在仓库根目录构建：

```bash
flutter build apk --release
flutter build appbundle --release
# 仅 macOS
flutter build ios --release
```

## 文档

- [开发与架构说明](docs/development.md)
- [HarmonyOS 原生端运行与实现说明](docs/harmony-development.md)
- [iOS 启动图片说明](docs/ios-launch-image.md)

## License

MIT License © 2026 BlockChain
