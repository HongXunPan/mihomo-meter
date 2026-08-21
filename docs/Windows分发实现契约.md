# Windows 分发实现契约

## 1. 文档定位

- 状态：W3-0 与 W3-1 已通过，W3-2 更新检查与稳定发布正在实施
- 更新日期：2026-08-09
- 工程基线：[Windows 工程代码技术选型](Windows工程代码技术选型.md)
- 当前实机指南：[Windows 阶段 W3-2 实机指南](Windows阶段W3-2实机指南.md)
- 历史实机指南：[Windows 阶段 W3-1 实机指南](Windows阶段W3-1实机指南.md)

本文是源码仓 Windows 版本输入、更新描述、统一程序载荷、便携 ZIP、NSIS 安装器和 GitHub Release 接入的公开真相源。父工作区维护 W3 范围与最终放行结论；源码仓只实现已确认契约，不把 draft 演练或 CI runner 结果写成稳定分发已通过。

## 2. W3-2 范围与版本

W3-2 在 W3-1 安装生命周期上增加人工更新检查、Windows 平台描述文件、Latest Release 下载指引和统一正式发布工作流，不修改业务模型、数据目录、Credential Manager Target Name 或安装范围。`v0.6.1` 单实例热修复只把依赖非打包应用路径的 AppInstance 注册替换为固定会话 Mutex 与当前用户 Named Pipe；应用仍只比较 Windows 实际版本并打开原始 Release 页面，不自动下载、安装、退出或重启。

应用版本、构建号和新构建资产继续使用无前导零的 `X.Y.Z`；发布 Tag 使用 `vX.Y.Z`，表示一次稳定发布快照。工作流允许选择 `macos`、`windows` 或 `all`：本次构建平台的实际版本等于 Tag 版本，未构建平台继续引用较早正式版本，旧资产不得复制、改名或伪装为当前 Tag 版本。

PR 与 `main` push 的 Windows 预览仍回退为 `0.0.0`；手动 Windows 预览 workflow 只上传 artifact。只有统一 Release workflow 可以创建 Tag 与 Release，且固定接收版本、目标平台和 `draft` / `stable` 模式。当前首个含双平台描述的快照允许只构建 Windows：macOS 实际版本继续停留在 `0.5.1`，不因 Windows 发版抬升版本或触发更新。

## 3. Windows 构建与打包职责

`scripts/validate_windows.ps1` 唯一负责静态检查、solution restore、Core 测试、App x64 Release 构建和 `dotnet publish`，发布目录固定为 `.codex-tmp/windows-publish`。它把相同版本传给 App、文件版本、程序集版本和打包入口，不允许 workflow 建立第二套发布口径。

`scripts/package_windows.ps1` 只消费已验证发布目录，检查可执行文件版本、PRI、敏感文件和禁止扩展名，排除 PDB 后生成同一载荷的便携 ZIP 与 NSIS 安装器。输出目录 `.codex-tmp/windows-package` 仍只包含版本化 ZIP、安装器和两行 `SHA256SUMS`；安装版与便携版不得产生不同业务实现。

`scripts/build_windows_installer.ps1` 继续只负责锁定 NSIS、校验带 BOM 的 UTF-8 源码、传入版本/载荷/输出路径并复核安装器版本。W3-2 不改变当前用户安装、首次可选目录、升级锁定已登记目录、开始菜单、卸载入口、运行中阻断和用户数据保留契约。

## 4. 平台描述与下载指引

每个 draft 或稳定 Release 必须包含：

```text
appcast.xml
macos-release.json
windows-release.json
SHA256SUMS
```

`appcast.xml` 继续只服务 Sparkle。两个 JSON 均使用 schema v1，分别记录平台、实际版本、来源 Tag、原始 Release 页面，以及带固定中文用途、文件名、HTTPS 下载地址和小写 SHA-256 的资产列表。macOS 固定列出 Apple Silicon、Intel 与通用 DMG；Windows 固定列出 x64 安装版与便携版。

本次构建平台必须从当前产物生成新描述，文件名中的版本、内嵌版本、来源 Tag 和描述版本必须一致。未构建平台优先复制上一正式 Release 的小型描述文件；其中的下载地址必须继续指向原 Release，不下载、复制或重新上传旧二进制。若上一正式版本早于平台描述契约，工作流只允许根据该 Release 的资产清单和 `SHA256SUMS` 严格补建描述；固定资产缺失、校验和格式异常或来源不一致时立即失败。仅构建 Windows 时还要原样沿用上一正式 `appcast.xml`，保证既有 macOS Sparkle 固定 Latest 地址继续提供相同版本，不向 Mac 用户推送本次 Windows 更新。

Release 正文顶部必须由两个 JSON 确定性生成下载矩阵，链接文字固定面向普通用户说明“Apple Silicon Mac（M 系列芯片）”“Intel Mac”“通用 Mac（不确定机型时选择）”“Windows x64 安装版”和“Windows x64 便携版”。用户不需要展开 Assets 或从 `arm64`、`x86_64` 文件名判断下载项；未更新平台要明确显示“沿用来源 Tag 的稳定版本”。

