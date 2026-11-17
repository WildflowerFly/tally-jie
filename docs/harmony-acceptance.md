# HarmonyOS 实施验收记录

> 建立日期：2026-11-17  
> 计划：`docs/harmony-implementation-plan.md`  
> 决策与环境：`docs/harmony-decisions.md`  
> 状态：Task 1 基线、Task 2 隔离领域契约已验证；新页面及持久层未实施，平台验收 blocked。

## 1. Task 1 基线结果

代码基线 `ce51113`，执行日期 2026-11-17。执行环境为 Windows DevEco 工具链，工程目录 `harmony/`。SDK 包为 HarmonyOS `26.0.0.105`（API 26、platform `26.0.0`，Release），工程 compatible `6.1.1(24)`。工具版本见决策记录。没有修改 SDK、应用数据或签名配置。

| 编号 | 操作/命令（工作目录 harmony/） | 实际结果 | 证据 | 遗留 |
| --- | --- | --- | --- | --- |
| V-01 | DevEco Node 执行 `scripts/test-domain.cjs`，参数为 DevEco 内置 `typescript.js` | PASS，8 个测试通过 | 下列测试清单及运行器汇总 `8 domain tests passed.` | 只验证平台无关领域逻辑 |
| V-02 | DevEco Node 执行 `hvigorw.js --mode module -p product=default -p module=entry@default assembleHap --no-daemon` | PASS，退出码 0；`BUILD SUCCESSFUL in 21 s 412 ms`；33 tasks，16 executed、17 up-to-date | 未签名 HAP 路径及 SHA-256 见下 | 增量构建非全量重编译；不代表设备通过 |
| V-03 环境探测 | SDK `hdc.exe list targets` | `[Empty]`，无在线设备 | 本轮 HDC 输出 | blocked，设备负责人提供设备/模拟器及本机签名后执行 |
| 文档/结构 | 检查 Task 1 文件、决策编号、步骤、验收组和相对链接 | Task 1 收尾时检查 | 提交前静态检查结果 | 不涉及业务能力验收 |

V-01 测试：

1. `moneyUsesIntegerCents`
2. `rejectsInvalidAmounts`
3. `validatesCalendarDates`
4. `monthlyTotalsRespectTypeAndMonth`
5. `categoryTotalsSortByAmount`
6. `rejectsMalformedBackupData`
7. `rejectsDuplicateIdsAndBudgets`
8. `roundTripsAllRecords`

V-02 产物：`harmony/entry/build/default/outputs/default/entry-default-unsigned.hap`。

SHA-256：`088694ec0dfc37f78e010ebfec0db0afdd61c4b7c43932cd1daa391afd730215`。

构建警告：`Will skip sign 'hos_hap'. No signingConfigs profile is configured in current project.` 未签名包只作基线证据，不承诺可直接安装，不提交生成产物。

运行复现：按实施计划 V-01/V-02 设置会话中的 DevEco 安装目录、`JAVA_HOME` 和 `DEVECO_SDK_HOME` 后执行；路径不会写入公共构建配置。工具桥接曾遇到命令变量被外层 shell 展开的问题，已改为 PowerShell UTF-16LE EncodedCommand 调用后成功；该错误不计为领域失败测试或构建失败。

## 2. 设备验收用例目录

以下为待执行用例，不是通过记录。共同前置：兼容设备及本机签名已准备；仅使用测试沙箱；记录机型、OS、代码版本及 schema 版本。每次执行记录操作、Expected、Actual、报告/截图、执行人、日期和遗留项。

