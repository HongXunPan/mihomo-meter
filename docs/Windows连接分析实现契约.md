# Windows 连接分析实现契约

## 1. 文档定位

- 状态：W2D-0 已通过；W2D-1 已实现，待 Windows CI 与 Win10 实机验收
- 更新日期：2026-08-08
- 工程基线：[Windows 工程代码技术选型](Windows工程代码技术选型.md)
- 当前实机入口：[Windows 阶段 W2D-1 实机指南](Windows阶段W2D1实机指南.md)

本文是源码仓 Windows 连接分析职责、隐私边界与自动化证据的公开真相源。父工作区负责阶段范围和放行结论；历史 W2D-0 复现入口仍保留在[实机指南](Windows阶段W2D0实机指南.md)。

## 2. 阶段边界

Windows 连接分析按三个可独立验证的纵切推进：

1. **W2D-0 元数据覆盖率门禁**：已用 52 条 Proxy 样本通过，主机名、应用及两者同时可识别均为 52 条、100%；
2. **W2D-1 实时连接**：当前实现 Proxy/DIRECT 活动连接、双向速率、累计、时长、分组搜索、进程识别诊断和通知区域 Top 5；
3. **W2D-2 历史归因**：尚未实现，未来才考虑默认关闭的独立归因账本、30 日榜单、交叉筛选、趋势和记录覆盖率。

W2D-1 不创建归因 SQLite，不保存当前筛选，不提供连接历史、诊断 ZIP、安装器、开机启动或自动更新。

## 3. 元数据与解码边界

`MihomoConnectionResponse` 通过专用 JSON Converter 读取 `metadata.host`、`sniffHost`、`process` 与 `processPath`，并在基础设施边界内完成脱敏：

- 字符串去除首尾空白，UTF-8 超过 2,048 字节或类型异常时视为缺失；
- 主机名优先使用 `host`，再使用 `sniffHost`，IPv4、IPv6 和带方括号的 IP 不作为主机名；
- 应用名称优先取 `processPath` 最外层 `.app` 名称，再取规范化 `process`，最后退化为路径文件名；
- 完整进程路径仅参与局部解析，在进入领域层前丢弃；
- `start` 使用容错 ISO 8601 解码，缺失、异常类型或未知格式只使时长不可用，不拒绝整帧。

领域层只接收脱敏主机名、应用名称、开始时间、累计、分类与内存连接 ID。目标 IP、端口、节点、规则、链路和完整路径不进入展示、日志、Fixture 或持久化层。连接 ID 只用于本次内存会话的差值、排序稳定性和行复用，从不显示或落盘。

`/configs.find-process-mode` 只读映射 `always`、`strict`、`off`；缺失、未来值或请求失败均退化为“不可确认”，不得阻断 Controller 验证、WebSocket 监控或配额能力，也不得自动修改 Mihomo 配置。

## 4. 实时链路与生命周期

W2D-1 复用既有 `/connections?interval=500`、`ProxyClassifier` 和 `TrafficMeasurementSession`，不建立第二个采样器。`ConnectionDeltaTracker` 从同一次连接差值输出分类、累计和脱敏元数据；Proxy 与 DIRECT 各自使用 1 秒窗口、最近 2 个窗口平滑的 `ConnectionRateAggregator`。

新连接从零计算首个差值；已消失连接立即移出速率窗口。内核计数回退、用户停止、stale、新会话和重连必须同时清空单连接速率、活动列表与覆盖率，不沿用旧连接或把缺失值显示成真实零速率。分类目录刷新只影响后续可靠分类。

覆盖率仍只累计可靠 Proxy 连接：同一 ID 在会话内只计一次，后续元数据补齐以逻辑或升级识别状态。DIRECT、REJECT 与未知不进入覆盖率分母。

## 5. 页面与通知区域

“Proxy 流量”使用独立 `ProxyTrafficWorkspaceView` 在缓存的“流量统计”和“实时连接”视图间切换，不向既有大型统计 XAML 继续追加职责，也不新建窗口、Coordinator 或采样器。

实时页支持：

- Proxy/直连切换；
- 连接、应用、域名三种查看方式；
- 应用名或域名的不区分大小写搜索；
- 连接行展示脱敏域名、应用、双向速率、累计和时长；
- 分组行展示相关维度数量、连接数、聚合速率和累计；
- Proxy 页展示 `find-process-mode` 与本次会话应用识别数量的只读诊断。

高频刷新使用稳定 `ObservableCollection`，按内存 ID 或分组键移动并更新既有行，只通知真实变化字段，禁止每帧替换视图或整份 `ItemsSource`。

通知区域继续使用 Win32 原生菜单。Proxy 与直连各有一个 Top 5 子菜单，每个子菜单固定五个槽位；只纳入当前总速率大于零的连接，按总速率降序排列，空位明确显示“暂无传输”。菜单打开时只捕获内存快照，不查询网络或数据库；“查看实时连接”复用主窗口并定位对应路径。

## 6. 自动化与隐私门禁

Core 测试至少覆盖：

- 元数据规范化、IP 排除、完整路径丢弃和异常 `start` 容错；
- `find-process-mode` 已知/未知映射及配置请求失败隔离；
- 单连接基线、双窗口平滑、关闭连接移除和 reset；
- Proxy/DIRECT 同源分类、计数器回退清空；
- 搜索、分组、未知标签、排序和固定五槽 Top 5；
- 覆盖率去重升级和生命周期清理。

`python3 scripts/validate_windows.py` 检查 W2D-1 文件、UI/菜单标记、无额外运行时依赖，以及领域层没有完整进程路径、所有 SQLite schema 没有连接 ID、路径、目标 IP/端口、规则或链路字段。非 Windows 静态通过不代表 WinUI 已编译或实机交互已通过。

Windows CI 固定执行静态检查、Core 单元测试、App x64 Release 构建和非打包自包含发布，并上传 `mihomo-meter-windows-w2d-x64-<sha>` artifact。

## 7. 实机放行

Win10 22H2 x64 标准用户按 W2D-1 指南验证真实 Proxy/DIRECT 连接、三种查看方式、搜索、速率/累计/时长、状态清理、`find-process-mode` 诊断、两个固定五槽原生子菜单及 W0-W2C 回归。

若出现旧连接残留、完整路径或连接 ID 泄漏、通知菜单触发请求、整页持续闪烁、W0-W2C 回归，W2D-1 不得放行。CI 和实机均通过并由父工作区记录后，才能进入 W2D-2。
