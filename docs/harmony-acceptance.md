# HarmonyOS 实施验收记录

> 建立日期：2026-11-17  
> 计划：`docs/harmony-implementation-plan.md`  
> 决策与环境：`docs/harmony-decisions.md`  
> 状态：Task 1 基线已验证；新增业务未实施，平台验收 blocked。

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

- D-01～D-07：需求方/实施负责人按决策记录提供确认；Task 1 只登记和评审依赖，不代替批准。
- V-03：设备负责人提供兼容设备、有效本机签名；在此之前不能执行数据库平台探针、文件选择器或 UI 集成测试。
- Task 2～14：未实施；仅允许先做不依赖未决规则的隔离部分，不能跨闸门完成验收。
