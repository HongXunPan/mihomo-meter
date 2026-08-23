# Windows 工程代码技术选型

## 1. 文档定位

- 状态：W0-W3 已通过；基础系统能力待 CI 与实机验收
- 更新日期：2026-08-23
- 上游边界：父工作区 `docs/Windows技术方案.md`、`docs/Windows阶段W2D连接分析技术方案.md`
- 历史门禁：[Windows 阶段 W0 实机指南](Windows阶段W0实机指南.md)

本文是开源源码仓 Windows 工程结构、依赖版本和验证入口的唯一详细真相源，不重新定义父工作区的产品阶段或验收口径。W2 已完成，连接分析边界见[Windows 连接分析实现契约](Windows连接分析实现契约.md)；W3-2 分发、更新与放行边界见[Windows 分发实现契约](Windows分发实现契约.md)。

## 2. 固定选型与依赖

| 项目 | 当前决策 |
| --- | --- |
| SDK | .NET SDK 10.0.302，禁止预览版 |
| App Target | `net10.0-windows10.0.19041.0`、x64 |
| Core / Tests Target | `net10.0` |
| UI | WinUI 3、Windows App SDK 2.3.1 |
| Windows 构建工具 | Microsoft.Windows.SDK.BuildTools 10.0.28000.2526 |
| 网络与 JSON | BCL `HttpClient`、`ClientWebSocket`、`System.Text.Json` |
| 凭据 | Win32 Credential Manager P/Invoke，不引入托管凭据包 |
| 测试 | MSTest.Sdk 4.3.2，仅测试工程使用 |
| SQLite ADO.NET | Microsoft.Data.Sqlite.Core 10.0.10，仅 Core 使用 |
| SQLite Provider | SQLitePCLRaw.bundle_winsqlite3 2.1.11，仅 App / Tests 初始化 |
| Profile YAML | YamlDotNet 18.1.0，仅 Core 类型化读取 `profiles.yaml` |
| 产物 | 非打包、自包含 `win-x64` 目录、版本化便携 ZIP 与 unsigned NSIS 3.12.0 当前用户安装器，不裁剪、不合并单文件 |

App 的运行时包只含系统 SQLite Provider，发布目录不得携带 `e_sqlite3`。Core 只允许 SQLite ADO.NET 与 W2C 类型化 YAML；Tests 只允许系统 Provider。项目不引入 ORM、迁移工具或另一份原生 SQLite。

测试工程采用锁定版本的 `MSTest.Sdk` 与 Microsoft Testing Platform，不启用额外测试扩展。

## 3. 工程与职责边界

Windows 工程固定放在 `platform/windows/`：

```text
platform/windows/
├── global.json
├── MihomoMeter.Windows.slnx
├── MihomoMeter.Windows.App/
│   ├── Presentation/
│   ├── Lifecycle/
│   ├── Infrastructure/Configuration/
│   ├── Infrastructure/Credentials/
│   ├── Infrastructure/{Statistics,ConnectionAnalytics,Update}/
│   ├── Interop/
│   └── Diagnostics/
├── MihomoMeter.Windows.Core/
│   ├── Domain/
│   ├── Application/
│   └── Infrastructure/{Mihomo,Statistics,ConnectionAnalytics}/
└── MihomoMeter.Windows.Tests/
```

- `MihomoMeter.Windows.App`：WinUI 进程入口、工作台壳层、独立实时监控/Proxy 流量视图与 ViewModel、W0 壳层、Windows Credential Manager、本机设置路径和应用装配。
- `MihomoMeter.Windows.Core`：不依赖 WinUI 或 Win32 的领域模型、分类/差值/速率、连接状态机与流量账本契约，以及 Mihomo HTTP/WebSocket、SQLite 适配器。
- `MihomoMeter.Windows.Tests`：只引用 Core，链接仓库既有 `Tests/Fixtures/` 脱敏 JSON，不复制第二套 fixture。
- `Lifecycle` 与既有 `Interop` 只承载窗口、通知区域、悬浮入口和单实例能力；单实例使用固定会话 Mutex 与仅限当前用户的 Named Pipe，不依赖安装路径、版本或 AppInstance 身份。
- Windows 专属配置与凭据实现通过 Core 定义的窄接口注入，Core 不读取 `%LOCALAPPDATA%`，也不调用 Credential Manager。

## 4. W1 至 W2D-2 实现契约

