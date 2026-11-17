# HarmonyOS v2 账本数据契约

> Task 2，2026-11-17；模型：`harmony/entry/src/main/ets/model/LedgerModels.ets`。当前为隔离领域实现，尚未接入页面或替换 v1 文件。

## 1. 已确认规则与未决边界

用户本轮确认：删除 Harmony 日记页面及功能；**仅信用卡类账户允许负余额**；周一为周首，预算使用自然月/自然周；历史初始余额 0 并提示补录；性能值仅候选。此明确修订优先于原 PRD 不设账户类型的描述。

- 账户最小类型：`standard` 普通、`credit` 信用卡；类型与名称解耦，改名不改变类型/ID。不引入账单日、利率、授信额度或自动还款。
- 未批准的日记历史数据物理清理不实施；旧类型仅为兼容输入，不保留活跃日记页面。旧导出归档政策仍待确认。
- 预算重叠、日均统计分母及自动跨期复用未确认，本任务不实现这些策略；周期函数与范围天数不等于已确定统计平均算法。
- 存储选型/平台探针、导入合并策略和系统备份政策不是本任务的完成项。

## 2. 公共约定

- `LedgerData.version = 2`。六组集合：accounts/categories/entries/transfers/budgets/attachments；无 diary/settings 活跃实体。`emptyLedger()` 不生成演示数据。
- 每张实体表 `id` 非空、表内唯一、创建后不变。允许不同表相同 ID；禁止依赖名称作外键。ID 由写入服务生成并在持久层唯一约束兜底，领域验证不自动重写 ID。
- 金额为安全整数分，单笔交易/转账/预算 `1..99999999999`，初始余额绝对值不超过同一上限。账户累计可超过单笔上限，但必须在 `Number.MAX_SAFE_INTEGER` 内，每次加法经 `addCents` 校验，不能在数据库/JS 间丢精度。
- 文本金额严格十进制，无前后空白、前导加号、科学计数、逗号或超过两位小数；初始余额留空为 0；普通账户负初始/当前余额一律拒绝，信用卡允许负初始/当前余额。`-0` 归一到 0。
- 日期 `YYYY-MM-DD`（0001～9999 年，真实日历日）；时间 `HH:mm`。交易日期为设备本地民用日期，不把它转成 UTC 业务日。日期运算内部使用 UTC 防止 DST 导致天数误差。
- 范围 `startDate/endDate` **两端包含**；持久层可换算成 `[开始日, 结束日下一天)` 时间查询，但不能把对外 endDate 当排除边界。周一到周日，月首到月末；闰日/跨年适用。无法表示的范围（例如跨到 0000 年）报错，不截断。
- `createdAt: string | null`、`updatedAt: string` 为 UTC ISO 毫秒时间戳；新建服务记录真实时间，历史未知创建时间为 null，显示“历史数据未记录”；历史 updatedAt 记录迁移时刻，不伪造旧创建时间。
- `validateLedger` 输入是已解析的强类型候选快照，非任意 JSON 的运行时结构解析器。Task 13 必须先检查文件结构/字段类型，不能 `JSON.parse(...) as LedgerData` 后直接信任。

## 3. 实体字段

| 实体 | 字段及约束 |
| --- | --- |
| Account | id/name/type/initialBalanceCents/needsInitialBalance/createdAt/updatedAt；名称非空；`needsInitialBalance` 是迁移提示标记，不放宽余额校验 |
| Category | id/type(income或expense)/name/iconKey/sortOrder/createdAt/updatedAt；sortOrder 为非负安全整数；同名收支“其他”是两个不同 ID；不在本层猜测名称唯一策略 |
| LedgerEntry | id/type/amountCents/accountId/categoryId/date/time/note/attachmentIds/createdAt/updatedAt；账户与分类存在，分类类型匹配；金额恒正，方向由 type 决定 |
| Transfer | id/fromAccountId/toAccountId/amountCents/date/time/note/createdAt/updatedAt；两账户存在且不同；不另造两笔收支，不进入统计和预算 |
| BudgetRule | id/scope(total或category)/categoryId/amountCents/period(month或week或custom)/startDate/endDate/createdAt/updatedAt；total 的 categoryId 必须 null；category 指向支出分类；月/周边界须为完整自然周期；custom 保留 PRD 自定义范围契约 |
| LegacyAttachment | id/relativePath；仅旧账单附件关联，限定 `images/img_[A-Za-z0-9_-]+.jpg`，禁止绝对路径/路径穿越；每账单最多9项，无重复、无悬空引用；不新增照片管理功能 |

