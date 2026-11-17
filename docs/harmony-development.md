# HarmonyOS 原生端

## 技术与工程

`harmony/` 是独立的 HarmonyOS Stage 模型工程，使用 ArkTS + ArkUI，不依赖 Flutter，也不改变 Android/iOS 的 `core/` 实现。

- 包名：`com.tallyjie.harmony`。
- 应用名：TallyJie。
- 工程当前 target SDK：`26.0.0`；compatible SDK：`6.1.1(24)`，沿用已有工程配置。
- 无新增第三方运行时依赖。
- 首次启动是空数据，不填充演示账单。

```text
harmony/
├── AppScope/                          # 应用标识与资源
├── entry/src/main/ets/
│   ├── entryability/EntryAbility.ets   # 原生入口
│   ├── model/AppData.ets               # 类型、分类、金额、日期、统计、备份校验
│   ├── service/DataStore.ets           # 本地持久化、图片选择与完整备份
│   └── pages/Index.ets                 # 四个主模块与编辑界面
├── entry/src/main/resources/rawfile/  # 与 Flutter 端一致的三款中文字体
├── entry/src/test/LocalUnit.test.ets    # Hypium 领域逻辑测试
└── scripts/test-domain.cjs             # 无设备领域测试运行器
```

## PRD 改造实施入口（2026-11-17）

新版个人记账需求实施计划见 [HarmonyOS 实施任务清单](harmony-implementation-plan.md)，未决规则见 [决策记录](harmony-decisions.md)，本轮验证证据及设备用例见 [验收记录](harmony-acceptance.md)。本节以下“当前实现”仍描述旧版实际能力，不代表新 PRD 已实现。

Task 1 本轮复验：DevEco Studio `26.0.0.865`，SDK 包 `26.0.0.105`，Node `v24.14.1`，Hvigor `6.26.9`，OhPM `26.0.0.630`，JBR `25.0.2`。工程 target/compatible SDK 未修改。平台无关 8 项测试通过；增量 `assembleHap` 退出码 0，生成未签名 HAP，不能当成设备已验收。HDC 返回 `[Empty]`，平台集成与 UI 验收仍 blocked；不自动创建签名、删除数据或推送代码。

后续按每 Task 一次提交推进，Git 格式为 `type(scope): 中文描述`。2026-11-17 用户已确认日记功能删除、仅信用卡可负、周一及自然月/周预算、历史余额0并提示补录、性能指标仅候选；剩余决策见台账，不因执行授权而自动批准；现有真实数据不得用于公开测试夹具。

Task 2 新增 [v2数据契约](harmony-data-contract.md) 与隔离领域模块，原8项+新增13项测试共21项通过；新模块经显式重导出进入实际应用依赖，ArkTS构建成功。普通/信用卡类型、余额限制、日期范围及引用校验已在领域层实现，但旧页面/持久层仍未切换；日记页面实际移除将在 Task 4 执行。

## 当前实现

| 模块 | 支持内容 |
| --- | --- |
| 日记 | 月历、记录日期标记、按日浏览、同一天多篇、新建/编辑/删除、心情、天气、手动地点、最多 9 张照片、图片预览 |
| 记账 | 收入/支出、新建/编辑/删除、18 个支出分类、10 个收入分类、6 个账户、日期时间、备注、最多 9 张凭证 |
| 预算 | 按月设置/修改/取消预算、进度、剩余额、超支提示 |
| 统计 | 按月收入/支出/结余、近六个月收支柱状图、分类金额/比例/笔数、分类跳转账单明细 |
| 筛选 | 按月、收支类型、分类、账户筛选，备注/分类/账户/金额搜索 |
| 设置 | 奶油纸感/汝窑天青/经典黑白、4 档字号、系统字体与 3 款中文字体 |
| 备份 | 通过系统文件选择器导出/恢复鸿蒙版 JSON，包含全部记录、预算、设置和图片 |

交互说明：账单或日记卡片点击进入编辑；编辑页底部可删除；月预算卡片点击修改，金额留空保存可取消预算；返回编辑页会提示放弃修改。

## 数据与安全

