# TallyJie HarmonyOS 端项目实施任务清单

> 文档状态：Draft v1.0  
> 编写日期：2026-11-17  
> 来源：`docs/PRD.md`、`docs/porject-task-step.md`、当前 HarmonyOS 工程源码  
> 适用仓库：`TallyJie`，实施范围为 `harmony/` 及相关 `docs/` 文档  
> 目标：将现有 HarmonyOS 原生生活记录应用演进为符合 PRD V1.0 的本地个人记账工具，形成可执行、可验证、可追溯的分批实施计划。  
> 执行状态：Task 1、2 已完成；Task 3 持久层/迁移实现与 Task 4 五页骨架已提交，设备验收仍 blocked，未验收 Step 保持未勾选。Task 5 账户服务/管理界面已实现，设备验证待执行；Task 6 分类管理已实现（记账联动待Task7）；Task 7～14 未实施；不得将构建通过视作数据库安全、视觉或端到端验收通过。证据见 `docs/harmony-acceptance.md`。

## 1. 执行约定

### 1.1 范围与现状基线

本次只规划 **HarmonyOS 手机端，ArkTS + ArkUI、Stage 模型**。不将 Flutter 移植到鸿蒙，不修改 `android/`、`ios/`、`core/`、`lib/` 或 Flutter 依赖，不开展 Android/iOS 同步开发。PRD 第七章的跨平台兼容要求，本期只执行 HarmonyOS 设备适配；其余平台延期。

代码检查基线：当前 HEAD 为 `ce51113`；工作区已有文档删除及未跟踪的 `docs/porject-task-step.md`，视为用户已有改动，不恢复、不覆盖。本文使用新文件路径，避免复用已删除的旧实施文档。

| 检查对象 | 当前实际实现 | 与新 PRD 的差距及处理方向 |
| --- | --- | --- |
| `harmony/entry/src/main/ets/pages/Index.ets` | 约 570 行单页面，集合界面、编辑、筛选、统计、设置；默认 `tab = 0` 对应日记 | 改为统计、明细、记账、存款、我的；默认索引 2；拆出页面、共享组件和应用服务 |
| `harmony/entry/src/main/ets/model/AppData.ets` | `AppData.version = 1`；交易按账户/分类名称关联；18 个支出分类、10 个收入分类、6 个账户为常量 | 建立稳定账户/分类 ID、初始余额、创建时间、转账和周期预算模型；名称不再充当关联键 |
| `harmony/entry/src/main/ets/service/DataStore.ets` | `filesDir/tallyjie.json` 整文件同步读写；临时文件、`fsync`、重命名；写入成功后更新内存 | 保留已有失败保护思想；拟迁移关系型数据库，以支持事务、索引、组合筛选及分页，见 D-01 |
| 记账与明细 | 已有收入/支出增删改、日期时间文本校验、备注、最多 9 张图片、按月筛选 | 缺账户/分类管理、独立详情、按日分组、任意日期与金额范围筛选、分页；时间选择需改原生交互 |
| 统计与预算 | 月收入/支出/结余、近六个月柱图、分类金额比例及跳转；月度总预算 | 缺统一周期、周/年/自定义范围、日周月粒度、环图交互、分类预算和消费分析 |
| 账户与存款 | 固定账户名称，未建独立账户实体 | 缺初始余额、当前余额、账户详情、层叠卡片、迁移关联账单及转账 |
| 现有导入导出 | 仅 `format: TallyJie-Harmony`、`version: 1` JSON 全量替换，含日记、设置和 Base64 图片 | 不是 PRD 的 CSV 预览/追加导入；需独立的新数据交换契约，不能直接复用破坏性恢复逻辑 |
| 测试 | `LocalUnit.test.ets` 含 8 个领域用例；`scripts/test-domain.cjs` 仅加载一个领域文件和该测试 | 扩展纯领域测试运行器；另加数据库、文件选择器、迁移、ArkUI 及设备测试，不能用 Node 测试代替平台验证 |
| 工程配置 | target SDK `26.0.0`、compatible SDK `6.1.1(24)`；手机；无运行时第三方依赖 | 沿用并先验证本机 SDK 可用性，不为匹配文档随意降级；设备范围待确认 |
| 签名与平台集成 | `signingConfigs` 为空，存在系统 `EntryBackupAbility` | 设备安装需要本机签名；不提交证书；系统备份声明与新产品本地化策略需核查，见 D-06 |

上述内容为源码静态检查结果。`docs/harmony-development.md` 中记载的历史构建成功、8 项测试通过及无设备状态，**不是本轮复验结果**。

### 1.2 实施与架构约束

- 原则顺序：先写失败测试 → 确认因目标能力缺失而失败 → 最小实现 → 局部验证 → 全量验证。纯文档、环境和视觉评审采用清单/截图验收，不虚构失败测试。
- 建议分层：`pages/components → state/AppState → service → repository → database`；`domain` 只放无平台依赖的金额、日期、筛选口径与计算规则，`model` 放实体/DTO。
- 页面不直接写数据库、操作文件或拼接统计 SQL；持久层不调用 UI 提示。服务返回稳定错误码，页面映射中文提示。
- `Index.ets` 保留为唯一 `@Entry` 页面，通过内部导航组织子页面；拟新增页面作为普通组件。若改用独立路由页面，必须同时更新 `main_pages.json` 和导航测试，不并行建设两套路由。
- 所有持久化写操作串行进入应用服务；数据库事务提交后才刷新状态。使用递增数据修订号废弃迟到查询结果，防止快速切换账户/筛选时旧响应覆盖新页面。
- 首期不引入第三方图表库，优先 ArkUI 原生绘制；新增运行时依赖须说明必要性、许可证和离线影响并评审。
- 本文新增路径均为**计划交付路径，不代表现有文件**；D-01 关联的数据库文件按推荐方案列出，决策变更时先修订任务，不同时实施两套存储方案。

### 1.3 数据、安全与兼容约束

- 金额以整数“分”保存，禁止以浮点元累计。沿用单笔正向交易上限 `99999999999` 分（`999999999.99` 元）；初始余额支持 0，仅信用卡类型支持负初始/当前余额，普通账户不得为负（用户本轮确认 D-03）。每次累计也检查安全整数及数据库取值边界。
- 账单方向只允许 `income/expense`，金额必须大于 0；转账独立实体，不以两条普通收支伪装实现。账户不设类型字段。
- 统一查询口径：日期按设备本地民用日期；领域范围起止日均包含，持久查询可换算成开始日包含、结束日下一天不包含。交易日期/时间与 `createdAt/updatedAt` 分离。周一起点、自然月/周预算已由用户确认，其他 D-05 统计口径仍待确认。
- 数据库结构版本、导出格式版本分别维护；迁移只向前逐版本执行。旧 `version: 1` 数据先完整校验，再映射，不原地覆盖旧文件。未知高版本、损坏文件必须阻止写入，不能当空库启动。
- 旧日记、图片、设置不属于新产品活跃功能，但未经批准不得删除；执行 D-02 的保留/归档方案。旧备份格式与新导出格式不得混淆。
- 无登录、无服务端、无云同步，不申请网络、银行卡、定位或全量相册权限来完成本期需求。文件交换使用系统文档选择器，仅访问用户选择的 URI。
- 不记录账单备注、日记正文、完整导入文件和附件到日志；只记录错误码、耗时、数量等必要诊断信息。导出明文文件前提示隐私风险。
- 不手改 `harmony/oh_modules/`、`.hvigor/`、`entry/build/` 等依赖/生成产物；依赖由 DevEco/OhPM 同步，锁文件只随实际依赖变动更新。`local.properties` 不写入公共 SDK 路径。
- 初版仅新增本文；2026-11-17 用户已授权从 Task 1 实施、逐步勾选、每个 Task 单独提交 Git，提交格式为 `type(scope): 中文描述`，禁止推送。不得未经授权发布、卸载应用、删除用户数据、替换已有备份或提交签名材料。风险性数据实验使用测试沙箱。

