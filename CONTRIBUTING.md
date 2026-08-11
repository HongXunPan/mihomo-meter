# 贡献指南

感谢你参与 Mihomo Meter。

## 开发前提

macOS 工程需要：

- 能够运行 Xcode 26 的 macOS
- Xcode 26 或更高版本
- Swift 6

应用与测试 Target 均最低支持 macOS 14。

Windows 工程需要 Windows 10 22H2 x64 或更高版本、.NET SDK 10.0.302、Windows 10 SDK 10.0.19041.0 或更高版本，以及 NSIS 3.12.0；`makensis.exe` 可以从 `PATH` 解析，也可以通过 `-MakeNsisPath` 显式传入。W2C 使用 `Microsoft.Data.Sqlite.Core` 10.0.10、系统 `winsqlite3.dll` 和仅用于 `profiles.yaml` 的 `YamlDotNet` 18.1.0，不引入图表库；`MSTest.Sdk` 4.3.2 只用于测试。非 Windows 主机只能运行静态契约检查。

跨平台共享核心固定使用 Rust 1.97.1 和标准库。P1.2b 双端运行态门禁已于 2026-08-11 通过，P1.3-1 已建立受保护主路径路由、自动回退与诊断基础设施，但三类生产格式器仍保持影子模式。详细边界见[跨平台共享核心技术方案](docs/跨平台共享核心技术方案.md)与[P1.3 方案](docs/跨平台共享核心P1.3受保护主路径技术方案.md)。rustup 必须能提供仓库锁定的主机工具链和目标架构；不得提交 `.build/`、`SharedCore/target/`、静态库或 DLL。

项目固定依赖 Sparkle 2.9.4 处理应用内更新，并使用 Yams 6.2.2 类型化解析用户授权目录中的 `profiles.yaml`。Yams 不得扩展为通用配置加载入口。请勿为了局部功能继续引入未经讨论的框架、代码生成器或包管理脚本。

## 开始开发

1. Fork 并克隆仓库。
2. 从 `main` 创建目标明确的分支。
3. 使用 Xcode 打开 `MihomoMeter.xcodeproj`。
4. 修改前先阅读相关公开文档和现有实现。
5. 开始编码前阅读并遵守 [Swift 代码规范](docs/Swift代码规范.md)。
6. 为领域逻辑补充或更新测试。

## 本地签名与诊断

- 在仓库根目录创建被 Git 忽略的 `Config.local.xcconfig`，填写 `DEVELOPMENT_TEAM = 你的 Apple Developer Team ID`；应用与测试 Target 均通过公共 `Config.xcconfig` 加载共享核心和本机配置。
- 不要把个人 Team ID 写入或提交到 `MihomoMeter.xcodeproj/project.pbxproj`，其他用户级 Xcode 配置同样不得提交。
- `MihomoMeter` Target 不启用 Keychain Sharing，也不得添加跨应用共享组；Controller Secret 只保存到当前用户的登录钥匙串。
- 不要将 macOS 签名身份强制设为 `-`；传统钥匙串根据应用代码签名控制访问，切换开发团队或签名身份后可能需要授权或重新填写一次 Secret。
- 正式 DMG 固定使用 `com.HongXunPan.MihomoMeter` 与自签名证书 `Mihomo Meter By HongXunPan`。替换该证书会改变指定要求，必须作为凭据迁移破坏性变更处理。
- XCTest 宿主必须保持 `MIHOMO_METER_TEST_MODE=1`，不得装配生产监控、访问真实 Keychain 或写入应用诊断日志。
- Debug 诊断日志位于应用沙盒，不得复制到仓库；提交日志用于 Issue 前必须再次确认其中不含本机敏感信息。

## 验证

本地已完成开发团队配置时，可以在不启动 Xcode GUI 的情况下构建或运行 Debug 应用：

```bash
scripts/build-debug.sh
scripts/build-debug.sh --run
```

Debug 构建失败时，脚本会在终端末尾重新输出真实错误上下文，并将完整构建日志保留到 `.build/Diagnostics/`，可供脱敏后复制反馈。构建成功时不保留该次诊断日志。

直接从 Xcode GUI 构建前，先运行 `scripts/build_shared_core_macos.sh` 生成当前宿主架构静态库；`scripts/build-debug.sh` 已自动执行这一步。构建 universal 正式包时必须同时提供 `arm64 x86_64`，不得复用单架构产物。

`--run` 会直接以前台进程执行 `.app` 内的可执行文件，不通过 `open` 脱离 Shell；应用退出后命令才返回，按 `Ctrl-C` 或关闭当前终端也会终止本次 Debug 应用。需要脱离终端运行时，先执行不带参数的构建命令，再按输出的 `open` 命令启动。

日常修改 Swift 源码或测试后，默认只执行严格格式检查：

```bash
xcrun swift format lint --recursive --strict Sources Tests
```

共享核心或适配器变更还需执行：

```bash
python3 scripts/validate_shared_core.py
scripts/test_shared_core_macos.sh
xcrun swift format lint --recursive --strict SharedCore/Adapters/Swift
```

Swift format 检查只证明代码格式符合规范；共享核心脚本还会构建 Rust 静态库，并让真实 macOS 格式化器与共享核心对统一向量执行差分。Windows 差分与 DLL 加载由 Windows CI 的完整入口验证。涉及脚本、配置或文档时，还应执行与变更直接相关的语法检查和定向复核，不扩大到无关门禁。

