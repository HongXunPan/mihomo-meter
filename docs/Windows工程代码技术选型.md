# Windows 工程代码技术选型

## 1. 文档定位

- 状态：W0 已通过，W1 工程契约已锁定并进入实现
- 更新日期：2026-08-07
- 上游边界：父工作区 `docs/Windows技术方案.md`、`docs/Windows阶段W1实时纵切验收.md`
- 历史门禁：[Windows 阶段 W0 实机指南](Windows阶段W0实机指南.md)

本文是开源源码仓 Windows 工程结构、依赖版本和验证入口的唯一详细真相源，不重新定义父工作区的产品阶段或验收口径。W0 已验证非打包 WinUI 3 壳层；W1 在现有壳层上接入 Controller、实时分类与重连，不移动或反向抽象 macOS `Sources/`。

## 2. 固定选型与依赖

| 项目 | W1 决策 |
| --- | --- |
| SDK | .NET SDK 10.0.302，禁止预览版 |
| App Target | `net10.0-windows10.0.19041.0`、x64 |
| Core / Tests Target | `net10.0` |
| UI | WinUI 3、Windows App SDK 2.3.1 |
| Windows 构建工具 | Microsoft.Windows.SDK.BuildTools 10.0.28000.2526 |
| 网络与 JSON | BCL `HttpClient`、`ClientWebSocket`、`System.Text.Json` |
| 凭据 | Win32 Credential Manager P/Invoke，不引入托管凭据包 |
| 测试 | MSTest.Sdk 4.3.2，仅测试工程使用 |
| 产物 | 非打包、自包含 `win-x64` 目录，不裁剪、不合并单文件 |