### 1.4 验证入口约定

以下为验证入口。初版编制时未执行；Task 1 已实际复验 V-01/V-02 并探测设备，结果见第 7 章。后续任务仍须记录各自实际版本及输出，不得将 Expected 或历史通过作为本任务结果。

**V-01：平台无关领域测试**

执行目录：仓库根目录的 Windows PowerShell。先将 `$studio` 设置为本机已安装的 DevEco Studio 实际目录（会话变量，不提交路径）：

```powershell
$studio = (Read-Host '输入本机 DevEco Studio 安装目录')
$node = Join-Path $studio 'tools\node\node.exe'
$ts = Join-Path $studio 'tools\hvigor\hvigor\node_modules\typescript\lib\typescript.js'
Test-Path $node
Test-Path $ts
Push-Location harmony
& $node scripts/test-domain.cjs $ts
Pop-Location
```

Expected：两个路径检查均为 `True`；运行器输出全部测试名称及通过总数，进程退出码为 0。新增多文件领域模块时，由 Task 2 同步扩展显式模块映射和测试注册；当前运行器不会自动发现新增测试。数据库、ArkUI 与 Harmony Kit 不得伪造为 Node 已验证。

**V-02：ArkTS/ArkUI 编译和 HAP 构建**

前置：V-01 的安装目录变量已设置，DevEco 已同步匹配 SDK 和依赖。在仓库根目录运行：

```powershell
$env:DEVECO_SDK_HOME = Join-Path $studio 'sdk'
$env:JAVA_HOME = Join-Path $studio 'jbr'
$hvigor = Join-Path $studio 'tools\hvigor\bin\hvigorw.js'
Push-Location harmony
& $node $hvigor --mode module -p product=default -p module=entry@default assembleHap --no-daemon
Pop-Location
```

Expected：构建成功，无 ArkTS/资源错误；未签名配置下检查 `harmony/entry/build/default/outputs/default/entry-default-unsigned.hap`。实际 SDK/JBR 布局以本机安装为准，由 Task 1 校正执行记录。未签名包不等于可安装交付包。

**V-03：平台集成与设备验收**

在 DevEco 打开 `harmony/`，配置本机签名；选择满足兼容版本的模拟器/真机。通过 IDE 运行 `entry/src/ohosTest` 的测试目标，并以 Run 安装应用执行任务中的人工用例。用例清单在 Task 1 建立，最终保留测试报告、录屏/截图、设备版本及冷启动记录。无在线设备时明确 `blocked`，提供方为实施人员/设备负责人；解除条件为可安装测试包的设备及有效本机签名。不能用 V-01 或 V-02 替代。

## 2. 开发前决策闸门

以下推荐值以决策记录为准；2026-11-17用户已确认删除日记功能、仅信用卡可负、周一及自然月/周预算、历史余额0并提示补录、性能值仅候选，其余不视为批准。产品规则由需求方确认，存储与环境方案由实施负责人评审；决策结果记录在计划新增的 `docs/harmony-decisions.md`，包含日期、依据、批准人、影响任务。未确认只能做不依赖该规则的测试设计或隔离实现。

| ID | 决策 | 推荐默认值/需提供依据 | 阻断任务 |
| --- | --- | --- | --- |
| D-01 | 继续 JSON 还是迁移关系型数据库 | 推荐 HarmonyOS `relationalStore`，数据模型版本 2，事务/外键/索引支持须先在目标 SDK 验证；不采用双写长期过渡 | Task 3，以及依赖持久层的后续集成 |
| D-02 | 新定位下日记、照片、主题和旧备份如何处置 | 已确认删除日记页面和功能；旧文件/图片暂保留；归档和新导出兼容策略仍待确认 | Task 3、Task 4 的旧入口下线、Task 13 的旧格式兼容和最终验收 |
| D-03 | 信用卡消费/还款、负余额及转账约束 | 已确认仅信用卡类账户允许负初始/当前余额；新增 standard/credit 类型，不靠名称判定；写入后全账户最终余额须满足约束；特殊还款业务不扩展 | Task 2 的符号边界、Task 5 余额验收、Task 12 |
| D-04 | CSV/JSON 导入模式、关联创建及重复识别 | 推荐 CSV 追加且不自动新建账户/分类，逐项映射；JSON 默认合并，预览冲突，不静默覆盖；完整格式支持同 ID 同内容跳过、同 ID 异内容报冲突 | Task 13 的格式冻结、写入和去重 |
| D-05 | 周期、重复预算、统计口径 | 周一为周首、自然月/周预算已确认；自定义范围保留 PRD 契约；重叠、日均分母及循环自动复用待确认 | Task 2 周期口径、Task 9、Task 10 |
| D-06 | 存量账户余额、历史创建时间及系统备份政策 | 已确认迁移初始余额设 0 并提示补录，禁止推算真实余额；旧账单创建时间未知则存空并展示“历史数据未记录”，不伪造；核查系统备份是否传输用户数据，未确认不新增备份能力 | Task 3、Task 5 的历史余额说明、Task 8 的历史详情、Task 14 |
| D-07 | 设备、容量和性能验收线 | 仅候选（用户确认不作已定验收线）：基准数据 10,000 笔、20 账户、100 分类；每页 50 条；目标冷启动可交互 ≤2 秒、保存反馈 ≤300ms、筛选首屏 ≤500ms；由需求方确认测试机型、OS、计时边界与指标 | Task 14 性能结论；Task 1 可先采集环境 |

无外部银行对接或云端协议依赖。信用卡规则未确认不妨碍普通收入/支出表单与 UI 框架先行，但不能宣称信用卡验收通过。

## 3. 依赖顺序

| 阶段 | 目标 | 任务 |
| --- | --- | --- |
| A：基线与数据基础 | 环境、规则、测试入口、迁移与一致性基础 | Task 1～3 |
| B：核心记账闭环 | 五页骨架、账户/分类、快速记账、明细管理 | Task 4～8 |
| C：分析与预算 | 统一范围统计、周期和分类预算 | Task 9～10 |
| D：账户体验与数据管理 | 存款卡片、转账、CSV/JSON 交换 | Task 11～13 |
| E：交付 | 设备、兼容、性能、异常与交付验收 | Task 14 |

硬依赖如下；各任务的决策条件仍需同时满足：

```text
Task 1 → Task 2 → Task 3
Task 1 + Task 2 → Task 4
Task 3 + Task 4 → Task 5、Task 6（可并行）
Task 5 + Task 6 → Task 7 → Task 8
Task 8 → Task 9 → Task 10
Task 8 → Task 11 → Task 12
Task 8 + Task 10 + Task 12 → Task 13
Task 1～13 → Task 14
```

Task 9～10 与 Task 11～12 可并行；Task 13 可提前设计解析器/预览，但完整写入验收必须等待预算与转账模型稳定。Task 4 的空态/视觉设计可与 Task 3 并行，不读取半迁移数据。文档和用例随对应任务持续同步，不构成反向依赖。

---

## Task 1：建立工程基线、决策记录和验证入口

**Files:**

- Create: `docs/harmony-decisions.md`、`docs/harmony-acceptance.md`
- Modify: `docs/harmony-development.md`