| 组 | 操作/测试数据 | Expected | 状态 |
| --- | --- | --- | --- |
| AC-00 | 按 V-01/V-02 复现环境；核对决策状态 | 测试/构建可复现，未决项不伪装批准 | 基线 PASS；产品决策 pending |
| AC-01 | 杀进程后冷启动，依次点五入口 | 默认记账，顺序统计/明细/记账/存款/我的 | todo |
| AC-02 | 截图五页与存款卡片，滑动多账户 | PRD 色板、悬浮导航、渐变层叠卡片一致 | todo |
| AC-03 | 输入空、0、0.10、三位小数和上限；重复点保存 | 非法值拒绝，合法值精确到分，提交只生成一笔 | todo |
| AC-04 | 初始100元、收入50元、支出20元，再补录初始200元；删除有关联账户 | 余额130→230元，有引用不直接删 | todo |
| AC-05 | 创建/改名分类、修改图标排序，重启；删除引用分类 | ID/历史不变，排序恢复，引用受保护 | todo |
| AC-06 | 跨日数据，组合类型/账户/分类/日期/金额/关键词并翻页 | 无重复漏单，汇总是全范围非单页 | todo |
| AC-07 | 100元支出改80元，换账户/跨月，再取消和确认删除 | 余额增加20元，两侧周期均更新；取消不改数据 | todo |
| AC-08 | 空周期、跨年周、闰月、分类扇区和趋势点点击 | 图表与同范围明细金额相等，无NaN | todo |
| AC-09 | 预算1000元、支出1200元，再删除300元支出 | 剩余-200/使用120%，随后100/90%；排除收入转账 | todo |
| AC-10 | 零/一/多账户及负余额，左右切换，查看全部 | 总余额精确，最近记录不串账，accountId正确 | todo |
| AC-11 | A1000、B200，转账500，编辑和删除 | A500/B700/合计1200；收入支出预算不变 | todo |
| AC-12 | 从我的进入账户/分类/预算/导入/导出 | 全部可达，无非范围设置页 | todo |
| AC-13 | 中文带引号/换行CSV；JSON空沙箱往返、重导、冲突、取消、写入故障 | 正确解析/预览/去重，冲突可见，失败原数据不变 | todo |
| AC-14 | 跨账户编辑、并发点击、迟到响应、迁移中断、损坏文件和重启 | 事务一致，无悬空关联，不清空损坏文件 | todo |
| AC-15 | 离线操作；D-07容量数据及性能计时 | 不上传，分页正确，达到批准指标 | blocked：D-07待确认 |
| AC-16 | 小屏/全面屏、键盘、大字号、长名称、读屏 | 无遮挡，可操作且语义可读 | blocked：设备矩阵未提供 |

## 3. 旧数据测试夹具生成与隐私

- 使用旧 `emptyData()`、`Transaction/Diary/Budget` 类型和 `validateData()` 构造合成 v1 样本，不读取真实账单/日记。
- 合法组：空数据；跨月收支；收入/支出同名“其他”；固定账户；中文、多行备注；同日多篇日记；月预算；0/1/9张合成图片引用。
- 异常组：未知版本、损坏JSON、重复ID/预算、非法日期金额、路径穿越、缺附件。故障注入只写入测试沙箱。
- 图片使用不含个人信息的测试像素图，记录名称、大小、SHA-256；迁移比对记录数量、ID、逐笔金额、汇总及附件校验值。
- 具体夹具及迁移测试由 Task 3 创建；这里仅完成生成方法，不宣称已生成或已迁移。

## 4. 遗留与责任

- 决策更新：本轮用户确认日记功能删除、仅信用卡可负、周一及自然月/周、历史余额0并提示补录、性能仅候选；其余细项按决策台账继续跟踪，不把部分确认扩展为全部批准。
- V-03：设备负责人提供兼容设备、有效本机签名；在此之前不能执行数据库平台探针、文件选择器或 UI 集成测试。
- Task 2：隔离领域契约已完成；Task 3～14：未实施，不能跨闸门完成验收。

## 5. Task 2：领域契约与规则

执行日期2026-11-17，父提交 `5530072`，工具链沿用 Task 1。本次无需平台 API，未写入用户文件。新增 `LedgerModels/Money/DateRange/LedgerRules` 和数据契约文档；v1 类型及旧页面行为不变。仅信用卡可负的规则已在 v2 领域层实现，尚未接到旧页面。

| 阶段 | 命令/检查 | 实际结果 |
| --- | --- | --- |
| 测试先行 | V-01，带可加载的测试桩 | 旧8项通过；`decimalAmountsAreIntegerCents` 报 `AssertionError [ERR_ASSERTION]`，`0 !== 30`，退出码1；不是模块加载失败 |
| 实现后 | V-01 | 发现一例测试把 credit 账户误当普通账户，按普通账户场景修正 type 后通过；随后补充删除收入/转入、附件/时间戳测试 |
| 编译覆盖校正 | V-02 | 初次未引用的新模块不作为已编译证据；通过 AppData 显式重导出纳入实际应用依赖 |
| ArkTS修复 | V-02 | `Structural typing is not supported (arkts-no-structural-typing)`，`LedgerRules.ets` 原96行：直接将 BudgetRule 传给 DateRange；改为显式构造日期范围后复验 |
| 最终领域测试 | V-01 | **21 domain tests passed.**，原8项+新增13项，退出码0 |
| 最终应用构建 | V-02，assembleHap --no-daemon | **BUILD SUCCESSFUL in 7 s 224 ms**，33 tasks：17 executed/16 up-to-date；退出码0 |
| 静态检查 | git diff --check、Task2步骤/文档链接检查 | PASS |
| 平台/设备 | V-03 | 未执行，环境仍 blocked；没有把 Node 测试当作设备测试 |