本层验证的是预算**周期实例范围**。未来如果产品确认自动复用，Task 10 另建循环定义/实例展开规则，不将一段固定日期暗中视为无限循环。

## 4. 余额与写入边界

`balance = initialBalanceCents + income - expense + transferIn - transferOut`。

- `accountBalance(data, accountId)` 只计算指定账户；`validateLedger(data)` 校验所有账户最终余额。拒绝普通账户负值，信用卡可负。校验最终快照，不逐笔重放时强行要求历史每一天都非负。
- 创建/编辑/删除收支或转账、删除/迁移账户、补录初始余额、改变账户类型、导入都必须在**同一写事务**中对候选状态校验再提交；校验失败旧状态不变。不能只检查“支出”和“转出”，删除收入或转入也可能透支。
- 改名不改变 ID 和历史关联。`assertAccountRemovable` 拒绝有收支/任一转账端引用的账户；`assertCategoryRemovable` 拒绝有收支/预算引用的分类。不存在报 REFERENCE_NOT_FOUND。合并迁移须检查自转账、分类类型并再次验证整库。
- 历史初始余额统一 0，`needsInitialBalance=true`；普通账户历史净额若负，**不能静默丢单、补造收入、自动变信用卡，或因提示标记绕过限制**。Task 3 需设计“旧文件保留、待补录且禁止常规写入”的恢复阶段，补录使候选状态合法后才完成切换。该阶段 UI/事务验收尚未实现，不能声称旧数据已迁移成功。

## 5. 查询契约

`LedgerFilter`：type(null表示全部)、accountIds/categoryIds（空数组不限，数组内 OR）、range(null不限)、minAmountCents/maxAmountCents（null不限）、keyword、cursor、pageSize；不同维度 AND。金额两端包含，关键词对分类名/账户名/备注匹配，具体模糊匹配与规范化在 Task 8 实现。

- 稳定排序 `(date DESC, time DESC, id DESC)`，游标为最后一条三元组，后续页严格小于游标；ID 比较使用稳定二进制/字典序，不能用本地语言排序。
- 50 条仅默认候选页大小，校验范围 1～200 为资源保护，不代表性能已验收。
- 汇总针对全筛选范围而非当前页；余额来源完整账本而非筛选片段。统计和预算不混入 transfers。
- 本任务仅定义/验证过滤对象，不声称分页查询和图表服务已经实现。

## 6. 错误码

`LedgerError` 携带稳定 code，message=code，不泄露备注/附件正文。

| code | 含义 |
| --- | --- |
| INVALID_AMOUNT / AMOUNT_OVERFLOW | 金额语法/范围错误；累计或输入非安全整数 |
| INVALID_DATE / INVALID_ENTITY | 日期、周期、游标时间错误；其他实体字段不合法 |
| DUPLICATE_ID | 同集合重复 ID（含同一账单重复附件引用） |
| REFERENCE_NOT_FOUND / REFERENCE_IN_USE | 缺少关联；删除仍被引用实体 |
| CATEGORY_TYPE_MISMATCH | 收支分类不匹配，或预算指向收入分类 |
| NEGATIVE_BALANCE / INVALID_TRANSFER | 非信用卡初始/最终余额为负；转账同源同目标 |
| BUDGET_OVERLAP / IMPORT_CONFLICT | 预留供 Task 10/13，经确认后实现，不在此提前冻结冲突策略 |

## 7. v1 兼容与验证

`AppData.ets` 的 Transaction/Diary/Budget/Settings 保持 v1 验证和旧页运行不变；不往旧 JSON 偷写 version2，不双写，不用 v2 覆盖 v1 类型。Task 3 单独迁移并保留源文件，Task 4 删除日记页面及行为。账户名称“信用卡”的迁移映射只对旧固定枚举适用，新账户不能靠名称猜类型。

运行器 `harmony/scripts/test-domain.cjs` 仅显式加载纯领域模块，仍禁止 Harmony Kit；Hypium `List.test.ets` 同步注册。当前测试结果、失败到通过证据见 `docs/harmony-acceptance.md`。Node 测试不代表数据库、页面及设备通过。