Controller 地址、Credential Target Name、设置路径、接口顺序、分类语义、stale、退避和人工验收以父工作区 `docs/Windows阶段W1实时纵切验收.md` 为上游唯一真相。源码实现需要保持以下边界：

1. `ControllerEndpoint` 只生成回环 HTTP/HTTPS 与 WS/WSS 地址；UI 不自行拼接 URL。
2. HTTP 客户端只负责 `/version`、`/proxies` 的请求、鉴权、状态码与 JSON 错误映射。
3. WebSocket Collector 只负责 `/connections?interval=500`、消息分片组装、取消和快照解码，不计算业务速率。
4. `ProxyClassifier`、差值跟踪器和速率聚合器是无 UI、无 I/O 的 Core 类型，并与 Swift 同名语义锚点保持等价行为。
5. Application 层为每次连接建立独立会话标识；取消后拒绝迟到事件，stale 与重连只作用于当前会话。
6. 凭据和非敏感地址只有在 `/version` 与 `/proxies` 均成功后保存；保存失败必须显示错误，不能伪装为已连接。
7. UI 收到 stale、断开或计数器重置时清空实时速率，不沿用旧值，也不把无值显示成真实零速率。
8. `TrafficMeasurementSession` 从同一次分类差值输出账本观测；实时速率和持久化不得建立平行计数器。
9. `SQLiteTrafficLedger` 是内核会话、分钟桶、每日汇总、运行状态和统计任务的唯一账本入口；UI 不直接访问任务表或执行 SQL。
10. `TrafficStatisticsCoordinator` 隔离账本故障；数据库失败只使累计不可用，不停止 Controller 与 WebSocket。
11. App 与 Tests 初始化系统 SQLite Provider，Core 不直接依赖 Win32 Provider。
12. schema v2 只增量创建 `traffic_intervals`；v1 迁移必须保留四张 W2A 表和既有累计，失败时回滚且不清库。
13. 多个统计任务共享永久 Proxy 累计基线，固定使用 active/completed/interrupted 和类型化结束原因；分钟桶清理不得改变任务结果。
14. 最近 30 日只读取 `traffic_daily_totals` 并补齐缺失日；清空在同一事务删除核心累计与任务，下一帧只建立新基线。
15. 任务、每日查询、维护、快照和会话转换使用独立文件承载，`SQLiteTrafficLedger` 仍是唯一串行账本入口。
16. 主窗口使用 `NavigationView` 组合“实时监控”和“Proxy 流量”两个缓存视图；内容宿主横向、纵向铺满工作区，切换模块只替换内容，不新建窗口、Coordinator 或采样器。
17. `TrafficStatisticsWorkspaceViewModel` 只通过共享 `TrafficStatisticsCoordinator` 提交操作；筛选、自动名称和 30 日图表投影进入可独立测试的 Core 转换。
18. 最近 30 日上传/下载堆叠柱使用独立 WinUI `UserControl` 和系统布局元素绘制，保留零值日期位置；X 轴显示第 1、8、15、22 与最后一天，Y 轴显示零到峰值的字节刻度和网格线，并提供范围合计、峰值日与每柱可访问名称。
19. 新建、重命名、删除和清空使用 WinUI `ContentDialog`；对话框绑定当前工作台 `XamlRoot`，清空文案明确区分被删除统计与保留配置。
20. 高频账本快照使用稳定的可观察集合保留任务行和图表柱对象，只发布变化字段；不得通过每帧替换 `ItemsSource` 让已结束任务或整张图表反复重建。
21. `TrafficStatisticsQuickTaskProjection` 固定投影五个稳定槽位：活动任务按开始时间倒序优先，再按当前系统时区使用本地今日已结束任务补足，并返回全部活动数和溢出数。
22. `NotificationAreaStatisticsController` 只订阅共享 Monitoring/Statistics Coordinator，在界面线程生成不可变菜单快照；它不建立采样器、数据库连接或第二份统计状态。
23. 通知区域继续使用 `CreatePopupMenu`、`AppendMenu` 与 `TrackPopupMenuEx`；任务父项、五个槽位、查看/停止子命令和溢出入口全部使用原生菜单，不引入自绘面板或菜单依赖。
24. 菜单跟踪期只持有任务 ID 映射；选中后先关闭菜单，再由 Dispatcher 异步开始或停止。查看任务与溢出入口切换既有主窗口到“Proxy 流量”，不创建第二个窗口。
25. W2D-1 复用既有 `/connections` WebSocket、`ProxyClassifier` 与监控会话，不建立第二个采样器或连接流。
26. 元数据适配器只输出脱敏主机名、应用名称与容错开始时间；完整路径在进入领域层前丢弃，`find-process-mode` 请求失败不得阻断监控。
27. Proxy 与 DIRECT 使用独立单连接速率聚合器；stale、重连、停止和计数器回退同时清空速率、列表和覆盖率。
28. “Proxy 流量”使用独立路由视图承载缓存的流量统计与实时连接；实时页以稳定集合更新连接/应用/域名行，不每帧替换视图或 `ItemsSource`。
29. 通知区域 Proxy/直连 Top 5 使用两个原生子菜单和固定五槽，菜单打开时只投影内存快照，不查询网络或数据库。
30. 连接元数据、投影、菜单与隐私细节以[Windows 连接分析实现契约](Windows连接分析实现契约.md)为唯一详细真相源。