新增13项：`decimalAmountsAreIntegerCents`、`rejectsInvalidAmountSyntaxAndOverflow`、`onlyCreditInitialBalanceMayBeNegative`、`calendarDatesAndMondayWeekAreStable`、`balancesTransfersAndRenameUseStableIds`、`rejectsReferencesDuplicatesAndCategoryMismatch`、`negativeStandardBalanceIsRejectedAfterEveryMutation`、`removingIncomeOrIncomingTransferCannotOverdrawStandardAccount`、`entityIdentityAndHistoricalAttachmentsArePreserved`、`transferAndBalanceOverflowAreRejected`、`budgetPeriodShapeIsCheckedWithoutFreezingPendingOverlapPolicy`、`legacyInitialZeroRequiresExplicitPromptAndDoesNotBypassBalanceRule`、`filterRangeCursorAndAmountsAreValidated`。

遗留警告：旧 DataStore/Index 的 `Function may throw exceptions. Special handling is required.` 仍存在；未签名警告仍存在。测试注册已同步 Hypium List，但本次只运行 Node 适配器，未执行 IDE Hypium 目标。产物为未签名 HAP，不提交生成文件。

迁移风险已记录：初始余额0与普通账户不得负不能互相绕过。历史净支出账户须保留旧文件并等待用户补录，Task 3/5 设计恢复阶段，不伪造收入也不自动改信用卡类型。预算重叠/自动复用、日均分母、导入归档策略及性能阈值仍未冻结。

## 6. Task 3：持久层与迁移（实现完成，平台验收 blocked）

2026-11-17：新增版本化 relationalStore schema、事务仓储（revision 乐观锁、串行操作、失败回滚）、纯迁移转换和平台迁移服务。旧 JSON/图片原地保留，迁移元数据记录 SHA256、位置和数量；新库与完成标记同事务提交。历史普通账户为负时只返回补录草稿，不写入数据库。首次无旧文件建立空账本，不插演示流水。

- V-01：**25 domain tests passed**；新增4项迁移测试，覆盖稳定映射、补录、信用卡、日记隔离、坏数据和未知版本。曾出现无效日记夹具，修正合法心情/天气后通过。
- V-02：修复 ArkTS catch 重抛需 `as Error` 及显式快照类型后，**BUILD SUCCESSFUL in 7 s 560 ms**，退出码0。
- V-03：新增并注册 Persistence/DatabaseMigration 平台测试（回滚注入、过期写拒绝、外键、重开库、迁移标记原子性/幂等）。**尚未运行**，无法声称平台测试先失败后通过；未签名、无连接设备的限制仍在。
- Task3 Step1 尚缺磁盘不足/文件服务全链路等完整设备覆盖；Step2/5 未勾选。Step3/4 仅表示代码实现完成，不表示完成真机迁移验收。新入口接入由 Task4 执行，旧 UI 本提交仍使用旧服务。
- 当前仓储使用全快照替换事务，索引已建；万条数据吞吐尚未测量，不宣称达到候选性能线。SHA256 能力不可用会阻止迁移，不删除原件。

## 7. Task 4：五页导航与统一状态（实现完成，设备验收 blocked）

- 先创建 `Navigation.test.ets`，再替换旧四页 Index；自动用例检查默认记账、五按钮左右顺序、切换“我的”后返回。设备不可用，未报告预期失败或运行通过。
- 完整人工用例：①清空测试应用数据冷启动默认记账；②五入口顺序统计/明细/记账/存款/我的，连点切换不写入；③输入金额/备注后切换提示，保留切换再返回文本不丢；④系统返回先确认，不直接丢输入；⑤损坏旧文件载入报错且不能保存；⑥慢加载时快速切页仍停留最后选择；⑦小屏/大字号/键盘/安全区检查滚动与导航；⑧迁移遇普通账户负余额显示补录，失败保留旧文件和输入；⑨模拟保存失败，旧快照不刷新，成功后 refreshVersion 才递增。以上均尚未设备执行。
- 新增 `AppState` 作为唯一数据库所有者，载入与保存错误可见；提交成功统一替换快照/递增刷新版本，失败不乐观刷新。页面不自行保存，切页不载入数据库；世代号阻止旧载入结果覆盖新状态。
- 移除日记和外观设置活跃 UI；旧 JSON/图片保留给迁移服务。导航默认2，配色、卡片与黑色悬浮栏独立组件；表单金额/备注输入由根状态保留。账户分类及记账服务尚未接入，保存明确禁用，无假账单。
- V-01：25项领域测试通过。V-02：应用 assembleHap 成功，退出码0。新增测试目标也通过 `--mode module -p product=default -p module=entry@ohosTest assembleHap --no-daemon`，**BUILD SUCCESSFUL in 9 s 129 ms**，35任务全部执行，退出码0；这仅证明平台测试可编译，不证明执行通过。
- EntryAbility 审查后沿用原有 pages/Index 与强制浅色模式，不为满足文件清单做无意义改动。
- Step1/3/4 勾选；Step2/5 仍 blocked。D-01 外键/事务实际能力尚未设备验证，Task5起依赖持久层的完整集成验收不能越过该门禁。需可运行 Harmony SDK26 测试应用的模拟器/真机及签名；2026-11-17 用户授权后续细节自行判断，设备待办不再阻断纯规则及界面开发，发布/验收仍受此限制。

