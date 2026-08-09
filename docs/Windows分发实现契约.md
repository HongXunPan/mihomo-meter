# Windows 分发实现契约

## 1. 文档定位

- 状态：W3-0 已通过，当前进入 W3-1 安装生命周期
- 更新日期：2026-08-09
- 工程基线：[Windows 工程代码技术选型](Windows工程代码技术选型.md)
- 当前实机指南：[Windows 阶段 W3-1 实机指南](Windows阶段W3-1实机指南.md)
- 历史实机指南：[Windows 阶段 W3-0 实机指南](Windows阶段W3-0实机指南.md)

本文是源码仓 Windows 版本输入、统一程序载荷、便携 ZIP、NSIS 安装器、校验文件和预览工作流的公开真相源。父工作区维护 W3 阶段范围与放行结论；应用内版本检查和稳定 Release 只有进入 W3-2 后才能在本文扩展。

## 2. W3-1 范围与版本

W3-1 在已通过的 W3-0 便携打包基线上增加 unsigned NSIS 当前用户安装器、运行中操作阻断、覆盖升级、开始菜单、卸载和重装，不修改业务模型、数据目录、Credential Manager Target Name 或单实例身份。它不创建 MSIX、APPX、Tag、GitHub Release、所有用户安装、桌面快捷方式、服务、开机启动、计划任务或应用内更新入口。

PR 与 `main` push 的预览版本固定回退为 `0.0.0`；手动 workflow 允许输入无前导零的 `X.Y.Z`，用于两个连续版本的覆盖升级验收，但仍只上传预览 artifact。同一次调用必须把唯一版本输入传给 App 的 `Version`、`FileVersion`、`AssemblyVersion`、NSIS 版本资源和全部资产名，不允许脚本从文件名或 Git Tag 猜测版本。

## 3. 构建与打包职责

`scripts/validate_windows.ps1` 继续唯一负责静态检查、solution restore、Core 测试、App x64 Release 构建和 `dotnet publish`，发布目录固定为 `.codex-tmp/windows-publish`。它把相同版本传给构建与发布，检查可执行文件、PRI、非 MSIX 和系统 `winsqlite3.dll` 后调用打包脚本。

`scripts/package_windows.ps1` 只消费已经验证的发布目录，不执行 restore、build 或 publish。它检查可执行文件四段版本、必需 PRI、敏感文件和禁止扩展名，排除 PDB 后生成一份临时统一载荷；便携 ZIP 和 NSIS 安装器必须消费该同一载荷，完成后清理载荷目录。

`scripts/build_windows_installer.ps1` 只负责调用已锁定的 NSIS 编译器、以 `/INPUTCHARSET UTF8` 读取主脚本、传入版本/载荷/输出路径并复核安装器版本，不复制发布、测试或 ZIP 职责。NSIS 脚本固定放在 `platform/windows/installer/MihomoMeter.nsi`，其 UTF-8 中文和显式指定 UTF-8 的拆分 include 必须保持一致，不得引入额外插件。

## 4. 资产与内容契约

W3-1 输出目录固定为 `.codex-tmp/windows-package`，只包含：

```text
Mihomo-Meter-0.0.0-windows-x64-portable.zip
Mihomo-Meter-0.0.0-windows-x64-setup.exe
SHA256SUMS
```

ZIP 内使用单一顶层目录 `Mihomo Meter/`。ZIP 与安装器必须包含同一份 `MihomoMeter.Windows.App.exe`、WinUI PRI 和运行依赖，不包含 PDB、MSIX、APPX、日志、转储、签名密钥、设置、Profile、Controller Secret 或三套业务数据库。

`SHA256SUMS` 使用 UTF-8 无 BOM、按资产文件名排序，每行“小写 SHA-256、两个空格、资产文件名”的格式，固定包含 ZIP 和安装器两行，不建立第二份校验文件。

## 5. Actions 边界

Windows workflow 对 PR、`main` push 和手动触发继续使用只读 `contents: read` 权限。官方 Windows 2025 runner 预装 Chocolatey，工作流通过它安装固定 NSIS 3.12.0；PR/Push 执行默认 `0.0.0`，手动触发使用显式版本。工作流上传 `.codex-tmp/windows-package` 为名称带版本和提交 SHA 的 W3 预览 artifact，保留 14 天。

W3-1 workflow 不使用个人 Token，不请求 `contents: write`，不创建或覆盖 Tag、Release。Actions 成功只证明 Windows runner 上的静态检查、Core 测试、Release 构建、自包含发布、统一载荷、ZIP、NSIS 编译和 SHA-256 组装通过，不代表 Win10 22H2 实机安装、升级或卸载通过。

## 6. 安装与卸载生命周期

安装器固定 `RequestExecutionLevel user`、`SetShellVarContext current` 和 64 位 HKCU 卸载视图，卸载标识为 `com.HongXunPan.MihomoMeter`。首次安装显示目录选择页，默认目录为 `%LOCALAPPDATA%\Programs\Mihomo Meter`，也允许选择其他磁盘上的当前用户可写专用目录；磁盘或共享根目录、用户数据目录、不可写目录和非空目录必须被拒绝。安装器仍不提供所有用户作用域，只创建当前用户开始菜单与卸载入口；完成页允许用户立即运行应用。

安装、升级和卸载都通过系统 PowerShell 只读检查应用进程。应用仍运行时只允许用户从通知区域明确退出后重试或取消，不强制结束进程。首次安装写入只属于程序目录的隐藏所有权标记；升级从 HKCU 读取既有 `InstallLocation`、跳过目录选择并在原目录完整替换旧载荷，避免迁移时遗留两套程序。当前旧预览版的默认目录允许一次兼容升级并补写标记；后续只有注册表路径、主程序和标记一致时才允许递归清理或卸载。

如需迁移程序目录，用户应先卸载再重新安装并重新选择目录。卸载只删除已登记程序目录、开始菜单和 HKCU 卸载项，始终保留 `%LOCALAPPDATA%\HongXunPan\MihomoMeter` 与 Credential Manager 凭据。

便携 ZIP 与安装版运行同一程序、共享当前用户数据和单实例身份。它们可以保存在不同目录，但不能作为两套独立业务状态并行运行，也不宣称便携版数据完全便携。

## 7. 验证与放行

非 Windows 主机执行 `python3 scripts/validate_windows.py`，验证安装权限、默认目录、首次目录选择、升级锁定、程序目录所有权、当前用户注册表、禁止提权/强制结束/删除数据，以及 W3 脚本、工作流和既有工程契约。Windows CI 执行完整 PowerShell 门禁，并上传可人工下载的 ZIP、安装器与校验文件。

Win10 22H2 x64 标准用户按 W3-1 指南验证两个版本的 SHA-256、首次安装、运行中阻断、覆盖升级、同版本重装、开始菜单、卸载、数据与凭据保留、重装恢复、便携版共存、单实例、通知区域和 W0-W2D 业务回归。W3-1 只放行安装生命周期；不得据此宣称应用内更新或稳定 GitHub 分发可用。

## 8. 停止条件

出现以下任一情况立即停止并重新规划：安装、升级或卸载需要提权；安装器强制结束应用或运行中覆盖；首次安装不能选择其他磁盘；升级静默迁移或留下两套程序；未验证目录所有权便递归删除；固定身份、版本或载荷不一致；卸载删除用户数据或凭据；ZIP/安装器包含禁止内容；脚本重复 build/publish；工作流需要写权限或个人 Token；安装版与便携版业务口径分叉；W0-W2D 回归；W3-1 尚未通过便创建稳定 Release。
