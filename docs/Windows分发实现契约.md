# Windows 分发实现契约

## 1. 文档定位

- 状态：W3-0 已通过，当前进入 W3-1 安装生命周期
- 更新日期：2026-08-09
- 工程基线：[Windows 工程代码技术选型](Windows工程代码技术选型.md)
- 最近实机指南：[Windows 阶段 W3-0 实机指南](Windows阶段W3-0实机指南.md)

本文是源码仓 Windows 版本输入、发布目录、便携 ZIP、校验文件和预览工作流的公开真相源。父工作区维护 W3 阶段范围与放行结论；NSIS 安装生命周期、应用内版本检查和稳定 Release 只有进入 W3-1、W3-2 后才能在本文扩展。

## 2. W3-0 范围

W3-0 只把现有非打包、自包含 `win-x64` 发布目录组装成版本化便携 ZIP 和 `SHA256SUMS`，继续作为 GitHub Actions artifact 分发。它不创建 NSIS、MSIX、APPX、Tag、GitHub Release 或自动更新入口。

预览构建固定使用版本 `0.0.0`。正式版本仍由后续手动发布工作流提供无前导零的 `X.Y.Z` 输入；同一次调用必须把唯一版本输入传给 App 的 `Version`、`FileVersion`、`AssemblyVersion` 和打包脚本，不允许脚本从文件名或 Git Tag 猜测版本。

## 3. 构建与打包职责

`scripts/validate_windows.ps1` 继续唯一负责静态检查、solution restore、Core 测试、App x64 Release 构建和 `dotnet publish`，发布目录固定为 `.codex-tmp/windows-publish`。它把相同版本传给构建与发布，检查可执行文件、PRI、非 MSIX 和系统 `winsqlite3.dll` 后调用打包脚本。

`scripts/package_windows.ps1` 只消费已经验证的发布目录，不执行 restore、build 或 publish。它检查可执行文件的四段文件版本、必需 PRI、敏感文件和禁止扩展名，排除 PDB，再按排序后的相对路径写入固定时间戳 ZIP；该职责边界避免 CI 与本地出现两套发布参数。

## 4. 资产与内容契约

W3-0 输出目录固定为 `.codex-tmp/windows-package`，只包含：

```text
Mihomo-Meter-0.0.0-windows-x64-portable.zip
SHA256SUMS
```

ZIP 内使用单一顶层目录 `Mihomo Meter/`，避免用户解压时把大量运行文件散落到当前目录。ZIP 必须包含 `MihomoMeter.Windows.App.exe` 和至少一个 WinUI PRI，不包含 PDB、MSIX、APPX、日志、转储、签名密钥、设置、Profile、Controller Secret 或三套业务数据库。

`SHA256SUMS` 使用 UTF-8 无 BOM、每行“小写 SHA-256、两个空格、资产文件名”的格式。W3-0 只有便携 ZIP，因此只包含一行；W3-1 加入安装器后再扩展为两个资产，不建立第二份校验文件。

## 5. Actions 边界

Windows workflow 对 PR、`main` push 和手动触发继续使用只读 `contents: read` 权限。它固定执行 `validate_windows.ps1 -Version 0.0.0`，上传 `.codex-tmp/windows-package` 为名称带提交 SHA 的 W3 预览 artifact，保留 14 天。

W3-0 workflow 不使用个人 Token，不请求 `contents: write`，不创建或覆盖 Tag、Release。Actions 成功只证明 Windows runner 上的静态检查、135 项以上 Core 测试、Release 构建、自包含发布、ZIP 和 SHA-256 组装通过，不代表 Win10 22H2 实机启动或未来安装生命周期通过。

## 6. 安装连续性预留

W3-1 固定采用当前用户安装，推荐目录 `%LOCALAPPDATA%\Programs\Mihomo Meter`，只创建开始菜单和卸载入口，不默认创建桌面快捷方式。安装和升级不要求管理员权限；卸载保留 `%LOCALAPPDATA%\HongXunPan\MihomoMeter` 与 Credential Manager 凭据。

便携 ZIP 仍使用既有用户数据目录和 Credential Manager，只表示无需安装，不宣称程序与数据完全便携。W3-0 不提前写 NSIS 脚本、注册表或快捷方式代码，但资产根目录和可执行文件名称从本阶段起视为升级连续性输入。

## 7. 验证与放行

非 Windows 主机执行 `python3 scripts/validate_windows.py`，只验证 W3 文件、工作流、打包标记和既有工程契约。Windows CI 执行完整 PowerShell 门禁，并上传可人工下载的 ZIP 与校验文件。

Win10 22H2 x64 标准用户按 W3-0 指南验证 SHA-256、解压结构、无提权启动、单实例、通知区域、关闭隐藏、明确退出和 W0-W2D 业务回归。W3-0 只放行打包基线；不得据此宣称 NSIS、覆盖升级、卸载、应用内更新或稳定 GitHub 分发可用。

## 8. 停止条件

出现以下任一情况立即停止并重新规划：版本在 PE 与资产名之间不一致；ZIP 缺失 PRI 或包含用户数据、凭据、日志、PDB、签名材料、MSIX/APPX；打包脚本再次执行 build/publish；工作流需要写权限或个人 Token；标准用户启动必须提权；W0-W2D 既有能力回归；W3-1 尚未通过便创建稳定 Release。