**Covers:** SUP-01、REQ-15、REQ-16。  
**Produces:** 可复现的环境记录、需求编号、决策台账及 V-01～V-03 基线结果。  
**Status:** done（环境与文档基线）；V-01/V-02 已通过，V-03 环境探测完成但设备验收 blocked；产品规则仍 pending，不等于整体已验收。  
**Depends:** 无；设备验证依赖实施人员提供 DevEco、SDK、签名和兼容设备。

- [x] **Step 1：登记环境与范围**：记录 Git 版本和工作区改动、DevEco/SDK/OhPM/Hvigor/Node 版本；核对 `build-profile.json5`，不擅自修改 SDK。
- [x] **Step 2：评审决策**：逐项记录 D-01～D-07；未确认项保持 pending；无设备则记录 blocked、提供方和解除条件。已登记于 `docs/harmony-decisions.md`；本步完成的是决策梳理，不代表需求方已批准推荐值。
- [x] **Step 3：执行替代检查**：本任务为环境/文档任务，不适用失败测试；执行 V-01、V-02，记录现有 8 项领域测试及构建实际结果；编制 V-03 用例目录。
- [x] **Step 4：同步文档**：区分历史结果与本次结果，记录旧数据样本的生成方法，禁止拿真实隐私账单做共享测试夹具。已更新开发说明，合成夹具方法与验收用例见 `docs/harmony-acceptance.md`。
- [x] **Step 5：验证**：检查文档链接、命令路径、环境版本和决策阻断关系。Expected：其他人员可按记录复现基线；没有环境的验证明确未执行，不伪装通过。实际：14 个 Task 编号、Markdown 围栏、文档相对链接与 Git diff 检查通过；V-01/V-02 复验通过，无设备明确 blocked。证据见 `docs/harmony-acceptance.md`。

## Task 2：定义稳定实体、整数金额和统一查询口径

**Files:**

- Modify: `harmony/entry/src/main/ets/model/AppData.ets`、`harmony/scripts/test-domain.cjs`、`harmony/entry/src/test/LocalUnit.test.ets`、`harmony/entry/src/test/List.test.ets`
- Create: `harmony/entry/src/main/ets/model/LedgerModels.ets`、`harmony/entry/src/main/ets/domain/Money.ets`、`harmony/entry/src/main/ets/domain/DateRange.ets`、`harmony/entry/src/main/ets/domain/LedgerRules.ets`
- Create: `harmony/entry/src/test/LedgerDomain.test.ets`、`docs/harmony-data-contract.md`

**Covers:** REQ-03、REQ-04、REQ-05、REQ-08、REQ-09、REQ-11、REQ-14、REQ-15。  
**Produces:** 版本化实体、可独立测试的领域规则与数据字典；旧 v1 类型作为兼容输入保留，不提前破坏现有页面。  
**Status:** done（隔离领域契约）；21 项领域测试通过，新模块已纳入实际 ArkTS 应用编译；未接页面/持久层。
**Depends:** Task 1；D-03、D-05 对应规则确认，其他实体定义可先推进。

- [x] **Step 1：先编写测试**：覆盖 `0.10+0.20=0.30`、零/负交易/三位小数/科学计数/上限；初始余额留空；闰日、跨年周/月和范围边界；分类收支类型不匹配；引用不存在；重复 ID；累计溢出。新增 `LedgerDomain.test.ets`，同时覆盖仅信用卡负余额及迁移补录提示。
- [x] **Step 2：确认预期失败**：扩展运行器的显式纯模块映射及测试注册后执行 V-01；Expected：因新规则未实现的业务断言失败，而非无法加载 `.ets` 或 Harmony Kit。实际：旧 8 项通过，新测试 `decimalAmountsAreIntegerCents` 因 `0 !== 30` 失败，退出码 1；新模块均成功加载。
- [x] **Step 3：实现契约**：账户 `id/name/type/initialBalanceCents/needsInitialBalance/createdAt/updatedAt`；分类 `id/type/name/iconKey/sortOrder/createdAt/updatedAt`；账单 `id/type/amountCents/accountId/categoryId/date/time/note/createdAt/updatedAt`；转账 `id/fromAccountId/toAccountId/amountCents/date/time/note/createdAt/updatedAt`；预算 `id/scope/categoryId/amountCents/period/startDate/endDate/createdAt/updatedAt`，空值/循环规则在数据字典明确。
- [x] **Step 4：同步契约与兼容边界**：统一筛选对象含类型、账户、分类、日期、金额、关键词和稳定排序游标；历史附件保留关联，旧创建时间可空；同名分类按收入/支出分别识别。明确错误码如 `INVALID_AMOUNT`、`REFERENCE_IN_USE`、`IMPORT_CONFLICT`，后续任务复用。
- [x] **Step 5：验证**：执行 V-01、V-02。Expected：新旧领域测试均通过，实体通过 ArkTS 编译；新建实体具有稳定 ID，改名不改变关联，所有金额累计保持安全整数。实际：21项测试通过；新模块显式接入编译依赖，修复 ArkTS 结构类型兼容问题后 assembleHap 成功（7s224ms），退出码0。证据见 `docs/harmony-acceptance.md` 第5节。

## Task 3：建设事务持久层并完成旧 JSON 安全迁移

**Files:**

- Modify: `harmony/entry/src/main/ets/service/DataStore.ets`
- Create: `harmony/entry/src/main/ets/database/LedgerDatabase.ets`、`harmony/entry/src/main/ets/database/SchemaMigrations.ets`、`harmony/entry/src/main/ets/repository/LedgerRepository.ets`、`harmony/entry/src/main/ets/service/LegacyMigrationService.ets`
- Create: `harmony/entry/src/ohosTest/ets/test/DatabaseMigration.test.ets`、`harmony/entry/src/ohosTest/ets/test/Persistence.test.ets`
- Modify: `harmony/entry/src/ohosTest/ets/test/List.test.ets`、`docs/harmony-data-contract.md`

**Covers:** REQ-04、REQ-05、REQ-14、REQ-15。  
**Produces:** 可重启、可事务回滚、带版本和索引的本地存储；旧数据只迁移一次且保留恢复依据。  
**Depends:** Task 2；D-01、D-02、D-06；数据库集成测试依赖 V-03 环境。

- [ ] **Step 1：先编写迁移/故障测试**：覆盖无文件首启、合法 v1、重复迁移、空数据、中文、同名不同类型分类、图片关联、未知版本、损坏 JSON、磁盘不足、提交中断及迁移后重启。
- [ ] **Step 2：确认预期失败**：执行 V-03 对应平台测试；Expected：因尚无新数据库和迁移标记导致断言失败。SDK/设备不可用是环境 blocked，不是预期失败。
- [x] **Step 3：实现数据库与迁移**：推荐账户、分类、账单、预算、转账、导入来源及迁移元数据表；日期/时间/ID 复合排序索引及账户/分类查询索引；外键和删除限制在 SDK 验证后启用，服务层仍校验引用。数据库变更仅由版本化迁移执行。
- [x] **Step 4：保证一次性切换**：先校验旧文件，按名称映射固定账户、按类型与名称映射分类，保留账单 ID 和日期时间；初始余额 0，旧月预算映射到同月范围，图片路径不随意重命名。日记/设置按 D-02 归档并记录位置、数量及校验值。关系写入和迁移完成标记同事务提交；仅提交成功才选择新库，不双写；保留原文件。失败回滚新库，保留旧文件且阻止写入，不能静默返回空数据。
- [ ] **Step 5：验证**：V-01、V-02、V-03；比较迁移前后各类记录数量、逐条金额、ID/附件关系、每月汇总及重启结果。Expected：失败原文件字节不变；中断重试无重复；空库无演示账单。旧版应用不能直接读新库，回退仅限使用迁移前副本，迁移后新增数据须先导出，禁止将“回退”解释为可无损降级。