W2D-2 与 W3 已完成；登录启动见[实现契约](登录后启动实现契约.md)，受限恢复重启见[实现契约](Windows受限恢复重启实现契约.md)，仍不实现诊断 ZIP 或自动更新。

## 5. 配置、凭据与隐私

- Generic Credential Target Name 固定为 `com.HongXunPan.MihomoMeter.controller`，使用 `CredReadW`、`CredWriteW`、`CredDeleteW` 与 `CredFree`。
- 返回的非托管凭据缓冲区必须在 `finally` 中释放；Secret 不进入异常消息、`ToString`、调试输出或属性变更通知参数。
- `%LOCALAPPDATA%\HongXunPan\MihomoMeter\settings.json` 只保存版本化结构和规范化 Controller 地址；写入使用同目录替换，失败时保留上一个已验证文件。
- 测试使用内存凭据和设置替身，不访问真实 Credential Manager、用户目录或网络。
- 共享 fixture 只包含合成版本、代理类型与连接累计；不得新增真实节点、规则、目标、进程路径、连接 ID 或 Secret。
- `traffic.sqlite3` 只保存四类聚合、会话、运行状态和统计任务基线，不保存连接、节点、规则、目标、地址或 Secret。
- W2C 不创建运行日志或诊断 ZIP；错误状态不得包含 Secret、原始订阅 URL 或 Provider 键。
- W2D-2 只在独立数据库保存日期、脱敏应用/主机名和上下行聚合；不得保存连接 ID、路径、目标、节点、规则或连接时间。

## 6. 自动化验证

跨平台静态入口演进为：

```bash
python3 scripts/validate_windows.py
```

该检查校验固定 SDK、依赖白名单、全部 WinUI XAML、W0–W2D-2 必需文件、三套独立 schema、连接投影、批量归因，以及 W3 安装、更新描述、发布工作流权限和隐私禁止项。非 Windows 主机执行成功只证明静态契约成立。

Windows CI 和具备相同环境的 Windows 主机使用：

```powershell
pwsh -File scripts/validate_windows.ps1
```

固定顺序为静态检查、solution restore、Core 单元测试、App x64 Release 构建、非打包自包含 publish、发布目录检查、便携 ZIP、NSIS 安装器和 SHA-256 组装。Windows CI 上传版本化 W3-2 预览 artifact；统一 Release workflow 才能生成平台描述和 Tag，不连接真实 Controller 或机场。

Core 测试在既有矩阵外覆盖归因默认关闭、批量与强制刷新、保留/基数、精确查询、覆盖率和趋势摘要；静态契约另锁定趋势请求代际与固定明细区。真实 Windows 原生菜单与 WinUI 仍需实机验证。

## 7. 人工验收与证据边界

W2D-2、W3-0 与 W3-1 已完成实机验收；W3-2 按[实机指南](Windows阶段W3-2实机指南.md)执行 draft 前置、首个稳定版同版本检查和下一 Windows 稳定版发现更新三段证据，不以 CI 替代实机。

GitHub Actions 成功不能表述为 Windows 10 实机、Credential Manager 或真实 Controller 已通过；macOS 静态检查成功也不能表述为 Windows 已编译。每个纵切通过后由父工作区保存带日期证据，源码仓只维护公开复现指南和自动化结果。

## 8. 停止条件

出现以下情况必须停机：需要管理员权限、服务、驱动或私有 IPC；Secret、原始 URL 或连接明细落盘；查询无法保证经过 Mihomo；任一账本故障停止实时监控；必须携带另一份 SQLite；跨端契约无法对齐；主机名或应用识别始终为零；W0–W2C 回归。