Windows 变更至少执行跨平台静态契约检查：

```bash
python3 scripts/validate_windows.py
```

完整 Windows 构建、发布和静态检查由 Windows CI 执行；具备 Windows 环境时可运行：

```powershell
pwsh -File scripts/validate_windows.ps1
```

该脚本按固定顺序执行静态契约、Core 单元测试、App Release 构建、非打包自包含发布、统一载荷、便携 ZIP、NSIS 安装器和 SHA-256 组装。`makensis.exe` 不在 `PATH` 时可通过 `-MakeNsisPath` 显式传入。W0–W3-1 历史门禁见各阶段指南；W3-2 自动验证和实机步骤见[Windows 阶段 W3-2 实机指南](docs/Windows阶段W3-2实机指南.md)，公开资产与版本描述边界见[Windows 分发实现契约](docs/Windows分发实现契约.md)。

完整 macOS 无签名构建与测试属于重型门禁，不作为每次任务完成或普通提交前的默认本地验证。所有分支 Push 和 Pull Request 都会由 macOS 持续集成自动执行；用户明确要求本机完整验证时，可执行：

```bash
bash -n \
  scripts/build-release-dmg.sh \
  scripts/generate-download-badge-json.sh \
  scripts/generate-sparkle-appcast.sh \
  scripts/generate-release-notes.sh \
  scripts/sign-sparkle-framework.sh \
  scripts/smoke-test-release-launch.sh \
  scripts/test-generate-download-badge-json.sh \
  scripts/test-generate-release-notes.sh \
  scripts/verify-sparkle-release.sh
PYTHONDONTWRITEBYTECODE=1 python3 scripts/test_release_platform_descriptors.py
scripts/test-generate-download-badge-json.sh
scripts/test-generate-release-notes.sh

xcodebuild \
  -project MihomoMeter.xcodeproj \
  -scheme MihomoMeter \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build test
```

成功标准：

- 日常严格格式检查无输出并返回退出码 `0`
- 发布说明脚本语法检查与隔离 Git 仓测试通过
- 完整门禁命令退出码为 `0`
- 应用 Target 编译通过
- `MihomoMeterTests` 全部通过
- 正式 DMG 构建会在宿主机支持的架构上执行无生产副作用的真实启动冒烟

提交 Pull Request 前应确认对应提交的远端持续集成完整通过；远端门禁仍在运行或未执行时，不得表述为完整验证通过。

正式版本的证书准备、GitHub Secrets 和工作流说明见[发布与安装](docs/发布与安装.md)。Pull Request 不应执行正式发布工作流。

## 代码要求

所有 Swift 源码和测试必须遵守 [Swift 代码规范](docs/Swift代码规范.md)；模块职责与代码落点以[架构概览](docs/架构概览.md)为准。

- 不记录 Controller Secret、订阅地址、节点信息或完整连接目标。
- 连接元数据只允许在 Mihomo 适配器中提取主机名，以及从最外层 `.app`、进程名或路径文件名得到的应用名称；完整进程路径必须在进入领域层前丢弃。连接 ID、URL、IP、端口、进程路径、节点和规则内容不得写入日志、Fixture 或持久化层。
- 可选日归因只允许在用户明确开启后写入独立 `connection-analytics.sqlite3`，字段限于本地日期、应用名称、完整主机名和 Proxy 上下行聚合；不得扩成连接明细或复用核心流量数据库。
- 应用与域名趋势必须至少带一个精确归因维度，只从既有日聚合按日期查询并补齐零值；不得为趋势保存目标、筛选、图表点或新增连接级字段。趋势查询失败不得写零值或中断核心流量总账。
- Profile 目录只能在用户明确授权后以只读安全范围访问；持久化层只能保存 UID、脱敏展示字段和应用本地 HMAC 指纹，不得保存原始订阅地址。
- 不把 DIRECT 或未知流量静默合并到 Proxy。
- Windows 核心流量只允许写入 `%LOCALAPPDATA%\HongXunPan\MihomoMeter\traffic.sqlite3` 的分类聚合，不得保存连接、节点、目标、规则或 Secret；数据库故障不得停止实时监控。
- Windows 机场配额只允许写入独立 `quota.sqlite3`；原始订阅 URL、Token、正文、完整响应头、Provider 键、UA 原文和 Secret 不得持久化，查询必须经过当前 Mihomo。
- Windows W2D-1 只允许 Mihomo JSON Converter 向领域层输出脱敏主机名、应用名称和容错开始时间；完整进程路径必须在适配器内丢弃。连接 ID 只作内存差值与稳定行键，主机名、应用、ID、目标 IP/端口、节点、规则和链路不得写入日志、Fixture 或持久化层。
- 不提交本机构建产物、用户级 Xcode 配置、日志或真实响应数据。

## Pull Request

Pull Request 应说明：

1. 解决的问题。
2. 采用的方案和边界。
3. 用户可见变化。
4. 已执行的验证。
5. 隐私、安全或兼容性影响。

一次 Pull Request 只处理一个主题。大规模重构应先通过 Issue 讨论分阶段方案。