## Task 4：搭建五页导航、统一视觉和状态刷新框架

**Files:**

- Modify: `harmony/entry/src/main/ets/pages/Index.ets`、`harmony/entry/src/main/ets/entryability/EntryAbility.ets`
- Create: `harmony/entry/src/main/ets/state/AppState.ets`、`harmony/entry/src/main/ets/theme/FinanceTheme.ets`、`harmony/entry/src/main/ets/components/FloatingNavBar.ets`
- Create: `harmony/entry/src/main/ets/pages/StatisticsPage.ets`、`harmony/entry/src/main/ets/pages/DetailsPage.ets`、`harmony/entry/src/main/ets/pages/RecordPage.ets`、`harmony/entry/src/main/ets/pages/DepositsPage.ets`、`harmony/entry/src/main/ets/pages/ProfilePage.ets`
- Create: `harmony/entry/src/ohosTest/ets/test/Navigation.test.ets`
- Modify: `harmony/entry/src/ohosTest/ets/test/List.test.ets`

**Covers:** REQ-01、REQ-02、REQ-12、REQ-15、REQ-16。  
**Produces:** 五入口正确排序、默认记账、金融视觉、统一加载/错误/空态及查询刷新机制。  
**Depends:** Task 1、Task 2；旧入口下线依赖 D-02；本任务骨架不依赖数据库完成。

- [x] **Step 1：先编写验收用例**：冷启动默认记账；五入口顺序；切页不重复保存；编辑返回提示；载入失败禁止记账；快速切换后迟到结果不覆盖当前页。
- [ ] **Step 2：确认预期失败**：V-03 验证当前四页导航不满足用例；视觉部分采用设计截图比对，不要求伪造自动失败。
- [x] **Step 3：实现界面骨架**：默认索引 2；背景 `#F5F5F5`、主文字 `#171717`、收入 `#269B73`、支出 `#E16C61`，白色大圆角卡片、深色悬浮导航；统一间距/字体/圆角。移除日记和外观设置活跃入口，不删除归档数据或 Flutter 功能。
- [x] **Step 4：同步导航和状态**：子页面只消费状态及调用服务；成功写入统一触发余额/明细/统计/预算失效与刷新；保留写入失败时的输入。导航、弹窗、键盘和滚动区域避开底部安全区，未实现页面明确显示待接入空态而不是假数据。
- [ ] **Step 5：验证**：V-02、V-03；小屏、长文本、系统大字号、键盘弹出与系统返回检查。Expected：默认直接可见记账表单；五入口无错位、遮挡；加载失败可见明确原因；编译通过不代表视觉已验收。

## Task 5：实现自定义账户管理和统一余额服务

**Files:**

- Create: `harmony/entry/src/main/ets/service/AccountService.ets`、`harmony/entry/src/main/ets/pages/AccountManagePage.ets`、`harmony/entry/src/main/ets/pages/AccountEditPage.ets`
- Modify: `harmony/entry/src/main/ets/repository/LedgerRepository.ets`、`harmony/entry/src/main/ets/pages/ProfilePage.ets`、`harmony/entry/src/main/ets/state/AppState.ets`
- Create: `harmony/entry/src/test/AccountRules.test.ets`、`harmony/entry/src/ohosTest/ets/test/AccountFlow.test.ets`
- Modify: `harmony/scripts/test-domain.cjs`、`harmony/entry/src/test/List.test.ets`、`harmony/entry/src/ohosTest/ets/test/List.test.ets`

**Covers:** REQ-04、REQ-12、REQ-14。  
**Produces:** 账户新增/编辑/删除、初始余额补录、引用保护和可复用余额查询。  
**Depends:** Task 3、Task 4；D-03、D-06 的余额规则。

- [ ] **Step 1：先编写测试**：名称空白、同名冲突、留空初始余额、负余额、补录和改名；无关联删除、有关联拒删；迁移到有效目标；迁移后转账同源同目标风险；写入失败不刷新。
- [ ] **Step 2：确认预期失败**：V-01 的纯规则及 V-03 的账户持久化用例因目标能力缺失失败。
- [x] **Step 3：实现账户管理**：名称去首尾空格后校验非空和唯一；余额留空按 0，可编辑，最小类型 standard/credit；仅信用卡允许负初始/当前余额，编辑类型或关联记录后检查全部受影响账户。余额统一按“初始余额 + 收入 - 支出 + 转入 - 转出”派生，首期不维护可漂移的余额缓存列。
- [x] **Step 4：保护关联和同步**：删除二次确认；有账单或转账关联时默认拒删并展示引用数量，可提供显式迁移；迁移检查所有新引用是否合法，不制造同账户转账，在同一事务中迁移成功才删源账户；否则要求先处理关联转账。账户改名不改 ID，相关搜索和展示即时更新；旧数据初始余额为 0 的说明可见。
- [ ] **Step 5：验证**：V-01、V-02、V-03。Expected：初始 100 元、收入 50 元、支出 20 元得到 130 元；改初始为 200 元得到 230 元；账户删除不能留下悬空引用，重启余额一致。

## Task 6：实现收支分类管理与历史关联保护

**Files:**

- Create: `harmony/entry/src/main/ets/service/CategoryService.ets`、`harmony/entry/src/main/ets/pages/CategoryManagePage.ets`、`harmony/entry/src/main/ets/pages/CategoryEditPage.ets`
- Modify: `harmony/entry/src/main/ets/repository/LedgerRepository.ets`、`harmony/entry/src/main/ets/pages/ProfilePage.ets`、`harmony/entry/src/main/ets/state/AppState.ets`
- Create: `harmony/entry/src/test/CategoryRules.test.ets`、`harmony/entry/src/ohosTest/ets/test/CategoryFlow.test.ets`
- Modify: `harmony/scripts/test-domain.cjs`、`harmony/entry/src/test/List.test.ets`、`harmony/entry/src/ohosTest/ets/test/List.test.ets`

**Covers:** REQ-05、REQ-12、REQ-14。  
**Produces:** 按收支类型独立管理分类名称、图标和排序，账单与预算关联不丢失。  
**Depends:** Task 3、Task 4。

- [ ] **Step 1：先编写测试**：同类型同名冲突、不同类型同名、空名称、非法图标、排序重启恢复、改名后历史查询、引用分类删除、迁移目标类型不符及预算引用冲突。
- [ ] **Step 2：确认预期失败**：执行 V-01、V-03 对应测试；Expected：失败指向动态分类/引用保护缺失。
- [x] **Step 3：实现分类服务**：收入/支出独立列表；本地图标白名单，不依赖远程图片；持久化排序；新库可种子化 PRD 示例分类但不生成账单。编辑名称/图标不改变 ID；有关联的分类不允许变更收支类型。
- [ ] **Step 4：同步关联入口**：记账页接动态分类；删除二次确认，有交易或预算引用则拒绝直接删除，支持显式迁移至同类型分类；预算冲突不得静默合并，要求用户先处理或按确认规则操作。最后一个分类可删除，但记账必须显示创建分类入口，不能默认选失效 ID。
- [ ] **Step 5：验证**：V-01、V-02、V-03。Expected：改名后的历史账单仍关联原 ID、统计金额不变；删除/迁移失败不产生部分修改。

