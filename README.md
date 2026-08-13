# Mihomo Meter

[![持续集成](https://github.com/HongXunPan/mihomo-meter/actions/workflows/ci.yml/badge.svg)](https://github.com/HongXunPan/mihomo-meter/actions/workflows/ci.yml)
[![Windows 构建与测试](https://github.com/HongXunPan/mihomo-meter/actions/workflows/windows.yml/badge.svg)](https://github.com/HongXunPan/mihomo-meter/actions/workflows/windows.yml)
[![许可证](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![macOS DMG 下载量](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2FHongXunPan%2Fmihomo-meter%2Fbadges%2Fdownload-count.json&cacheSeconds=3600)](https://github.com/HongXunPan/mihomo-meter/releases)

[使用文档（Wiki）](https://github.com/HongXunPan/mihomo-meter/wiki) ·
[最新版本与下载](https://github.com/HongXunPan/mihomo-meter/releases/latest) ·
[问题反馈](https://github.com/HongXunPan/mihomo-meter/issues/new/choose)

Mihomo Meter 是一款通过 Mihomo Controller API 统计真实代理流量的原生 macOS 与 Windows 桌面应用。它明确区分 Proxy、DIRECT、REJECT 和无法可靠归属的未知流量，不会为了让数字完整而把未知或直连流量计入 Proxy。

当前正式版为 **v0.7.0**。macOS 与 Windows 已完成正式分发，流量格式化和代理类型基础分类由同一份 Rust 共享核心提供，并保留平台原生实现作为异常时的懒回退。

## 下载与运行要求

请只从 [GitHub Releases](https://github.com/HongXunPan/mihomo-meter/releases/latest) 下载。Release 正文顶部提供按设备和安装方式命名的直接链接，不需要从 Assets 中判断架构缩写。

| 平台 | 系统要求 | 正式资产 | 安装提醒 |
| --- | --- | --- | --- |
| macOS | macOS 14 或更高版本；`v0.3.x` 是最后支持 macOS 13 的版本线 | Apple Silicon、Intel、Universal 三种 DMG | 固定自签名但未公证，首次打开需要处理 Gatekeeper 提示 |
| Windows | Windows 10 22H2 x64 或更高版本 | x64 当前用户安装版、x64 便携版 | 安装器未签名，可能出现“未知发布者”或 SmartScreen |

Windows 安装包为自包含应用，不需要另行安装 .NET Runtime。安装版默认写入 `%LOCALAPPDATA%\Programs\Mihomo Meter`，不请求管理员权限；便携版应完整解压后运行。两种形态共享当前用户数据并实行跨目录单实例。

完整安装、校验、升级和卸载步骤见 Wiki 的[下载与安装](https://github.com/HongXunPan/mihomo-meter/wiki/%E4%B8%8B%E8%BD%BD%E4%B8%8E%E5%AE%89%E8%A3%85)。

## 为什么开发与项目边界

Mihomo 的内核总流量同时包含代理、直连和其他内核承载流量，不能直接回答“真正经过 Proxy 出口的流量是多少”。Mihomo Meter 基于连接快照与实际出口类型分类，并把无法确认的部分保留为未知。

Mihomo Meter 是只读监控工具：

- 不内置或启动 Mihomo Core；
- 不提供节点、订阅或代理服务；
- 不修改系统代理、路由、节点、规则或代理模式；
- 不读取 Clash Verge Rev 私有进程间通信；
- 不抓包，不解密网络内容；
- 不把本机统计宣称为机场计费结果；
- 不连接局域网或公网 Controller，只接受 `127.0.0.1` 与 `::1`。

## 核心能力

### 分类流量与本地统计

- 通过 `/version` 验证连接和鉴权，通过 `/configs`、`/proxies` 与 `/connections` 读取必要状态；
- 独立展示 Proxy、DIRECT、REJECT 和未知实时速度与分类覆盖率；
- 使用最近两个完整一秒窗口平滑速度，数据过期时归零并自动重连；
- 保存分钟级分类流量、每日汇总、本机累计与多个秒表式 Proxy 统计任务；
- 正常退出或异常恢复时，将尚未结束的统计任务收口为“已中断”。

### 实时连接与历史归因

- 分别查看 Proxy 与 DIRECT 活动连接、应用、主机名、双向速度、累计和时长；
- macOS 状态栏与 Windows 通知区域均提供 Proxy/DIRECT Top 5；
- 实时连接只保存在内存，连接消失后立即移除，不保留连接明细；
- 历史归因默认关闭，用户明确开启后才保存最近 30 天的“应用名称 × 完整主机名 × Proxy 上下行日聚合”；
- 提供应用榜、域名榜、交叉筛选、识别覆盖率和独立 30 天趋势。

### 订阅余额

- 当前运行订阅轻量模式只观察 Mihomo 暴露的唯一有效配额候选，不读取订阅 URL；
- 用户主动选择 Clash Verge Profile 目录后，可按 UID 追踪多个远程 Profile；
- 原始订阅地址只在内存中参与查询，本地仅保存 HMAC-SHA256 指纹；
- 主动查询只接受 HTTPS，并始终经过当前 Mihomo 的 mixed、HTTP 或 SOCKS 本地代理；代理不可用时不会静默直连；
- 提供配额快照、周期与套餐变化事件、24 小时/7 天/30 天/12 月趋势和受质量门禁约束的预计耗尽。

### 桌面体验与更新

- macOS 使用原生状态栏菜单、设置窗口和统计工作区；
- Windows 使用 WinUI 3 主窗口、原生通知区域菜单和可选实时速度悬浮图标；
- 关闭统计窗口或主窗口后继续监控，只有状态栏或通知区域的“退出”会结束应用；
- macOS 使用 Sparkle 验签、下载并在用户确认后安装更新；
- Windows 只检查平台实际版本并打开本项目 Release 页面，不自动下载、安装、退出或重启。

## 快速开始

Mihomo Meter 不是代理客户端。开始前需要一个正在运行、能够开放 HTTP External Controller 的 Mihomo；Clash Verge Rev、Clash Nyanpasu、FlClash 和 Clash Party 等客户端通常已经内置 Mihomo。

1. 在代理客户端中启用 External Controller。
2. 将监听地址限制为 `127.0.0.1` 或 `::1`，使用固定端口，并取得 Controller Secret。
3. macOS 从状态栏菜单打开“Mihomo 连接设置…”；Windows 打开“设置 → Mihomo 连接”。
4. 填写例如 `127.0.0.1:9090` 的回环地址与 Secret，点击“连接”。
5. 界面显示“已连接”和 Mihomo 版本后，即可查看流量、连接分析和订阅余额。

Controller Secret 不是订阅链接、机场密码或节点密码。Mihomo Meter 没有手动输入订阅 URL 的字段；订阅应先导入代理客户端。零基础说明、常见客户端设置和 Profile 目录路径见[使用 Wiki](https://github.com/HongXunPan/mihomo-meter/wiki)。

## 架构与数据边界

```text
Mihomo Controller API
        │
        ├── macOS：Swift / SwiftUI / AppKit / 系统服务
        ├── Windows：C# / .NET 10 / WinUI 3 / Win32 / 系统服务
        └── SharedCore：Rust 1.97.1 / 标准库 / 稳定 C ABI
```

View、窗口生命周期、Controller 解码、网络、异步调度、Keychain、Credential Manager 与 SQLite 保留在平台层。共享核心只承载经过双端差分和实机门禁确认的纯算法；当前包含十进制流量缩放与代理类型基础分类。共享调用失败或遇到未识别类型时只执行一次对应平台原生回退，不影响最终展示。

| 数据 | macOS | Windows |
| --- | --- | --- |
| Controller Secret | 登录钥匙串 | Credential Manager 的 `com.HongXunPan.MihomoMeter.controller` |
| 业务数据库 | 应用沙盒 `Library/Application Support/Mihomo Meter/` | `%LOCALAPPDATA%\HongXunPan\MihomoMeter\` |
| Controller 地址 | 应用设置 | 同目录 `settings.json` |
| 本地诊断 | 沙盒内限量轮换日志 | 正常运行不创建持久日志；仅显式启动控制台输出粗粒度状态 |

三个 SQLite 数据库各自负责分类流量、连接日归因和订阅配额。Controller Secret、原始订阅 URL、节点、完整 URL、目标 IP/端口、连接 ID、进程完整路径、规则内容和响应正文不得进入普通设置、数据库、日志或 Fixture。完整边界见[数据与隐私](docs/数据与隐私.md)。

## 开发与验证

### macOS

开发环境需要能够运行 Xcode 26 的 macOS、Xcode 26 或更高版本和 Swift 6。应用与测试 Target 最低支持 macOS 14。

```bash
git clone git@github.com:HongXunPan/mihomo-meter.git
cd mihomo-meter
open MihomoMeter.xcodeproj
```

首次构建前在仓库根目录创建被 Git 忽略的 `Config.local.xcconfig`：

```xcconfig
DEVELOPMENT_TEAM = 你的 Apple Developer Team ID
```

直接从 Xcode 构建前先执行 `scripts/build_shared_core_macos.sh`。命令行 Debug 构建与前台运行入口为：

```bash
scripts/build-debug.sh
scripts/build-debug.sh --run
```

Swift 源码或测试的日常默认验证是严格格式检查：

```bash
xcrun swift format lint --recursive --strict Sources Tests
```

### 共享核心

仓库通过 `rust-toolchain.toml` 固定 Rust 1.97.1，只依赖标准库。共享核心或适配器变更需执行：

```bash
python3 scripts/validate_shared_core.py
scripts/test_shared_core_macos.sh
xcrun swift format lint --recursive --strict SharedCore/Adapters/Swift
```

### Windows

完整开发环境需要 Windows 10 22H2 x64 或更高版本、.NET SDK 10.0.302、Windows 10 SDK 10.0.19041.0 或更高版本和 NSIS 3.12.0。非 Windows 主机只执行静态契约检查：

```bash
python3 scripts/validate_windows.py
```

真实 Windows 环境的完整入口为：

```powershell
pwsh -File scripts/validate_windows.ps1
```

完整无签名 macOS 构建测试和 Windows 构建打包属于重型门禁，默认交由分支 Push、Pull Request 与发布 CI。详细环境、签名、验证矩阵和代码要求见[贡献指南](CONTRIBUTING.md)。

## 文档与贡献

- 普通用户：[使用 Wiki](https://github.com/HongXunPan/mihomo-meter/wiki)
- 构建、签名与分发：[发布与安装](docs/发布与安装.md)
- 跨端实现：[跨平台共享核心技术方案](docs/跨平台共享核心技术方案.md)
- macOS 分层：[架构概览](docs/架构概览.md)
- Windows 工程：[Windows 工程代码技术选型](docs/Windows工程代码技术选型.md)
- Windows 分发：[Windows 分发实现契约](docs/Windows分发实现契约.md)
- 隐私边界：[数据与隐私](docs/数据与隐私.md)
- 开发约束：[贡献指南](CONTRIBUTING.md)与[Swift 代码规范](docs/Swift代码规范.md)
- 缺陷和建议：[Issue 模板](https://github.com/HongXunPan/mihomo-meter/issues/new/choose)
- 安全问题：[私密漏洞报告](https://github.com/HongXunPan/mihomo-meter/security)

一次 Pull Request 只处理一个主题，并说明问题、方案、用户可见变化、验证结果及隐私或兼容性影响。

## 许可证与独立声明

本项目采用 [MIT License](LICENSE)。

应用内更新使用开源 [Sparkle 2.9.4](https://github.com/sparkle-project/Sparkle/blob/2.9.4/LICENSE)，macOS Profile YAML 解析使用开源 [Yams 6.2.2](https://github.com/jpsim/Yams/blob/6.2.2/LICENSE)。Windows 依赖及用途由[贡献指南](CONTRIBUTING.md)和工程文件锁定。

Mihomo Meter 是独立社区项目，与 Mihomo、MetaCubeX 或第三方客户端维护团队不存在隶属或官方合作关系。相关名称仅用于说明兼容方式。