Windows 应用固定读取：

```text
https://github.com/HongXunPan/mihomo-meter/releases/latest/download/windows-release.json
```

客户端只接受 schema v1、`platform=windows`、严格 `X.Y.Z`、与版本一致的来源 Tag，以及本仓库 HTTPS Release 页面和资产地址。描述无效、超时、限流、重定向越界或网络失败只显示可恢复状态；只有实际版本高于当前应用时才显示更新，并由用户主动打开描述中的原始 Release 页面。

## 5. Actions 与权限边界

`.github/workflows/windows.yml` 继续对 PR、`main` push 和手动预览使用 `contents: read`，在 Windows 2025 runner 安装固定 NSIS 3.12.0，复用 `validate_windows.ps1` 并上传保留 14 天的 W3 预览 artifact。它不创建 Tag 或 Release。

`.github/workflows/release.yml` 是唯一正式发布入口，固定拆分为预检、按需 macOS 构建、按需 Windows 构建和最终发布任务。工作流级权限默认为 `contents: read`，只有最终发布任务使用 `contents: write`；签名 Secrets 只进入 macOS 构建任务，不进入 Windows 或发布正文。

只读预检拒绝非 `main`、非法版本和不支持的模式；draft 模式还拒绝既有 Tag/Release，平台任务并行复用既有测试与打包入口，最终创建候选 Release。Draft Release 仅对拥有发布写权限的任务可见，因此 stable 模式的 Draft、prerelease 和目标提交检查固定放在唯一的最终发布任务，并在下载候选前执行；通过后才复核资产清单、两个描述、下载矩阵和 SHA-256，再原样提升为 Latest，不重新构建、上传或替换资产。工作流只使用仓库 `GITHUB_TOKEN`，不使用个人 Token。

## 6. 安装、隐私与信任边界

Windows 安装器固定 `RequestExecutionLevel user`、当前用户 Shell/注册表范围和 x64 HKCU 卸载视图。首次安装默认 `%LOCALAPPDATA%\Programs\Mihomo Meter` 并允许其他磁盘的当前用户可写空专用目录；升级继续使用已登记位置，迁移必须先卸载再重装。安装器不默认开启登录启动；卸载只清理精确指向当前安装目录的登录启动值，并始终保留 `%LOCALAPPDATA%\HongXunPan\MihomoMeter` 和 Credential Manager 凭据。详细边界见[登录后启动实现契约](登录后启动实现契约.md)。

`windows-release.json` 是公开版本索引，不包含 Controller 地址、Secret、Profile、订阅 URL、主机名、应用名、流量、设置或数据库。它通过 GitHub HTTPS 帮助用户找到人工下载页面，但没有独立签名，不能作为自动下载或安装信任根；Windows unsigned 安装器仍可能显示“未知发布者”和 SmartScreen。

## 7. 验证与放行

非 Windows 主机执行 `python3 scripts/validate_windows.py`、平台描述脚本单元测试、发布脚本语法检查、工作流定向静态门禁和 `git diff --check`。Windows CI 继续执行完整 PowerShell 门禁，并验证新增 Core 测试、App x64 Release 构建、描述文件生成、ZIP、安装器与 SHA-256。

W3-2 采用两段式门禁。首发前以 `platform=windows` 完成 draft 演练，确认 Windows 新描述和资产、从 `v0.5.1` 元数据补建的 macOS 描述、原样沿用的 appcast、跨平台下载矩阵，以及 draft 不进入 Latest；候选不得包含旧 DMG。Win10 22H2 x64 标准用户还要验证当前版本展示、固定描述暂不可用时的故障隔离、重复点击、安装、覆盖升级、通知区域、单实例和 W0-W2D 回归。单实例必须双向覆盖安装版、便携版及不同便携目录，第二次启动恢复既有窗口且不建立第二个进程。前置结果记录且用户明确确认后，才允许原样提升同版本 Windows-only stable；发布后立即验证同版本显示和打开正确页面。低版本发现更新延后到下一次 Windows 稳定发布作为发布后门禁，不增加可替换更新地址或创建后删除临时稳定 Release。

## 8. 停止条件

出现以下任一情况立即停止并重新规划：更新检查影响监控；客户端按 Latest Tag 而非 Windows 描述判断；描述允许非本仓库或非 HTTPS 地址；旧二进制被复制、改名或重新上传；macOS 实际版本被错误抬升或 appcast 宣告本次 Windows 版本；旧 Release 元数据不足仍继续继承；下载矩阵与描述不一致；本次新资产的内嵌版本、文件名和平台描述不一致；Release workflow 请求个人 Token 或把写权限授予构建任务；安装、升级或卸载需要提权；用户数据、凭据或敏感内容进入描述、日志或 Release；前置门禁未记录或用户未确认便触发首个稳定发布。