## Task 7：完成默认快速记账与账单写入闭环

**Files:**

- Create: `harmony/entry/src/main/ets/service/TransactionService.ets`、`harmony/entry/src/main/ets/components/AmountKeyboard.ets`、`harmony/entry/src/main/ets/components/TransactionForm.ets`
- Modify: `harmony/entry/src/main/ets/pages/RecordPage.ets`、`harmony/entry/src/main/ets/state/AppState.ets`、`harmony/entry/src/main/ets/repository/LedgerRepository.ets`
- Create: `harmony/entry/src/test/TransactionRules.test.ets`、`harmony/entry/src/ohosTest/ets/test/RecordFlow.test.ets`
- Modify: `harmony/scripts/test-domain.cjs`、`harmony/entry/src/test/List.test.ets`、`harmony/entry/src/ohosTest/ets/test/List.test.ets`

**Covers:** REQ-01、REQ-03、REQ-14。  
**Produces:** 冷启动后可直接完成收入/支出记录，写入后所有相关页面使用同一份已提交数据。  
**Depends:** Task 5、Task 6。

- [ ] **Step 1：先编写测试**：整数/小数/退格、空/零/超限金额、缺分类或账户、切换类型清理不匹配分类、补录过去日期和时间、重复点击、写入失败保留输入。
- [ ] **Step 2：确认预期失败**：V-01 与 V-03；Expected：新表单写入/动态引用等用例失败，而非旧页面仍可记账就判定已满足。
- [ ] **Step 3：实现最小表单**：默认支出和当前日期时间，大字号金额、自定义数字键盘、动态分类图标、账户选择、原生日期时间选择、选填备注；无账户引导创建，不假设用户必有“微信”。
- [ ] **Step 4：事务与状态同步**：保存前再次校验实体及类型；保存中禁重复点击，并使用同一次提交的稳定 ID/幂等标识防重复；提交成功清金额/备注并重设下一笔时间，失败保留完整输入。新建与编辑复用服务，编辑保留创建时间，更新修改时间。
- [ ] **Step 5：验证**：V-01、V-02、V-03。Expected：一笔支出只落一条；保存、重启、余额/统计/预算查询一致；无效数据不落库、不提前改余额。

## Task 8：实现分页明细、组合检索及详情编辑删除

**Files:**

- Modify: `harmony/entry/src/main/ets/pages/DetailsPage.ets`、`harmony/entry/src/main/ets/service/TransactionService.ets`、`harmony/entry/src/main/ets/repository/LedgerRepository.ets`
- Create: `harmony/entry/src/main/ets/pages/TransactionDetailPage.ets`、`harmony/entry/src/main/ets/pages/TransactionEditPage.ets`、`harmony/entry/src/main/ets/components/TransactionFilterSheet.ets`、`harmony/entry/src/main/ets/components/DayTransactionGroup.ets`
- Create: `harmony/entry/src/test/TransactionQuery.test.ets`、`harmony/entry/src/ohosTest/ets/test/DetailsFlow.test.ets`
- Modify: `harmony/scripts/test-domain.cjs`、`harmony/entry/src/test/List.test.ets`、`harmony/entry/src/ohosTest/ets/test/List.test.ets`

**Covers:** REQ-06、REQ-07、REQ-14、REQ-15。  
**Produces:** 按日分组的全量可查询账单、完整组合筛选、独立详情及编辑/删除链路。  
**Depends:** Task 7。

- [ ] **Step 1：先编写测试**：关键词命中分类/备注/账户；类型+账户+分类+日期+金额组合；起止日/金额边界、无结果、跨页同一天、相同时间稳定排序；编辑换账户/类型/跨月；删除取消/确认。
- [ ] **Step 2：确认预期失败**：V-01、V-03；Expected：缺失的范围筛选、分组分页或详情用例失败。
- [ ] **Step 3：实现查询与展示**：按日期、时间、ID 倒序游标分页，默认每页 50 条；顶部汇总与日分组汇总基于全部筛选结果，不只累计已加载页；搜索使用参数化查询并转义通配符；重置筛选清空旧游标；金额使用正值范围筛选。
- [ ] **Step 4：实现管理和跳转**：详情包含收支、金额、分类、账户、发生日期时间、备注和创建时间；旧创建时间未知显式标注。编辑复用表单和服务；删除二次确认；编辑换账户需同时使原/新账户及原/新周期缓存失效；预留预算入口，Task 10 接通；接受统计/账户传入的统一筛选参数。
- [ ] **Step 5：验证**：V-01、V-02、V-03。Expected：翻页无丢失/重复，跨页日期不重复拼错；例如 100 元支出改为 80 元时账户余额增加 20 元，改跨月后两个周期统计/预算同步更新；重启后不恢复已删记录。

## Task 9：建立统一范围统计、可交互图表及消费分析

**Files:**

- Modify: `harmony/entry/src/main/ets/pages/StatisticsPage.ets`、`harmony/entry/src/main/ets/repository/LedgerRepository.ets`
- Create: `harmony/entry/src/main/ets/service/StatisticsService.ets`、`harmony/entry/src/main/ets/components/TrendChart.ets`、`harmony/entry/src/main/ets/components/CategoryRingChart.ets`
- Create: `harmony/entry/src/test/StatisticsRules.test.ets`、`harmony/entry/src/ohosTest/ets/test/StatisticsFlow.test.ets`
- Modify: `harmony/scripts/test-domain.cjs`、`harmony/entry/src/test/List.test.ets`、`harmony/entry/src/ohosTest/ets/test/List.test.ets`

**Covers:** REQ-08、REQ-14、REQ-15。  
**Produces:** 默认本月、可切周/月/年/自定义范围的收支概览、趋势、分类占比和消费分析。  
**Depends:** Task 8；D-05。

- [ ] **Step 1：先编写测试**：空周期、单分类、零分母、跨年/闰年/周边界、空日补零、最高分类/最高日期并列、日均、排行稳定性；范围切换迟到结果；图表点击传参。
- [ ] **Step 2：确认预期失败**：执行 V-01、V-03；Expected：新周期聚合与联动断言失败。
- [ ] **Step 3：实现聚合**：同一筛选范围计算收入、支出、结余；收入/支出分别支持日/周/月趋势、分类金额/比例和来源排行；消费分析展示日/月趋势、最高分类、最高日期、日均和排行；只统计普通收支，转账不混入。
- [ ] **Step 4：实现图表与下钻**：原生环形图与趋势图可点击；收入/支出卡片、分类扇区及趋势点传统一筛选到明细；周/月点传对应桶与当前范围的交集。显示金额和文本列表供无障碍读取；按范围和修订号复用聚合，避免每次 build 扫描全量记录。
- [ ] **Step 5：验证**：V-01、V-02、V-03。Expected：所有卡片/图表范围一致；下钻明细总额等于图表；无数据不显示 NaN；切换范围及账单修改后无过期结果。

## Task 10：实现总预算、分类预算及周期使用情况

**Files:**

- Create: `harmony/entry/src/main/ets/service/BudgetService.ets`、`harmony/entry/src/main/ets/pages/BudgetManagePage.ets`、`harmony/entry/src/main/ets/pages/BudgetEditPage.ets`
- Modify: `harmony/entry/src/main/ets/pages/ProfilePage.ets`、`harmony/entry/src/main/ets/pages/DetailsPage.ets`、`harmony/entry/src/main/ets/repository/LedgerRepository.ets`
- Create: `harmony/entry/src/test/BudgetRules.test.ets`、`harmony/entry/src/ohosTest/ets/test/BudgetFlow.test.ets`
- Modify: `harmony/scripts/test-domain.cjs`、`harmony/entry/src/test/List.test.ets`、`harmony/entry/src/ohosTest/ets/test/List.test.ets`