## 8. Task 5：账户管理

- 已实现账户新增/编辑、留空初始余额0、信用卡类型、历史补录标记、余额派生、引用计数、删除确认与显式历史迁移；入口“我的 → 账户管理”。名称trim后1～40字、区分大小写精确唯一。
- 自行决策：删除迁移只移动历史引用，不合并源初始余额，确认弹窗明确提示；遇双方直接转账形成同账户则整次拒绝；普通目标余额不足同样拒绝。无乐观UI写入，事务成功后才刷新。
- 测试先行：空实现导致 `Cannot read properties of undefined (reading 'name')`，退出码1，服务模块已加载，明确为缺失账户行为。实现后 **29 domain tests passed**（新增4项）；应用 **BUILD SUCCESSFUL in 7 s 234 ms**，退出码0；修复Select选项需显式SelectOption类型。
- 用例覆盖名称、空/负初始余额、信用卡、改名稳定ID、100+50-20=130、改初始200后230、引用拒删/迁移、自转账风险、原快照不变及补录。账户重启/写失败UI等设备用例未执行；Step1/2/5保持未全选，Step3/4为代码完成。

## 9. Task 6：动态分类管理

- 已实现收支独立分类、同类型名称唯一、本地图标键白名单及文字图标、持久化排序、编辑稳定ID、引用删除保护、同类型历史迁移；入口“我的 → 分类管理”。最后一个分类允许删除，不自动制造替代分类；记账联动将在Task7接入，因此Step4暂不勾选。
- 自行决策：同一分类范围任何日期交叠预算均拒绝迁移，不自动合并预算；名称trim后1～30字，排序为非负安全整数，排序相同按ID稳定排列。新空库不预置演示数据，提供创建入口。
- 测试先行空实现：分类数量 `0 !== 3`，退出码1。实现后 **32 domain tests passed**（新增3项）；应用 **BUILD SUCCESSFUL in 8 s 329 ms**，退出码0。
- 覆盖不同类型同名、非法名称/图标/排序、历史改名稳定ID、交易/预算引用、类型变更拒绝、迁移预算冲突和最后分类删除。Step3勾选；设备排序重启、删除取消及UI反馈未执行，Step1/2/5未全选。

## 10. Task 7：快速记账

- 已接动态账户、按类型排序的分类、金额/备注、数字键盘、原生日期时间选择；默认支出及当前日期时间，无账户/分类可直达创建入口。记账组件切页隐藏不销毁，完整选择与输入保留。
- `saveEntry` 新建/编辑复用，正整数分金额校验、引用/类型校验、所有账户最终余额检查；稳定提交ID防重，保存期间禁止再次提交；成功才清空金额/备注并重设时间与ID，失败保留。历史创建时间及附件引用编辑时保留。
- 测试先行：键盘空串加小数点，实际 `''` 预期 `'0.'`，退出码1；实现后 **35 domain tests passed**（新增3项）；应用 **BUILD SUCCESSFUL in 8 s 58 ms**，退出码0。覆盖小数/退格/上限、稳定ID重试、历史时间保留、无效日期时间/账户/类型/超支拒绝。
- Task6 Step4动态入口联动现已完成，Task7 Step3/4勾选；设备重复点击、失败保留输入、重启一致性仍待实测，Step1/2/5不全选。

## 11. Task 8：分页明细与编辑删除

- 已实现默认50条、日期/时间/ID倒序独占游标、组合筛选、字面关键词、完整结果/每日汇总、详情创建时间、编辑及删除确认。复用统一事务服务，失败不丢表单，成功重置游标；支持外部统一筛选。
- TDD 首次失败 ，退出1；实现后 **37 domain tests passed**；应用 **BUILD SUCCESSFUL in 8 s 251 ms**（后续统一筛选小改会随Task9复验）。103条同时间记录分页50/50/3无重复、全筛选汇总及边界匹配通过。
- 实施调整：详情/编辑暂内聚于DetailsPage，查询用已加载快照内存过滤，不拼接SQL，通配符无特殊含义；尚未实现数据库游标分页和索引查询，不能声称满足大数据性能目标。Task8各step含尚未验证的SQL/设备/跨页跳转条件，保持未全选；当前是功能交付而非完整验收。
