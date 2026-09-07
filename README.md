# Mihomo Meter

[![持续集成](https://github.com/HongXunPan/mihomo-meter/actions/workflows/ci.yml/badge.svg)](https://github.com/HongXunPan/mihomo-meter/actions/workflows/ci.yml)
[![Windows 构建与测试](https://github.com/HongXunPan/mihomo-meter/actions/workflows/windows.yml/badge.svg)](https://github.com/HongXunPan/mihomo-meter/actions/workflows/windows.yml)
[![许可证](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![应用下载量](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2FHongXunPan%2Fmihomo-meter%2Fbadges%2Fdownload-count.json&cacheSeconds=3600)](https://github.com/HongXunPan/mihomo-meter/releases)

[使用文档（Wiki）](https://github.com/HongXunPan/mihomo-meter/wiki) ·
[最新版本与下载](https://github.com/HongXunPan/mihomo-meter/releases/latest) ·
[问题反馈](https://github.com/HongXunPan/mihomo-meter/issues/new/choose)

Mihomo Meter 是一款面向 macOS 与 Windows 的桌面流量统计工具，帮助你查看真正经过代理的流量。它会明确区分 Proxy、DIRECT、REJECT 和无法可靠归属的未知流量，不会把未知或直连流量算进 Proxy。

## 下载走势

<a href="https://github.com/HongXunPan/mihomo-meter/releases">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/HongXunPan/mihomo-meter/badges/download-history-dark.svg">
    <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/HongXunPan/mihomo-meter/badges/download-history-light.svg">
    <img alt="Mihomo Meter 应用下载量走势图" src="https://raw.githubusercontent.com/HongXunPan/mihomo-meter/badges/download-history-light.svg">
  </picture>
</a>

## 下载与运行要求

请只从 [GitHub Releases](https://github.com/HongXunPan/mihomo-meter/releases/latest) 下载。Release 正文顶部提供按设备和安装方式命名的直接链接，不需要从 Assets 中判断架构缩写。

| 平台 | 系统要求 | 正式资产 | 安装提醒 |
| --- | --- | --- | --- |
| macOS | macOS 14 或更高版本；`v0.3.x` 是最后支持 macOS 13 的版本线 | Apple Silicon、Intel、Universal 三种 DMG | 固定自签名但未公证，首次打开需要处理 Gatekeeper 提示 |
| Windows | Windows 10 22H2 x64 或更高版本 | x64 当前用户安装版、x64 便携版 | 安装器未签名，可能出现“未知发布者”或 SmartScreen |

Windows 安装包不需要另行安装 .NET Runtime，也不要求管理员权限；便携版应完整解压后运行。

完整安装、校验、升级和卸载步骤见 Wiki 的[下载与安装](https://github.com/HongXunPan/mihomo-meter/wiki/%E4%B8%8B%E8%BD%BD%E4%B8%8E%E5%AE%89%E8%A3%85)。

## 为什么使用 Mihomo Meter

Mihomo 显示的总流量同时包含代理、直连和其他流量，不能直接回答“真正经过 Proxy 出口的流量是多少”。Mihomo Meter 会按实际出口分类，并把无法确认的部分保留为未知。

Mihomo Meter 是只读监控工具：

- 不内置或启动 Mihomo Core；
- 不提供节点、订阅或代理服务；
- 不修改系统代理、路由、节点、规则或代理模式；
- 不读取 Clash Verge Rev 私有进程间通信；
- 不抓包，不解密网络内容；
- 不把本机统计宣称为机场计费结果；
- 不连接局域网或公网 Controller，只接受 `127.0.0.1` 与 `::1`。

## 主要功能

### 分类流量与本地统计

- 独立展示 Proxy、DIRECT、REJECT 和未知实时速度与分类覆盖率；
- 平滑显示实时速度，连接中断后自动恢复；
- 保存分钟级分类流量、每日汇总、本机累计与多个秒表式 Proxy 统计任务；
- 支持随时开始和结束独立的 Proxy 流量统计任务。

### 实时连接与历史归因

- 分别查看 Proxy 与 DIRECT 活动连接、应用、主机名、双向速度、累计和时长；
- macOS 状态栏与 Windows 通知区域均提供 Proxy/DIRECT Top 5；
- 实时连接只保存在内存，连接消失后立即移除，不保留连接明细；
- 历史归因默认关闭，开启后可查看最近 30 天的应用榜、域名榜和趋势。

### 订阅余额

- 可直接查看当前运行订阅的剩余流量；
- 选择 Clash Verge Profile 目录后，可同时追踪多个远程订阅；
- 查询始终经过当前 Mihomo，本地代理不可用时不会绕过代理直连；
- 提供配额快照、套餐变化记录、不同时间范围的走势和预计耗尽时间。

### 桌面体验

- macOS 提供状态栏菜单，Windows 提供通知区域菜单和可选实时速度悬浮图标；
- 两个平台都可主动开启登录后静默启动，默认关闭；
- 设置页可导出经过隐私处理的诊断文件，方便反馈问题；
- 关闭统计窗口或主窗口后继续监控，只有状态栏或通知区域的“退出”会结束应用；
- 支持检查新版本，是否下载安装始终由用户决定。

## 快速开始

Mihomo Meter 不是代理客户端。开始前需要一个正在运行、能够开放 HTTP External Controller 的 Mihomo；Clash Verge Rev、Clash Nyanpasu、FlClash 和 Clash Party 等客户端通常已经内置 Mihomo。

1. 在代理客户端中启用 External Controller。
2. 将监听地址限制为 `127.0.0.1` 或 `::1`，使用固定端口，并取得 Controller Secret。
3. macOS 从状态栏菜单打开“设置…”；Windows 打开“设置 → Mihomo 连接”。
4. 填写例如 `127.0.0.1:9090` 的回环地址与 Secret，点击“连接”。
5. 界面显示“已连接”和 Mihomo 版本后，即可查看流量、连接分析和订阅余额。

Controller Secret 不是订阅链接、机场密码或节点密码。Mihomo Meter 没有手动输入订阅 URL 的字段；订阅应先导入代理客户端。零基础说明、常见客户端设置和 Profile 目录路径见[使用 Wiki](https://github.com/HongXunPan/mihomo-meter/wiki)。

## 隐私与安全

- 只连接本机的 Mihomo，不接受局域网或公网 Controller；
- Controller Secret 在 macOS 保存到登录钥匙串，在 Windows 保存到凭据管理器；
- 流量统计、订阅配额和用户主动开启的历史归因只保存在本机；
- 实时连接仅在内存中展示，连接结束后不会保留明细；
- 原始订阅地址不会作为普通设置或统计数据保存；
- 诊断文件只在用户主动操作时导出，也不会自动上传；
- 不抓包、不读取网络内容，也不会修改代理设置、路由、节点、规则或代理模式。

完整说明见[数据与隐私](docs/数据与隐私.md)。

## 帮助与反馈

- 使用说明与常见问题：[项目 Wiki](https://github.com/HongXunPan/mihomo-meter/wiki)
- 安装、升级与卸载：[下载与安装](https://github.com/HongXunPan/mihomo-meter/wiki/%E4%B8%8B%E8%BD%BD%E4%B8%8E%E5%AE%89%E8%A3%85)
- 缺陷与建议：[提交 Issue](https://github.com/HongXunPan/mihomo-meter/issues/new/choose)
- 安全问题：[私密报告漏洞](https://github.com/HongXunPan/mihomo-meter/security)
- 参与开发：[贡献指南](CONTRIBUTING.md)

## 许可证与独立声明

本项目采用 [MIT License](LICENSE)。

Mihomo Meter 是独立社区项目，与 Mihomo、MetaCubeX 或第三方客户端维护团队不存在隶属或官方合作关系。相关名称仅用于说明兼容方式。