**Covers:** REQ-09、REQ-12、REQ-14。  
**Produces:** 从我的/明细进入预算，支持总/分类、月/周/自定义周期，正确显示使用与超支。  
**Depends:** Task 9；D-05。

- [ ] **Step 1：先编写测试**：零/负预算拒绝、收入分类拒绝、重复/重叠规则、月周边界、跨年、分类迁移、修改/删除/跨期账单、收入/转账排除和超预算情况。
- [ ] **Step 2：确认预期失败**：V-01、V-03；Expected：分类预算或周期规则未实现导致失败。
- [ ] **Step 3：实现预算**：只统计范围内匹配分类的支出；总预算包含全部支出；使用率为使用/预算×100%，剩余可为负，视觉进度条最多填满但真实超支百分比不得截断。总预算和分类预算各自衡量，不能相加当成总支出。
- [ ] **Step 4：同步入口和历史**：明细及我的入口可达；新增、修改、删除预算有明确反馈；分类有预算引用时遵循 Task 6 保护规则；旧单月预算保持原周期/金额，不自动扩展为无限循环预算。
- [ ] **Step 5：验证**：V-01、V-02、V-03。Expected：1000 元预算、1200 元支出显示剩余 -200 元、使用 120%；删除 300 元支出后显示 100 元、90%；收入/转账不改变预算使用量。

## Task 11：实现存款层叠卡片、账户详情和关联明细

**Files:**

- Modify: `harmony/entry/src/main/ets/pages/DepositsPage.ets`、`harmony/entry/src/main/ets/service/AccountService.ets`
- Create: `harmony/entry/src/main/ets/components/AccountCardSwiper.ets`、`harmony/entry/src/main/ets/pages/AccountDetailPage.ets`
- Create: `harmony/entry/src/ohosTest/ets/test/DepositsFlow.test.ets`
- Modify: `harmony/entry/src/ohosTest/ets/test/List.test.ets`

**Covers:** REQ-02、REQ-04、REQ-10、REQ-14、REQ-16。  
**Produces:** 总余额、账户数量、左右切换层叠卡片、最近记录和账户详情。  
**Depends:** Task 8。

- [ ] **Step 1：先编写验收用例**：零/一/多账户、负余额、长名称、账户删除后选中回退、快速左右切换、最近记录与查看全部参数、点击卡片进入详情。
- [ ] **Step 2：确认预期失败**：V-03；Expected：当前无存款页面功能，用例因内容/交互缺失失败；渐变和层叠效果使用截图评审。
- [ ] **Step 3：实现卡片与详情**：深色 `#303030 → #111111` 渐变、大圆角、余额与名称，当前账户居中、左右滑动、前后层叠；不展示/收集卡号、有效期或持卡人。总余额是所有账户当前余额相加，负数不归零。
- [ ] **Step 4：同步账户数据**：详情展示初始余额、当前余额、累计收入、累计支出和最近记录，转入/转出独立展示避免混入收支；查看全部带 accountId 进入明细；编辑/删除复用 Task 5。切换只展示当前账户的数据，迟到查询不得串账。
- [ ] **Step 5：验证**：V-02、V-03；Expected：卡片/详情/账户管理余额一致，左右切换连带更新最近记录与统计；长名称、负数、大字号、小屏及底部安全区不遮挡。

## Task 12：实现独立转账及资金守恒校验

**Files:**

- Create: `harmony/entry/src/main/ets/service/TransferService.ets`、`harmony/entry/src/main/ets/pages/TransferPage.ets`、`harmony/entry/src/main/ets/pages/TransferDetailPage.ets`
- Modify: `harmony/entry/src/main/ets/pages/AccountDetailPage.ets`、`harmony/entry/src/main/ets/repository/LedgerRepository.ets`、`harmony/entry/src/main/ets/state/AppState.ets`
- Create: `harmony/entry/src/test/TransferRules.test.ets`、`harmony/entry/src/ohosTest/ets/test/TransferFlow.test.ets`
- Modify: `harmony/scripts/test-domain.cjs`、`harmony/entry/src/test/List.test.ets`、`harmony/entry/src/ohosTest/ets/test/List.test.ets`

**Covers:** REQ-04、REQ-10、REQ-11、REQ-14。  
**Produces:** 账户详情可发起/查看/编辑/删除转账，资金变化可追溯且不污染收支统计。  
**Depends:** Task 11；D-03。

- [ ] **Step 1：先编写测试**：同账户拒绝、无效账户、非正金额、重复提交、修改金额/源目标、删除、事务失败；信用卡还款；无手续费转账前后总资产守恒。
- [ ] **Step 2：确认预期失败**：V-01、V-03；Expected：缺独立转账写入及余额计算分支导致失败。
- [ ] **Step 3：实现转账服务**：单独持久化一笔转账，账户余额聚合转入转出；同事务校验和写入，不出现仅一侧生效。按 D-03 仅信用卡账户允许净余额为负；创建/编辑/删除转账均检查双方余额，不额外实现授信或透支额度。
- [ ] **Step 4：同步展示与引用保护**：双方账户记录显示转入/转出和对方名称；转账详情编辑/删除需确认；普通收入/支出筛选与预算排除转账。账户迁移/删除同时检查转账引用，不能静默丢失历史。
- [ ] **Step 5：验证**：V-01、V-02、V-03。Expected：A=1000 元、B=200 元，转账 500 元后 A=500、B=700、合计仍 1200 元；收入、支出、预算不变；删除后恢复原余额，写入失败两侧均不变化。

## Task 13：实现 CSV/JSON 数据交换、预览、去重与安全提交

**Files:**

- Create: `harmony/entry/src/main/ets/service/DataExchangeService.ets`、`harmony/entry/src/main/ets/domain/CsvCodec.ets`、`harmony/entry/src/main/ets/domain/ImportValidator.ets`
- Create: `harmony/entry/src/main/ets/pages/ImportPage.ets`、`harmony/entry/src/main/ets/pages/ImportPreviewPage.ets`、`harmony/entry/src/main/ets/pages/ExportPage.ets`
- Modify: `harmony/entry/src/main/ets/service/DataStore.ets`、`harmony/entry/src/main/ets/pages/ProfilePage.ets`、`harmony/entry/src/main/ets/repository/LedgerRepository.ets`
- Create: `harmony/entry/src/test/DataExchange.test.ets`、`harmony/entry/src/ohosTest/ets/test/DataExchangeFlow.test.ets`、`docs/harmony-import-export.md`
- Modify: `harmony/scripts/test-domain.cjs`、`harmony/entry/src/test/List.test.ets`、`harmony/entry/src/ohosTest/ets/test/List.test.ets`

**Covers:** REQ-12、REQ-13、REQ-14、REQ-15。  
**Produces:** 系统选择文件 → 解析校验 → 映射/预览 → 确认导入，以及带范围和格式选择的 CSV/JSON 导出；失败不损坏已有数据。  
**Depends:** Task 8、Task 10、Task 12；D-02、D-04。

