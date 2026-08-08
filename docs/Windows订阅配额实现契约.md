# Windows 订阅配额实现契约

## 1. 定位与范围

本文是 Windows W2C 在源码仓的公开实现契约。产品口径沿用[订阅配额架构](订阅配额架构.md)，Windows 工程基线见[Windows 工程代码技术选型](Windows工程代码技术选型.md)，实机步骤见[Windows 阶段 W2C 实机指南](Windows阶段W2C实机指南.md)。

W2C 包含当前运行订阅轻量追踪、用户授权的 Clash Verge Profile 目录、多 Profile 主动查询、独立配额账本、周期与变化事件、四档真实快照趋势、预计耗尽、通知区域文字摘要和清空。它不实现连接分析、客户端目录扫描、私有 IPC、安装器、自动更新或稳定 Release。

## 2. 工程职责与依赖

- Core 的 Domain/Application 承载配额值、订阅身份、周期、事件、趋势、预测、调度和协调器；
- Core 的 Infrastructure 承载 Mihomo DTO、YAML 只读适配器、主动查询和 SQLite 账本；
- App 只承载文件夹选择、非敏感路径设置、Credential Manager、WinUI 工作台和通知区域接线；
- Tests 对领域、Schema、YAML、HMAC、HTTPS/代理约束、单并发、冷却和生命周期隔离做自动化验证。

Core 新增 `YamlDotNet 18.1.0`，只允许类型化解析 `profiles.yaml`。配额库继续复用既有 `Microsoft.Data.Sqlite.Core 10.0.10` 和 Windows 系统 `winsqlite3.dll`；不引入 ORM、第二个 SQLite Provider、图表库或自绘通知区域面板。

## 3. 身份与采集

Controller 验证成功后，配额协调器立即请求 `/providers/proxies`，随后约每 5 分钟观察。只有响应中恰好存在一个有效 `subscriptionInfo` 候选，且用户明确确认后，才记录“当前运行订阅”。零个、多个、Provider 来源变化或 Controller 地址变化会暂停轻量追踪，不猜选、不求和。

用户通过 Windows 文件夹选择器明确选择根部含 `profiles.yaml` 的目录。应用不扫描客户端目录；解析器只读取根文件，限制 2 MiB，拒绝重解析点，忽略未知字段并按 UID 建立身份。Profile 改名保持身份；URL 变化只更新应用本地 HMAC-SHA256 指纹并重新进入查询计划。原始 URL 只存在于本次内存目录快照。

## 4. 主动查询

应用从 `/configs` 选择 mixed、HTTP、SOCKS 本地端口，顺序固定为 mixed → HTTP → SOCKS；安全的 `global-ua` 原样用于请求，否则使用 `clash.meta`。请求只接受 HTTPS，手动处理最多五次 HTTPS 重定向，始终显式设置当前 Mihomo 代理；没有本地代理时安全失败，禁止直连。

响应只读取标准 `Subscription-Userinfo` 或名称以 `-subscription-userinfo` 结尾的兼容头，正文不进入业务层。多个 Profile 全局单并发；可选间隔为 1、3、6、12、24 小时，并应用随机抖动、每日有限自动重试和 60 秒手动冷却。查询失败保留最近有效快照，不写零值。

## 5. 账本、周期与趋势

配额只写入 `%LOCALAPPDATA%\HongXunPan\MihomoMeter\quota.sqlite3`，与 `traffic.sqlite3` 物理隔离。Schema v1 包含订阅、快照、周期、事实事件和查询状态；数据库版本高于应用时拒绝打开并只降级配额能力。

账本不得保存原始 URL、Token、正文、完整响应头、Provider 键、UA 原文、节点或 Controller Secret。URL 只保存独立 Credential Manager 密钥生成的 HMAC 指纹；Controller Secret 与指纹密钥使用不同 Target。

累计下降开启待确认新周期；总量和到期变化记录事实事件。24 小时、7 天、30 天和 12 月趋势只使用真实快照，跨周期或任一累计方向回退时断线，不插值、不补零。预计耗尽只使用当前已确认周期内最多近 7 天的新鲜样本，并要求至少两个点、跨度至少 6 小时且消耗速度为正。

## 6. 展示与生命周期

主窗口缓存“订阅余额”工作台，展示轻量模式确认、Profile 追踪与间隔、单项/全部查询、周期确认、四档趋势和清空。图表使用 WinUI 原生 Canvas/Shape，以范围首尾真实时间为横轴，提供 X/Y 轴、下载/上传增量堆叠、周期断点，以及包含真实起止时间、增量和间隔的指针明细。

通知区域使用打开时的内存快照，最多展示五个订阅的剩余或故障摘要，并提供进入完整窗口和“立即查询全部”命令；菜单跟踪期间不执行 SQLite、YAML 或网络操作。断线、重连、用户断开和退出均停止配额网络任务，最近历史保留。配额初始化、运行或停止异常不得阻断 W1 实时监控和 W2A/W2B 核心流量。

清空只重置 `quota.sqlite3` 内的身份、快照、周期、事件和调度状态；Controller 配置、Profile 目录路径、指纹密钥和 `traffic.sqlite3` 保留。

## 7. 验证边界

跨平台静态检查只证明文件、依赖、隐私标记和 XAML 契约成立。Windows CI 固定执行 Core 单元测试、App x64 Release 构建和非打包自包含发布；Win10 文件夹选择器、Credential Manager、原生通知区域、图表指针与真实 Mihomo/机场交互仍必须按实机指南验证。
