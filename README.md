# Mihomo Meter

[![持续集成](https://github.com/HongXunPan/mihomo-meter/actions/workflows/ci.yml/badge.svg)](https://github.com/HongXunPan/mihomo-meter/actions/workflows/ci.yml)
[![许可证](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[使用文档（Wiki）](https://github.com/HongXunPan/mihomo-meter/wiki) ·
[版本发布与下载（GitHub Releases）](https://github.com/HongXunPan/mihomo-meter/releases)

Mihomo Meter 是一款原生 macOS 状态栏应用，通过 Mihomo Controller API 统计真实经过代理出口的实时网速和本机累计流量。

> 当前已完成 MVP-1 实时纵切和 MVP-2 本机统计闭环；订阅余额走势尚未实现。

## 为什么开发

Mihomo 的内核总流量同时包含代理、直连和其他内核承载流量，不能直接回答“真正经过 Proxy 出口的流量是多少”。

Mihomo Meter 的目标是基于连接级数据进行分类，并明确区分：

- Proxy
- DIRECT
- REJECT
- 无法可靠归属的未知流量

未知流量不会被推测性地计入 Proxy。

## 项目边界

Mihomo Meter 是只读监控工具：

- 不内置或启动 Mihomo Core
- 不修改系统代理、路由、节点或规则
- 不读取 Clash Verge Rev 私有进程间通信
- 不抓包，不解密网络内容
- 不把本机统计宣称为机场计费结果

## 实现计划

- [x] 阶段 0：工程骨架与 Mihomo Controller API 数据验证
- [x] 阶段 1A：MVP-1 实时代理流量纵切
- [x] 阶段 1B：MVP-2 本机分类流量统计闭环
- [ ] 阶段 2：机场订阅余额走势
- [ ] 阶段 3：本机 Proxy 流量与机场配额对账分析

已勾选项目表示当前源码和测试已经实现；未勾选项目不代表发布时间承诺。各阶段的子任务与完成状态见[开发路线图](docs/路线图.md)。

## 已实现

- 用户手动填写本机 Mihomo 服务地址和访问密钥
- 仅允许 `127.0.0.1` 或 `::1`
- 使用 `/version` 验证连接和鉴权
- 使用 `/configs` 只读展示运行模式、TUN 和基础运行配置
- 使用 `/proxies` 建立出口类型目录
- 使用 `/connections?interval=500` WebSocket 采集连接快照
- 独立展示 Proxy、DIRECT、REJECT 和未知实时速度
- 计算分类覆盖率
- 展示当前可确认出口和活动连接命中的规则类型，不读取规则匹配内容
- 最近两个完整一秒窗口平滑
- 数据超过 2 秒未更新时先归零提示，持续 5 秒后才取消旧流并指数退避重连
- 服务地址保存到应用设置，访问密钥（Secret）仅保存到 macOS 登录钥匙串
- 使用系统 SQLite3 保存分钟级分类流量、每日汇总和本机累计
- 状态栏弹层快速展示活动任务，并通过独立统计窗口管理全部秒表式 Proxy 流量统计任务
- 正常退出或崩溃恢复时，将仍在进行的任务收口为“已中断”
- 清空本地统计时删除账本与任务，但保留服务地址和访问密钥（Secret）
- 在弹层底部展示应用版本，并通过 Sparkle 检查、下载和安装 Ed25519 签名更新

应用不会读取 Clash Verge 配置文件或私有 IPC，也不会自动获取 Secret。

正式版本仅通过 GitHub Releases 分发自签名、未公证的 DMG，不上架 Mac App Store。
每个版本提供 Apple Silicon、Intel 和 Universal 三种 DMG，首次打开需要按
[发布与安装](docs/发布与安装.md)处理 macOS Gatekeeper 提示。
`0.1.x` 首次升级到包含 Sparkle 的 `0.2.x` 仍需手动下载 DMG；之后应用会在启动时检查更新，
并在用户确认后使用 Universal DMG 完成安装，不会后台静默安装。

## 项目结构

```text
.
├── .github/                 # 公开协作模板与持续集成
├── MihomoMeter.xcodeproj/   # Xcode 工程
├── Sources/
│   ├── Application/         # 应用入口与生命周期
│   ├── Domain/              # 与界面无关的领域模型
│   ├── Infrastructure/      # Controller、WebSocket、SQLite、Keychain 与 Sparkle
│   └── Presentation/        # 状态栏和弹层界面
├── Tests/                   # 单元测试
├── scripts/                 # 构建与运行辅助脚本
└── docs/                    # 公开架构、隐私和路线图
```

## 运行要求

- macOS 13 或更高版本

## 开发环境

- 能够运行 Xcode 26 的 macOS
- Xcode 26 或更高版本
- Swift 6

当前维护环境为 Xcode 26.5 和 Swift 6.3.2。

## 本地运行

```bash
git clone git@github.com:HongXunPan/mihomo-meter.git
cd mihomo-meter
open MihomoMeter.xcodeproj
```

首次构建前，在仓库根目录创建不会提交到 Git 的 `Config.local.xcconfig`：

```xcconfig
DEVELOPMENT_TEAM = 你的 Apple Developer Team ID
```

Xcode 的 Debug 和 Release 配置会通过公共 `Config.xcconfig` 读取本机 Team ID；不要把个人团队写回 `project.pbxproj`。然后在 Xcode 中选择 `MihomoMeter` Scheme 运行。Controller Secret 保存到登录钥匙串，并由 macOS 根据应用签名控制读取权限；切换开发团队或签名身份后，可能需要授权或重新填写一次 Secret。

首次运行：

1. 确认 Mihomo 已启用本机 External Controller。
2. 点击状态栏中的 Mihomo Meter。
3. 手动填写回环 Mihomo 服务地址，例如 `127.0.0.1:9090`。
4. 手动填写访问密钥；Mihomo 未配置鉴权时可以留空。
5. 点击“连接”。

实时口径与异常状态见 [MVP-1 使用与统计口径](docs/MVP-1使用与统计口径.md)，
本机累计和统计任务见 [MVP-2 秒表式流量统计](docs/MVP-2秒表式流量统计.md)。

Debug 构建的脱敏诊断日志说明见[数据与隐私](docs/数据与隐私.md#debug-诊断日志)。

退出 Xcode GUI 后也可以构建。脚本默认只构建已签名的 Debug 应用，传入 `--run` 时在构建成功后启动：

```bash
scripts/build-debug.sh
scripts/build-debug.sh --run
```

脚本从已忽略的 `Config.local.xcconfig` 读取开发团队，并允许 Xcode 完成本机开发签名；构建完成后会检查沙盒、网络和钥匙串相关签名权限。首次使用前仍需在本机登录 Xcode 并完成自动签名和开发证书配置。使用 `--run` 前应先退出正在运行的 Mihomo Meter，避免继续使用旧进程。

命令行验证：

```bash
xcodebuild \
  -project MihomoMeter.xcodeproj \
  -scheme MihomoMeter \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build test
```

## 文档

- [架构概览](docs/架构概览.md)
- [Swift 代码规范](docs/Swift代码规范.md)
- [数据与隐私](docs/数据与隐私.md)
- [MVP-1 使用与统计口径](docs/MVP-1使用与统计口径.md)
- [MVP-2 秒表式流量统计](docs/MVP-2秒表式流量统计.md)
- [发布与安装](docs/发布与安装.md)
- [开发路线图](docs/路线图.md)
- [贡献指南](CONTRIBUTING.md)
- [安全策略](SECURITY.md)

## 贡献

提交修改前请阅读 [贡献指南](CONTRIBUTING.md)。缺陷报告和功能建议请使用仓库提供的 Issue 模板。

## 独立项目声明

Mihomo Meter 是独立社区项目，与 Mihomo、MetaCubeX 或 Clash Verge Rev 的维护团队不存在隶属或官方合作关系。相关名称仅用于描述兼容性。

## 许可证

本项目采用 [MIT License](LICENSE)。
应用内更新使用开源 [Sparkle](https://github.com/sparkle-project/Sparkle)，适用其
[项目许可声明](https://github.com/sparkle-project/Sparkle/blob/2.9.4/LICENSE)。