- [ ] **Step 1：先编写测试**：UTF-8/BOM、中文、逗号、双引号、换行、空列、缺列、错误日期金额、超大文件、重复 ID/来源记录、同 ID 异内容、同金额时间但确为两笔、缺关联、未知格式版本、取消选择、事务失败及写出失败。
- [ ] **Step 2：确认预期失败**：V-01 的编解码与 V-03 的选择器/数据库测试；Expected：CSV 解析、预览和非破坏性导入能力缺失导致失败。
- [ ] **Step 3：冻结格式并实现导出**：CSV 账单模板含 schemaVersion、id、type、amount（十进制元）、accountId/accountName、categoryId/categoryName、date、time、note、createdAt、updatedAt；文本正确转义，防 Excel 公式注入并记录可逆转义规则。CSV 的账户/分类/预算使用各自表结构文件；多文件逐一选择保存并提示取消/部分完成。JSON 通过独立 format/version 标识，包含账户、分类、账单、预算、转账、关联及批准保留的兼容归档。完整导出与部分导出清晰区分；按时间导出时带上引用实体，注明不是完整迁移集。
- [ ] **Step 4：实现导入与去重**：CSV 首期仅承诺公开模板，不宣称兼容微信/支付宝任意账单；展示行号、错误原因、映射结果、新增/跳过/冲突数量；存在阻断错误时不可确认。有效批次一次事务提交；有 ID 时按 ID 与内容识别，无 ID 时用文件内容标识+源行标识阻止同文件重导，业务字段指纹仅提示疑似重复，不自动吞掉真实同额交易。预览后数据库变化则提交前复验；不调用旧 `importBackup()` 直接覆盖全量数据。旧格式兼容单独走版本适配器，禁止误认 Flutter ZIP/JSON。
- [ ] **Step 5：资源、完整性与验证**：文件大小/行数限制先写进格式文档并在解析前校验；初期可沿用导入文件 64 MB 上限，但必须分批解析/写入、避免主线程整文件处理。历史附件按 D-02 冻结的规则输出并验证引用，缺附件不得宣称完整导出。执行 V-01、V-02、V-03。Expected：完整 JSON 导出到空测试沙箱再导入，实体/金额/关系及归档可比对；再次导入新增 0 条；冲突显式提示；任何失败数据库及现有附件不变；CSV 可用表格工具正确打开中文和多行备注。导出取消、部分多文件完成、写出失败分别提示，不谎报成功。

## Task 14：完成全链路、迁移、性能和设备适配验收

**Files:**

- Create: `harmony/entry/src/ohosTest/ets/test/LedgerE2E.test.ets`、`harmony/entry/src/ohosTest/ets/test/LargeDataset.test.ets`
- Modify: `harmony/entry/src/ohosTest/ets/test/List.test.ets`、`docs/harmony-acceptance.md`、`docs/harmony-development.md`、`docs/harmony-data-contract.md`、`docs/harmony-import-export.md`、`README.md`、`docs/harmony-implementation-plan.md`
- Modify（仅 D-06 核查后确需调整时）: `harmony/entry/src/main/module.json5`、`harmony/entry/src/main/resources/base/profile/backup_config.json`、`harmony/entry/src/main/ets/entrybackupability/EntryBackupAbility.ets`

**Covers:** SUP-01、REQ-01～REQ-16。  
**Produces:** 可安装测试包、真实环境报告、功能/一致性/性能证据及准确交接资料，不将未签名编译产物当成上线包。  
**Depends:** Task 1～13；D-01～D-07 已落定；设备负责人提供满足 D-07 的设备及本机签名。

- [ ] **Step 1：建立端到端验收数据**：从空库创建账户/分类，补录初始余额，记收支，跨账户/跨月编辑，删除，筛选，下钻，预算超支，转账，导出再导入；用独立整数计算器/基准脚本核对每个阶段总额，不只比较两个共用同一错误实现的页面。
- [ ] **Step 2：执行全量验证**：V-01、V-02、V-03，覆盖迁移中断、损坏文件、磁盘写入失败、选择器取消、重复导入、快速重复保存、迟到查询、进程重启。Expected：所有基线及新增测试通过，数据库无悬空引用，重启数据/余额/预算一致。
- [ ] **Step 3：执行专项验收**：按 D-07 数据量和实际确认阈值，分别记录冷启动、保存反馈、筛选首屏耗时及统计查询，至少多次测量并注明机型/OS、样本、计时点和冷暖状态；不能仅写“流畅”。检查小屏、全面屏安全区、软键盘、大字号、长文本、读屏、滑动卡片与图表可点性；核查无不必要权限或第三方账单上传。
- [ ] **Step 4：完成交接与回退说明**：同步 README 的鸿蒙功能说明，保留 Flutter 端旧能力描述并明确平台差异；更新数据版本、导入模板、存储位置、旧数据保留及回退限制。记录构建签名状态、包校验值与安装环境，不提交证书。
- [ ] **Step 5：关闭验收**：核对覆盖矩阵、决策台账和下节完成标准，记录未完成项负责人及解除条件。Expected：只有全部范围通过且证据可定位才将状态改为 Verified；缺设备/性能或业务确认仍保持 Draft/Implementing，不发布未授权包。

---

## 4. 需求/问题覆盖矩阵

PRD 未提供稳定需求编号，本文建立下列编号；后续测试名/验收记录引用这些编号。每个 `AC-*` 是验收组编号，Task 1 在 `docs/harmony-acceptance.md` 展开步骤、数据及证据位置。

| 需求/问题 | 来源与范围 | 解决任务 | 验收依据 |
| --- | --- | --- | --- |
| SUP-01 工程可复现与交付追踪 | 实施支撑目标、现有工程环境 | Task 1、Task 14 | AC-00：环境/决策/报告可复现 |
| REQ-01 五入口及默认记账 | PRD 2、8.1、11 | Task 4、Task 7、Task 14 | AC-01：冷启动索引 2，顺序正确 |
| REQ-02 金融视觉规范 | PRD 3、4.4 | Task 4、Task 11、Task 14 | AC-02：色板、悬浮导航、渐变层叠卡片截图 |
| REQ-03 快速收支记账 | PRD 4.3、5.1、5.5 | Task 2、Task 7、Task 14 | AC-03：金额/分类/账户/时间校验与重复保存测试 |
| REQ-04 自定义账户/初始余额 | PRD 4.4 G、4.5 A、10.2～10.3 | Task 2、Task 3、Task 5、Task 11、Task 12、Task 14 | AC-04：空值为 0、补录、改名、引用保护、余额基准 |
| REQ-05 分类管理 | PRD 4.3、4.5 B、5.4 | Task 2、Task 3、Task 6、Task 14 | AC-05：图标、排序、改名及关联迁移 |
| REQ-06 明细查询和分组 | PRD 4.2 A～C、8.3 | Task 8、Task 14 | AC-06：搜索三字段、组合条件、分页和全范围汇总 |
| REQ-07 账单详情/编辑/删除 | PRD 4.2 D～F、5.4 | Task 8、Task 14 | AC-07：详情字段、跨账户/跨月编辑与二次确认 |
| REQ-08 收支统计及消费分析 | PRD 4.1 | Task 2、Task 9、Task 14 | AC-08：统一周期、日周月趋势、占比、消费分析及下钻 |
| REQ-09 总预算/分类预算 | PRD 4.2 G、4.5 C、5.3 | Task 2、Task 10、Task 14 | AC-09：周期/范围、超支率、修改删除后的重新计算 |
| REQ-10 存款与账户详情 | PRD 4.4、8.2 | Task 11、Task 12、Task 14 | AC-10：总余额、卡片切换、近期记录、查看全部 |
| REQ-11 独立转账 | PRD 5.2、10.1 | Task 2、Task 12、Task 14 | AC-11：余额守恒、统计/预算排除、还款不重复支出 |
| REQ-12 我的管理入口 | PRD 4.5 | Task 4、Task 5、Task 6、Task 10、Task 13、Task 14 | AC-12：账户/分类/预算/导入/导出入口可达，无额外设置 |
| REQ-13 数据导入/导出 | PRD 4.5 D～E、6.3、8.4 | Task 13、Task 14 | AC-13：预览、异常、去重、格式范围、JSON 完整关系 |
| REQ-14 数据一致性与安全 | PRD 5、6、7.2、11 | Task 2、Task 3、Task 5～13、Task 14 | AC-14：事务失败保护、稳定 ID、重启、余额与预算基准 |
| REQ-15 本地存储与性能 | PRD 6、7.1 | Task 1～4、Task 8、Task 9、Task 13、Task 14 | AC-15：离线运行、迁移、分页、D-07 性能报告 |
| REQ-16 HarmonyOS 适配/易用性 | PRD 7.3～7.4，本期仅鸿蒙 | Task 1、Task 4、Task 11、Task 14 | AC-16：设备矩阵、安全区、字号、键盘及无障碍 |

