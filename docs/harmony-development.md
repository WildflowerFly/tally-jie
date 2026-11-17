# HarmonyOS 原生账本开发说明

## 工程与状态

`harmony/` 独立使用 Stage/ArkTS/ArkUI，不依赖Flutter；本轮未修改Android/iOS功能。包名 `com.tallyjie.harmony`，target SDK `26.0.0`，compatible SDK `6.1.1(24)`，无新增第三方运行时依赖。

当前 **Implementing**，不是已验收发行包。功能与未完成项分别见[实施计划](harmony-implementation-plan.md)、[验收记录](harmony-acceptance.md)、[自主决策记录](harmony-decisions.md)。用户授权逐Task提交、不推送，并授权实现者自行判断产品细节；设备事实不能自行假定。

## 当前入口

默认记账；五入口依次统计、明细、记账、存款、我的。

- 记账：动态分类/账户、正十进制金额、备注、原生日期/时间选择、自定义数字键盘；保存成功才重置，失败保留。首次使用从空账户/分类开始，不写入演示数据。
- 我的：账户、分类、预算管理及数据交换。账户只有普通/信用卡最小类型，只有信用卡可负；改名及迁移保持历史ID引用保护。
- 明细：字面关键词和类型/账户/分类/日期/金额组合过滤；50条游标展示、完整筛选及每日汇总；内联详情/编辑/删除。
- 统计：周/月/年/自定义范围，日/周/月补零趋势、分布、排行、最高支出日/分类并列及全日历日日均；对应文本按钮下钻。
- 存款：渐变账户滑动卡片、总/当前/初始余额、累计收支、独立转入转出、最近记录及全部明细；账户内可管理独立转账。
- 数据交换：[实际CSV/JSON格式](harmony-import-export.md)，先校验预览再合并，不直接覆盖。不是完整图片或旧归档备份。
- 原日记与主题字号设置入口已下线；不物理删除旧文件。

## 代码组织

- `entry/src/main/ets/model/LedgerModels.ets`：v2稳定ID实体、筛选及错误类型；`AppData.ets`保留v1迁移契约。
- `entry/src/main/ets/domain/`：整数分、日历范围、全账本余额/引用校验、CSV。
- `entry/src/main/ets/database/`：relationalStore打开和schema升级。
- `entry/src/main/ets/repository/LedgerRepository.ets`：事务、修订号、迁移标记和故障注入点。
- `entry/src/main/ets/service/`：迁移、账户、分类、收支、查询、统计、预算、转账、数据交换；旧DataStore仅保留兼容实现，新界面不调用旧写入。
- `entry/src/main/ets/state/AppState.ets`：唯一账本状态，提交成功再发布快照。
- `entry/src/main/ets/pages/`：五入口及内联管理；`components/`及`theme/`：导航、统一金融色板。
- `entry/src/test/`：纯领域测试；`entry/src/ohosTest/`：平台数据库/迁移/导航探针（已编译未设备运行）。

## 数据、安全及回退

- 新账本使用relationalStore数据库 `tallyjie-ledger.db`，DB schema1，业务模型v2；写入前完整校验，单事务更新并递增修订号，失败不更新内存。当前仍全快照替换/读取，查询内存分页，不宣称已完成数据库索引分页优化。
- 金额为整数分；单笔最多9位整数、2位小数，拒绝科学计数法和非正收支/转账。总额逐步检查安全整数。
- 旧源 `filesDir/tallyjie.json`、`filesDir/images/`保留；迁移标记与账本同事务，源文件摘要校验。历史初始余额0并提示；普通账户历史净额负时先补录真实初始余额，不伪造收入/负债类型。
- 原版不能读新v2数据。安装旧版仅能读取旧迁移源，不会包含新账单；不得在没有完整备份的情况下卸载以“回退”。迁移平台故障恢复仍需真机验证。
- 历史图片引用保留但新UI无新增照片功能；当前交换不含图片字节或日记归档，勿当完整迁移备份。
- 系统备份原扩展及allowToBackupRestore配置未改变，新数据库系统恢复尚未验证。没有新网络上传或登录；本地财务文件同样敏感，需妥善保存。

## 构建与运行

本轮工具：DevEco Studio `26.0.0.865`，SDK包 `26.0.0.105`，Node `24.14.1`，Hvigor `6.26.9`，OhPM `26.0.0.630`，JBR `25.0.2`。

1. DevEco打开 `harmony/`，同步匹配SDK与OhPM/Hvigor。
2. 连接 compatible SDK 支持的设备或模拟器。
3. 本机配置Signing Configs（当前为空），不提交证书/密钥。
4. 选择entry运行，实际设备验收按验收文档执行。

PowerShell示例（本机路径自行替换）：

```powershell
$studio = 'C:\path\to\DevEco Studio'
$env:DEVECO_SDK_HOME = "$studio\sdk"
$env:JAVA_HOME = "$studio\jbr"
cd harmony
& "$studio\tools\node\node.exe" scripts/test-domain.cjs "$studio\tools\hvigor\hvigor\node_modules\typescript\lib\typescript.js"
& "$studio\tools\node\node.exe" "$studio\tools\hvigor\bin\hvigorw.js" --mode module -p product=default -p module=entry@default assembleHap --no-daemon
& "$studio\tools\node\node.exe" "$studio\tools\hvigor\bin\hvigorw.js" --mode module -p product=default -p module=entry@ohosTest assembleHap --no-daemon
& "$studio\sdk\default\openharmony\toolchains\hdc.exe" list targets
```

Node运行器用TypeScript转译及最小Hypium适配，不替代真实ArkTS/设备平台测试。测试包构建不等于测试运行。

## 本轮最终检查

- **47项领域测试通过**，含旧8项、领域规则、业务服务、数据交换、独立整数基准的跨业务流程、1万条同时间分页无丢失重复。
- 应用增量构建成功，测试HAP构建成功；未签名产物 `harmony/entry/build/default/outputs/default/entry-default-unsigned.hap`。
- HDC仍 `[Empty]`，无设备/模拟器操作、磁盘/选择器故障或冷启动/保存/筛选性能结论。
- 尚待完善：SQL分页、图表扇区与趋势点直接交互、透视层叠视觉、完整CSV多表协议/映射、附件归档可移植导出、分批导入、设备全链路与系统备份恢复。1万条逻辑测试不等于满足候选2s/300ms/500ms性能阈值。