发布应用的 NuGet 依赖仍严格只有 `Microsoft.WindowsAppSDK` 与 `Microsoft.Windows.SDK.BuildTools`。`MSTest.Sdk` 是测试工程的 MSBuild SDK，不进入 App 项目或发布目录；Core 不允许 PackageReference。新增依赖、调整 Target Framework、改变运行时发布形态或更换 UI 技术栈必须先回到父仓技术选型闸门。

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
│   ├── Interop/
│   └── Diagnostics/
├── MihomoMeter.Windows.Core/
│   ├── Domain/
│   ├── Application/
│   └── Infrastructure/Mihomo/
└── MihomoMeter.Windows.Tests/
```

- `MihomoMeter.Windows.App`：WinUI 进程入口、视图与 ViewModel、W0 壳层、Windows Credential Manager、本机设置路径和应用装配。
- `MihomoMeter.Windows.Core`：不依赖 WinUI 或 Win32 的领域模型、分类/差值/速率、连接状态机契约，以及 Mihomo HTTP/WebSocket 适配器。
- `MihomoMeter.Windows.Tests`：只引用 Core，链接仓库既有 `Tests/Fixtures/` 脱敏 JSON，不复制第二套 fixture。
- `Lifecycle` 与既有 `Interop` 继续只承载窗口、通知区域、悬浮入口和单实例能力，不接入网络或领域算法。
- Windows 专属配置与凭据实现通过 Core 定义的窄接口注入，Core 不读取 `%LOCALAPPDATA%`，也不调用 Credential Manager。

W1 开始前必须先建立 Core 与 Tests 的独立项目，不能继续把 Controller、状态机或分类算法追加进 `MainWindow.xaml.cs`。主窗口代码隐藏只允许处理窗口事件和把用户意图转交 ViewModel。

## 4. W1 实现契约

Controller 地址、Credential Target Name、设置路径、接口顺序、分类语义、stale、退避和人工验收以父工作区 `docs/Windows阶段W1实时纵切验收.md` 为上游唯一真相。源码实现需要保持以下边界：

1. `ControllerEndpoint` 只生成回环 HTTP/HTTPS 与 WS/WSS 地址；UI 不自行拼接 URL。
2. HTTP 客户端只负责 `/version`、`/proxies` 的请求、鉴权、状态码与 JSON 错误映射。
3. WebSocket Collector 只负责 `/connections?interval=500`、消息分片组装、取消和快照解码，不计算业务速率。
4. `ProxyClassifier`、差值跟踪器和速率聚合器是无 UI、无 I/O 的 Core 类型，并与 Swift 同名语义锚点保持等价行为。
5. Application 层为每次连接建立独立会话标识；取消后拒绝迟到事件，stale 与重连只作用于当前会话。
6. 凭据和非敏感地址只有在 `/version` 与 `/proxies` 均成功后保存；保存失败必须显示错误，不能伪装为已连接。
7. UI 收到 stale、断开或计数器重置时清空实时速率，不沿用旧值，也不把无值显示成真实零速率。

W1 不实现 SQLite、跨进程累计、连接明细、Profile、订阅配额、诊断日志、开机启动、安装器或自动更新。W0 的 `run-w0-gate.cmd` 与控制台阶段码只保留为历史门禁，不成为 W1 预览产物的正式入口。

## 5. 配置、凭据与隐私

- Generic Credential Target Name 固定为 `com.HongXunPan.MihomoMeter.controller`，使用 `CredReadW`、`CredWriteW`、`CredDeleteW` 与 `CredFree`。
- 返回的非托管凭据缓冲区必须在 `finally` 中释放；Secret 不进入异常消息、`ToString`、调试输出或属性变更通知参数。
- `%LOCALAPPDATA%\HongXunPan\MihomoMeter\settings.json` 只保存版本化结构和规范化 Controller 地址；写入使用同目录替换，失败时保留上一个已验证文件。
- 测试使用内存凭据和设置替身，不访问真实 Credential Manager、用户目录或网络。
- 共享 fixture 只包含合成版本、代理类型与连接累计；不得新增真实节点、规则、目标、进程路径、连接 ID 或 Secret。
- W1 不创建运行日志或诊断 ZIP；可观察错误使用不含地址细节和 Secret 的类型化状态。

## 6. 自动化验证

跨平台静态入口演进为：

```bash
python3 scripts/validate_windows.py
```

该检查校验固定 SDK、项目分层、依赖白名单、Target Framework、清单、W0 生命周期锚点、W1 必需文件与禁止项。非 Windows 主机执行成功只证明静态契约成立。

Windows CI 和具备相同环境的 Windows 主机使用：

```powershell
pwsh -File scripts/validate_windows.ps1
```

固定顺序为静态检查、solution restore、Core 单元测试、App x64 Release 构建、非打包自包含 publish 和发布目录检查。CI 上传 W1 预览 artifact，不运行真实 Credential Manager 写入或外部 Controller 集成测试。

测试至少覆盖地址、fixture 解码、分类、差值、速率、stale、重连退避、会话隔离和配置保存编排。W0 壳层回归由静态标记、构建门禁和 Windows 10 实机矩阵共同负责，不能只靠 Core 单元测试。

## 7. 人工验收与证据边界

Windows 10 22H2 x64 标准用户必须按[Windows 阶段 W1 实机指南](Windows阶段W1实机指南.md)复现父工作区 W1 矩阵，验证正确/错误 Secret、真实 Proxy 与 DIRECT 流量、Mihomo 停止恢复、用户断开、睡眠、重复启动和退出清理。测试期间必须重新记录断开空闲、连接空闲和受控流量窗口的 CPU 与内存，不能沿用缺失的 W0 资源数值。

GitHub Actions 成功不能表述为 Windows 10 实机、Credential Manager 或真实 Controller 已通过；macOS 静态检查成功也不能表述为 Windows 已编译。W1 通过后由父工作区保存带日期证据，源码仓只维护公开复现指南和自动化结果。

## 8. 停止条件

出现以下情况必须停止实现并回到父仓重新决策：需要管理员权限、服务、驱动或 Clash Verge 私有 IPC；Secret 需要写入普通文件；Core 必须依赖 WinUI/Win32 才能测试；`ClientWebSocket` 无法可靠取消或产生重复会话；共享 fixture 的 Swift/C# 口径无法对齐；必须增加未批准运行时依赖；W0 壳层回归；W1 需要 SQLite 或 W2 能力才能成立。