### 明确延期或排除的事项

- **延期**：Android/iOS 新 PRD 改造、Flutter 与鸿蒙的数据互通、任意第三方账单模板兼容。JSON 导出不代表已支持跨端导入。
- **按 PRD 排除**：注册/登录、云同步、多账本、社交、隐私/外观/其他设置页、独立备份恢复模块、银行卡绑定与自动同步。
- **现有功能退场须保护数据**：日记、主题、字体设置及消费凭证新增能力不是本 PRD 必做功能；旧数据/附件的保留与导出以 D-02 为准，不因移除入口而删除。
- **不扩展金融业务**：多币种、手续费、信用卡账单日/还款日/额度、复杂资产负债类型及自动计息不纳入本期；仅新增用户明确要求的普通/信用卡最小类型，信用卡类型不由账户名称决定。

## 5. 功能完成标准

- [ ] AC-00：已确认决策有记录；V-01～V-03 实际结果、代码版本和环境可追踪；无来源任务及文档断链已清理。
- [ ] AC-01～AC-03：冷启动进入记账；导航五入口顺序正确；可完成收入/支出，非法金额或缺引用不可保存；连续点击不重复落单。
- [ ] AC-04～AC-05：账户/分类可增删改，初始余额空值/补录正确，图标排序可重启恢复；改名不丢历史，删除不能产生悬空引用。
- [ ] AC-06～AC-07：分组列表、完整组合筛选、关键词、分页、详情、编辑删除全部通过；顶部/每日汇总基于全量筛选，非当前页。
- [ ] AC-08：周/月/年/自定义范围和日周月趋势口径一致；分类占比、消费分析及点击下钻与对应明细金额相等。
- [ ] AC-09：总/分类预算、月/周/自定义周期正确；超支负剩余、真实使用率、收支修改后的结果通过独立金额核对。
- [ ] AC-10～AC-11：存款卡片/账户详情和近期账单正确；转账双方余额、总资产守恒、还款和统计/预算排除均有测试证据。
- [ ] AC-12～AC-13：我的管理入口可达；CSV 导入支持公开模板、预览、异常和重复检测；JSON 完整导出能在空测试沙箱保留全部关联；未知版本拒绝，取消/失败原数据不变。
- [ ] AC-14：所有写入事务提交后才更新 UI；跨账户/跨期编辑刷新两侧；重复提交、迟到响应、磁盘失败、重启及迁移中断经过验证。
- [ ] AC-15：无需登录可离线使用，不上传个人账单；旧数据安全迁移且归档可定位；D-07 确认的容量及性能指标均有真实测试结果。
- [ ] AC-02、AC-16：确认设备矩阵内无导航/键盘遮挡；大字号、小屏、负余额、长文本与图表交互/读屏验收通过。
- [ ] 构建、单元测试、平台集成和设备安装分别有证据；系统备份策略符合 D-06；不将 Node 断言或未签名 HAP 当成真机验收。
- [ ] 数据契约、导入模板、开发说明、平台差异和回退限制同步，未提交隐私数据、密钥和本机签名文件。
- [ ] 所有未完成/阻断项如实登记；全项满足且证据齐备后，文档整体才可标记为 `Verified`。

## 6. 建议实施批次

| 批次 | 任务范围 | 交付目标 | 验证与回退边界 |
| --- | --- | --- | --- |
| A：基础 | Task 1～3 | 决策、测试基线、实体与迁移基础 | 通过规则和迁移测试；失败保留旧文件，不进入新库写入 |
| B：核心记账 | Task 4～8 | 默认记账、账户/分类、明细管理闭环 | 五页先有骨架，未接功能不得计完成；核心流通过 V-01～V-03；不回删已迁移数据 |
| C：统计预算 | Task 9～10 | 周期统计、图表、总/分类预算 | 范围/下钻/超支/跨期编辑一致；可撤 UI 入口，不破坏已保存预算 |
| D：账户体验 | Task 11～12，可与 C 并行 | 存款层叠卡片、详情、独立转账 | 卡片交互及资金守恒验证；转账模型不退化成收支替代 |
| E：数据交换 | Task 13，须 C/D 完成后集成 | CSV/JSON 契约、预览、去重及导出 | 完整往返/失败回滚/重复导入通过；不提供未批准的替换恢复按钮 |
| F：最终交付 | Task 14 | 安装包、设备/性能报告和交接 | 所有 AC 及决策关闭；发布/提交需另行授权；无设备则保持 blocked |

批次 B 对应 PRD 第一阶段；批次 C 对应第二阶段；批次 D/E 对应第三阶段。五入口的架构提前建立，但不改变阶段功能验收边界。

## 7. 交付与验收记录

### 7.1 当前实际记录

| 任务/批次 | 验证环境与版本 | 命令/验收方法 | 实际结果 | 证据 | 遗留项 |
| --- | --- | --- | --- | --- | --- |
| 初版文档 | 仓库 HEAD `ce51113`，现有工作区 | 静态检查 | 已形成 Draft 实施计划；初版未执行测试 | 本文 | 历史记录 |
| Task 1 / V-01 | DevEco Node `v24.14.1` | 领域测试命令 | PASS，8 项测试 | `docs/harmony-acceptance.md` | 非平台测试 |
| Task 1 / V-02 | SDK `26.0.0.105`、Hvigor `6.26.9` | 增量 assembleHap | PASS，退出码 0；未签名 | `docs/harmony-acceptance.md` | 未验证设备安装 |
| Task 1 / V-03 | HDC 无在线设备，无签名配置 | hdc list targets | 环境探测 `[Empty]`；设备测试 blocked | `docs/harmony-decisions.md` | 设备负责人提供设备及签名 |
| Task 2 / V-01～V-02 | 同 Task 1 工具链 | 扩展领域测试与 assembleHap | 结果见验收记录 | `docs/harmony-acceptance.md` | 尚未接入页面/持久层 |
| Task 3～14 | 未实施 | 待决策/设备后按任务推进 | 未执行 | 无 | 剩余决策状态见台账 |

### 7.2 后续逐任务记录要求

Task 1 创建的 `docs/harmony-acceptance.md` 按 Task/AC 编号逐条记录：代码版本、机型/OS、数据版本、执行命令或操作、预期结果、实际结果、报告/截图路径、执行人和日期、遗留项与负责人。失败用例修复后保留前后证据；`todo / in_progress / blocked / done` 不混用，只有满足本任务验收条件才可写 `done`。

**目前已执行 Task 1 基线和 Task 2 隔离领域契约；页面功能、迁移及设备验收尚未完成，日记页面实际移除在 Task 4 执行。**
