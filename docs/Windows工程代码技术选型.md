# Windows 工程代码技术选型

## 1. 文档定位

- 状态：W2A 已合并，W2B1 统计任务账本进入实现
- 更新日期：2026-08-08
- 上游边界：父工作区 `docs/Windows技术方案.md`、`docs/Windows阶段W2B统计任务与工作台技术方案.md`
- 历史门禁：[Windows 阶段 W0 实机指南](Windows阶段W0实机指南.md)

本文是开源源码仓 Windows 工程结构、依赖版本和验证入口的唯一详细真相源，不重新定义父工作区的产品阶段或验收口径。W2B1 在 W2A 核心账本上增加统计任务、最近 30 日查询和清空语义，不移动或反向抽象 macOS `Sources/`。

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
| 产物 | 非打包、自包含 `win-x64` 目录，不裁剪、不合并单文件 |

App 的运行时包只增加 `SQLitePCLRaw.bundle_winsqlite3`，它连接 Windows 10 系统 `winsqlite3.dll`，发布目录不得携带 `e_sqlite3`。Core 只允许 `Microsoft.Data.Sqlite.Core`；Tests 只允许系统 Provider。项目不引入 EF Core、ORM、迁移工具或另一份原生 SQLite。新增依赖、调整 Target Framework、改变运行时发布形态或更换 UI 技术栈必须先回到父仓技术选型闸门。

测试工程采用 `MSTest.Sdk/4.3.2` 与 Microsoft Testing Platform，版本在工程和 `global.json` 中锁定。当前不启用覆盖率、浏览器、云服务或其他测试扩展，避免把测试工具链扩成运行时依赖。

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
│   ├── Infrastructure/Statistics/
│   ├── Interop/
│   └── Diagnostics/
├── MihomoMeter.Windows.Core/
│   ├── Domain/
│   ├── Application/
│   └── Infrastructure/{Mihomo,Statistics}/
└── MihomoMeter.Windows.Tests/
```

- `MihomoMeter.Windows.App`：WinUI 进程入口、视图与 ViewModel、W0 壳层、Windows Credential Manager、本机设置路径和应用装配。
- `MihomoMeter.Windows.Core`：不依赖 WinUI 或 Win32 的领域模型、分类/差值/速率、连接状态机与流量账本契约，以及 Mihomo HTTP/WebSocket、SQLite 适配器。
- `MihomoMeter.Windows.Tests`：只引用 Core，链接仓库既有 `Tests/Fixtures/` 脱敏 JSON，不复制第二套 fixture。
- `Lifecycle` 与既有 `Interop` 继续只承载窗口、通知区域、悬浮入口和单实例能力，不接入网络或领域算法。
- Windows 专属配置与凭据实现通过 Core 定义的窄接口注入，Core 不读取 `%LOCALAPPDATA%`，也不调用 Credential Manager。

W1 开始前必须先建立 Core 与 Tests 的独立项目，不能继续把 Controller、状态机或分类算法追加进 `MainWindow.xaml.cs`。主窗口代码隐藏只允许处理窗口事件和把用户意图转交 ViewModel。

## 4. W1、W2A 与 W2B1 实现契约

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

W2B1 不实现 WinUI 统计工作台、通知区域任务菜单、连接明细、Profile、订阅配额、诊断日志、开机启动、安装器或自动更新。W0 的 `run-w0-gate.cmd` 与控制台阶段码只保留为历史门禁，不成为预览产物的正式入口。

## 5. 配置、凭据与隐私

- Generic Credential Target Name 固定为 `com.HongXunPan.MihomoMeter.controller`，使用 `CredReadW`、`CredWriteW`、`CredDeleteW` 与 `CredFree`。
- 返回的非托管凭据缓冲区必须在 `finally` 中释放；Secret 不进入异常消息、`ToString`、调试输出或属性变更通知参数。
- `%LOCALAPPDATA%\HongXunPan\MihomoMeter\settings.json` 只保存版本化结构和规范化 Controller 地址；写入使用同目录替换，失败时保留上一个已验证文件。
- 测试使用内存凭据和设置替身，不访问真实 Credential Manager、用户目录或网络。
- 共享 fixture 只包含合成版本、代理类型与连接累计；不得新增真实节点、规则、目标、进程路径、连接 ID 或 Secret。
- `traffic.sqlite3` 只保存四类聚合、会话、运行状态和统计任务基线，不保存连接、节点、规则、目标、地址或 Secret。
- W2B1 不创建运行日志或诊断 ZIP；可观察错误使用不含地址细节和 Secret 的类型化状态。

## 6. 自动化验证

跨平台静态入口演进为：

```bash
python3 scripts/validate_windows.py
```

该检查校验固定 SDK、项目分层、依赖白名单、Target Framework、清单、W0/W1 生命周期锚点、W2B1 必需文件、schema v2 五张表与禁止项。非 Windows 主机执行成功只证明静态契约成立。

Windows CI 和具备相同环境的 Windows 主机使用：

```powershell
pwsh -File scripts/validate_windows.ps1
```

固定顺序为静态检查、solution restore、Core 单元测试、App x64 Release 构建、非打包自包含 publish 和发布目录检查。CI 上传 W2B x64 预览 artifact，不运行真实 Credential Manager 写入或外部 Controller 集成测试。

测试至少覆盖地址、fixture 解码、分类、差值、速率、stale、重连退避、会话隔离、配置保存，以及账本基线、分类增量、重连缺口、计数器回退、重启恢复、跨日、保留清理、v1→v2 迁移、重叠任务、各类中断、最近 30 日、清空回滚和数据库故障隔离。W0/W1 回归仍不能只靠 Core 单元测试。

## 7. 人工验收与证据边界

Windows 10 22H2 x64 标准用户按[Windows 阶段 W2B 实机指南](Windows阶段W2B实机指南.md)分增量验证数据库升级、任务工作台、通知区域和 W0/W1 生命周期。分类兼容性与精确性能数据继续作为稳定分发后的观察项，不把未记录数据写成量化结论。

GitHub Actions 成功不能表述为 Windows 10 实机、Credential Manager 或真实 Controller 已通过；macOS 静态检查成功也不能表述为 Windows 已编译。W1 通过后由父工作区保存带日期证据，源码仓只维护公开复现指南和自动化结果。

## 8. 停止条件

出现以下情况必须停止实现并回到父仓重新决策：需要管理员权限、服务、驱动或 Clash Verge 私有 IPC；Secret 或连接明细进入数据库；Core 必须依赖 WinUI/Win32 Provider 才能测试；schema v2 迁移删除或重建 W2A 数据；账本故障停止实时监控；任务重复累计或跨日丢失；必须携带另一份原生 SQLite；共享 fixture 的 Swift/C# 口径无法对齐；增加未批准依赖；W0/W1 生命周期回归。
