# Windows 工程代码技术选型

## 1. 文档定位

- 状态：W0 实现基线
- 更新日期：2026-08-07
- 上游边界：父工作区 `docs/Windows技术方案.md` 与 `docs/Windows阶段W0壳层验收.md`

本文是开源源码仓 Windows 工程结构、依赖版本和验证入口的真相源，不重新定义产品阶段或验收口径。当前仓库此前没有 Windows 同类实现，项目模式缺失；W0 仅借鉴 StorPulse 已验证的非打包 WinUI 3 壳层组织方式，不把其磁盘采集、权限或业务代码移入本项目。

## 2. 固定选型

| 项目 | W0 决策 |
| --- | --- |
| 语言与运行时 | C#、.NET SDK 10.0.302、`net10.0-windows10.0.19041.0` |
| UI | WinUI 3、Windows App SDK 2.3.1 |
| 系统互操作 | 仅在壳层边界使用 Win32 P/Invoke |
| 目标系统 | Windows 10 22H2 x64 标准用户 |
| 产物 | 非打包、自包含、`win-x64` 目录发布，不裁剪、不合并单文件 |
| 包管理 | SDK 风格项目与 NuGet 锁定版本 |
| 签名 | W0 不签名、不使用 MSIX、不要求商店身份 |

依赖只允许 `Microsoft.WindowsAppSDK` 2.3.1 与 `Microsoft.Windows.SDK.BuildTools` 10.0.28000.2526。新增依赖、调整目标框架或改成 WPF 必须先回到父仓技术选型闸门；WPF 只是在 WinUI W0 真实失败后的对照探针，不并行维护。

## 3. 工程边界

Windows 工程固定放在 `platform/windows/`：

- `MihomoMeter.Windows.App/`：进程入口、WinUI 主窗口与应用装配；
- `Lifecycle/`：单实例、窗口生命周期、通知区域与悬浮入口；
- `Interop/`：按职责拆分的 Win32 声明，不向 UI 暴露裸句柄细节；
- `Diagnostics/`：只向当前控制台输出不含本机敏感信息的 W0 阶段码；
- `scripts/validate_windows_w0.py`：非 Windows 主机可运行的静态契约检查；
- `scripts/validate_windows_w0.ps1`：Windows 还原、构建与自包含发布检查。

W0 只实现确定性内存状态。悬浮入口的开关和位置不写注册表、文件、SQLite 或应用设置：同一进程内隐藏再显示保持位置，进程重启后使用默认位置。

## 4. 生命周期契约

1. `Program` 在创建 WinUI `Application` 前注册固定单实例键；第二次启动把激活请求重定向到主实例后退出。
2. 主窗口关闭事件只隐藏窗口；只有通知区域菜单“退出”才能清理悬浮入口、通知区域图标和进程。
3. 通知区域图标基于 `Shell_NotifyIcon`，接收 `TaskbarCreated` 后重新注册。
4. 悬浮入口是同进程 Win32 工具窗口，不进入任务栏或 Alt+Tab，不持续抢焦点；单击打开主窗口，拖动只更新内存位置。
5. 所有非托管资源必须由明确的 `Dispose`/退出路径释放，重复通知和重复窗口必须幂等处理。

## 5. W0 禁止项

- 不连接 Mihomo Controller、WebSocket 或真实业务模型；
- 不读取或保存 Secret、Profile、订阅地址、节点或连接目标；
- 不创建持久化数据库、运行日志、诊断 ZIP、本机配置或启动项；
- 不引入后台服务、管理员权限、UAC、驱动、ETW、安装器或自动更新；
- 不把 Windows 壳层反向抽象进现有 Swift/macOS 工程。

## 6. 验证分层

1. 所有主机：`python3 scripts/validate_windows_w0.py`，校验项目属性、固定依赖、清单、目录和禁止项。
2. Windows CI：`pwsh -File scripts/validate_windows_w0.ps1`，执行 restore、x64 Release build 与非打包自包含 publish，并上传目录 artifact。
3. Windows 10 22H2 x64 标准用户实机：按《Windows 阶段 W0 实机指南》完成单实例、关闭隐藏、通知区域、Explorer 恢复、悬浮拖动、DPI、睡眠和明确退出验证。

CI 构建成功不能代替 Win10 实机兼容与交互结论；macOS 静态检查成功也不能表述为 Windows 已编译。

## 7. 停止条件

出现以下情况必须停止实现并回到父仓重新决策：Win10 22H2 无法以标准用户启动；非打包自包含仍依赖预装运行时；WinUI 无法稳定满足通知区域、悬浮入口、DPI 或单实例契约；需要新增持久化、业务接入、第三方依赖或管理员权限；文档、代码、CI 与实机结果互相冲突。
