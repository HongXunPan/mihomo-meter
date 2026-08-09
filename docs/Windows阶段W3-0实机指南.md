# Windows 阶段 W3-0 实机指南

## 1. 用途与边界

本文用于 Windows 10 22H2 x64 标准用户验证版本化便携 ZIP、SHA-256 和解压启动。W3-0 仍是预览 artifact，不包含安装器、卸载器、应用内更新或稳定 Release。

不要上传 Controller Secret、订阅 URL、真实主机名、应用名称、进程路径、数据库、设置文件或本机路径。反馈只需提供提交 SHA、Action run 链接和失败步骤。

## 2. 下载与校验

1. 确认目标提交的“Windows 构建与测试”成功。
2. 下载名称以 `mihomo-meter-windows-w3-preview-0.0.0-` 开头的 artifact 并完整解压。
3. 确认 artifact 只包含 `Mihomo-Meter-0.0.0-windows-x64-portable.zip` 与 `SHA256SUMS`。
4. 在 artifact 目录执行：

```powershell
$Expected = (Get-Content .\SHA256SUMS).Split(' ')[0]
$Actual = (Get-FileHash .\Mihomo-Meter-0.0.0-windows-x64-portable.zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($Expected -ne $Actual) { throw "SHA-256 不一致" }
```

5. 解压 ZIP，确认所有程序文件位于单一 `Mihomo Meter` 目录，且不存在 PDB、数据库、日志、`settings.json`、`profiles.yaml`、MSIX 或 APPX。

## 3. 启动与生命周期

1. 使用标准用户直接运行 `Mihomo Meter\MihomoMeter.Windows.App.exe`，不要选择“以管理员身份运行”。
2. 确认启动不触发 UAC；首次下载可能出现 SmartScreen，这属于 unsigned 预览的已知边界。
3. 确认标题显示“Windows W3-0”，主窗口、通知区域图标和默认关闭的悬浮图标设置正常。
4. 右键通知区域图标，确认菜单立即弹出，且订阅余额、统计任务、活动 Proxy Top 5、活动直连 Top 5、悬浮图标和退出入口同时存在。
5. 分别点击“查看订阅余额”“查看任务”或“开始新统计”“查看实时连接”和悬浮图标开关，确认菜单命令执行后进入既有窗口或切换既有状态，不新建重复进程。
6. 重复启动一次，确认仍只有一个进程和一个通知区域入口，并激活既有实例。
7. 关闭主窗口，确认应用继续在通知区域运行；再从菜单明确退出，确认窗口、图标和进程全部结束。

## 4. 业务回归

使用既有合成或脱敏测试条件快速确认：Controller 配置与 Credential Manager、Proxy/DIRECT 实时速度、核心累计、统计任务、30 日趋势、订阅配额、实时连接、通知区域 Top 5 和默认关闭的历史归因均可进入并正常刷新。

W3-0 没有修改业务模型。若任一 W0-W2D 能力回归、数据库无法恢复或凭据丢失，应停止验收；不要为了排障上传数据库、日志或真实响应。

## 5. 通过标准与反馈

通过需要同时满足：CI 全绿；artifact 只有 ZIP 与校验文件；SHA-256 一致；ZIP 使用单一顶层目录且无禁止内容；标准用户无提权启动；单实例、通知区域右键菜单、关闭隐藏与明确退出正常；W0-W2D 冒烟未发现回归。

反馈以下结果即可：

| 场景 | 通过 / 失败 / 未覆盖 | 备注 |
| --- | --- | --- |
| SHA-256 与资产结构 |  |  |
| 标准用户无提权启动 |  |  |
| 单实例与通知区域生命周期 |  |  |
| 通知区域右键菜单与命令 |  |  |
| W0-W2D 业务冒烟 |  |  |
| 是否观察到明显启动或运行异常 |  |  |

W3-0 通过后才能进入 W3-1 NSIS 安装生命周期；本指南结果不能替代首次安装、覆盖升级、卸载和重装门禁。