- 数据在应用 `filesDir/tallyjie.json`，图片在 `filesDir/images/`。卸载通常会清除数据，请定期导出备份。
- 金额以整数“分”保存，显示时转换为“元”；最多 9 位整数、2 位小数，不接受零金额、负金额、科学计数法。
- 保存先写临时文件并 `fsync`，再重命名替换；写入失败不更新页面内存数据。
- 本地文件读取/校验失败时停止写入，显示错误，不自动清空或覆盖原始文件。
- 从系统照片选择器复制图片到沙箱，不依赖临时 URI 的授权期限；不申请全量相册权限。
- 恢复前确认替换；校验格式、版本、日期、金额、分类、账户、ID、预算及附件路径；附件使用新文件名写入，最后才提交数据。导入失败清理本次新建附件。
- 单张图片最多 8 MB；单次导出最多 40 MB 原始附件；导入文件最多 64 MB。
- JSON 内图片使用 Base64，备份未加密，可能包含财务与日记隐私，需妥善保存。

## 与 Flutter 端的差异及后续工作

这是一版可编译的原生核心实现，不代表 Flutter 所有细节已逐项迁移。

1. **备份格式独立**：仅支持 `format: TallyJie-Harmony`、`version: 1` 的 JSON；不支持 Flutter SQLite 表结构的 JSON 或 ZIP 直接导入，也没有跨端自动同步。
2. **位置为手动输入**：未接入系统定位，也不申请定位权限。
3. **日期时间为文本录入**：保存时严格校验；后续可换成原生日期/时间选择器。
4. **存储规模**：目前使用整份 JSON 原子替换，适合首版本地使用；大量记录建议迁移到关系型数据库，并为统计建立索引。
5. **附件回收**：删除记录、移除照片或取消编辑后，暂不主动清理旧沙箱图片；导出仅包含当前记录引用的附件。后续可增加引用计数/垃圾回收。
6. **界面细节**：采用相同色板与字体，但不是 Flutter 页面逐像素复刻；还需真机检查系统安全区、键盘、大字号、图片与文档选择器、长列表和无障碍。
7. **系统外观**：强制浅色模式，三个主题均为浅色主题。

## DevEco Studio 运行

1. 在 DevEco Studio 中打开仓库的 **`harmony/` 目录**，而不是 Flutter 仓库根目录。
2. 安装匹配工程配置的 HarmonyOS SDK，完成 OhPM/Hvigor 同步。
3. 连接满足 compatible SDK 的真机或启动模拟器。
4. 在 `File > Project Structure > Signing Configs` 为 `default` 配置签名（可使用自动签名）。不要提交个人证书或签名密码。
5. 选择 `entry`，点击 Run。

已有 `local.properties` 为本机配置，不应把开发者的 SDK 绝对路径写入公共构建脚本。

命令行示例（PowerShell，按本机安装路径设置环境）：

```powershell
$studio = 'C:\path\to\DevEco Studio'
$env:DEVECO_SDK_HOME = "$studio\sdk"
$env:JAVA_HOME = "$studio\jbr"
cd harmony
& "$studio\tools\node\node.exe" "$studio\tools\hvigor\bin\hvigorw.js" --mode module -p product=default -p module=entry@default assembleHap --no-daemon
```

未配置签名时会生成：

```text
harmony/entry/build/default/outputs/default/entry-default-unsigned.hap
```

未签名 HAP 不是可直接安装的正式包。

## 测试

`entry/src/test/LocalUnit.test.ets` 可在 DevEco Studio 的本地单元测试功能中运行；也可以通过以下命令在 Node 上执行同一组平台无关断言，不需要安装 npm 依赖：

```powershell
# 在 harmony/ 目录，沿用上文的 $studio 变量
& "$studio\tools\node\node.exe" scripts/test-domain.cjs "$studio\tools\hvigor\hvigor\node_modules\typescript\lib\typescript.js"
```

运行器使用 DevEco 自带 TypeScript 转译纯领域逻辑，并提供最小 Hypium 断言适配；不能代替 ArkTS 编译、设备测试或文件系统集成测试。

当前检查结果：

- Hvigor `assembleHap` 成功，生成未签名 HAP。
- 8 个领域测试通过：金额整数精度、无效金额、日期、月度统计、分类统计、异常备份、重复数据、JSON 往返。
- `hdc list targets` 无设备，未执行真机/模拟器 UI、持久化和系统选择器测试。

建议真机验收顺序：

1. 创建/修改/删除收入和支出；重启确认保存，跨月确认统计边界。
2. 设置预算、修改金额触发超支、清空预算。
3. 同一天添加多篇日记、切换心情天气、添加与移除多图、查看原图。
4. 筛选、搜索、分类明细跳转、跨年六个月趋势。
5. 修改主题、字号和字体，重启检查恢复。
6. 导出带中文内容和图片的备份，恢复后逐项比对。
7. 取消系统选择器、导入损坏/非鸿蒙 JSON、超限图片；确认错误提示及原数据未被覆盖。
