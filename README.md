# Mihomo Meter

[![持续集成](https://github.com/HongXunPan/mihomo-meter/actions/workflows/ci.yml/badge.svg)](https://github.com/HongXunPan/mihomo-meter/actions/workflows/ci.yml)
[![许可证](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![DMG 下载量](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2FHongXunPan%2Fmihomo-meter%2Fbadges%2Fdownload-count.json&cacheSeconds=3600)](https://github.com/HongXunPan/mihomo-meter/releases)

[使用文档（Wiki）](https://github.com/HongXunPan/mihomo-meter/wiki) ·
[版本发布与下载（GitHub Releases）](https://github.com/HongXunPan/mihomo-meter/releases)

Mihomo Meter 是一款原生 macOS 状态栏应用，通过 Mihomo Controller API 统计真实经过代理出口的实时网速、本机累计流量和机场订阅剩余流量走势。

> 当前已完成 MVP-1、MVP-2，以及阶段 2.1 至 2.4 的订阅配额账本、轻量追踪、Profile 身份管理和多 Profile 主动查询；高级趋势与阶段 2 完整验收仍未完成。

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
- [x] 阶段 2.1：订阅配额领域与独立账本
- [x] 阶段 2.2：当前运行订阅轻量追踪
- [x] 阶段 2.3：指定 Profile 只读授权与身份映射
- [x] 阶段 2.4：多 Profile 主动查询
- [ ] 阶段 2.5：高级趋势与完整验收

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
- 清空 Proxy 本地统计时删除流量账本与任务，但保留服务地址和访问密钥（Secret）
- 连接成功后每 5 分钟只读查询 `/providers/proxies`，只接受唯一有效的 `subscriptionInfo`
- 用户明确确认后，以本地 UUID 记录“当前运行订阅”；零个、多个候选或来源变化时自动暂停
- 使用独立的 `quota.sqlite3` 保存机场原始配额快照、周期和 24 小时、7 天、30 天走势
- 状态栏弹层直接展示剩余流量卡片和走势图，完整统计窗口通过侧边栏切换 Proxy 流量与订阅余额
- 经用户明确选择后，以只读权限访问 Clash Verge Profile 目录并类型化解析 `profiles.yaml`
- 使用 Profile UID 维持改名和订阅地址重置前后的身份连续性；原始订阅地址只在内存中参与查询准备
- 订阅地址仅以应用本地 HMAC-SHA256 指纹写入额度账本，指纹密钥保存在 macOS 登录钥匙串
- 指定 Profile 可独立选择 1、3、6、12 或 24 小时查询间隔，不跟随 Clash Verge 自动刷新周期
- 通过当前 Mihomo 的 mixed、HTTP 或 SOCKS 本地代理主动发起 HTTPS 订阅请求；代理不可用时不会静默直连
- 主动查询复用 Mihomo 的 `global-ua`（缺失时使用默认值 `clash.meta`），只解析兼容的 `Subscription-Userinfo` 响应头并丢弃正文，使用单并发、随机抖动、有限退避和手动查询冷却保护机场服务
- 状态栏弹层以单开手风琴展示多个 Profile，默认只展开当前 Profile；完整统计窗口以自适应卡片同屏展示并支持单项或全部查询
- Profile 管理入口提供授权、重选和停止访问；目录变化只协调身份，URL 变化由独立调度器按新地址重新查询
- 在弹层底部展示应用版本，并通过 Sparkle 检查、下载和安装 Ed25519 签名更新

当前运行订阅轻量模式不会读取 Clash Verge 配置文件或私有 IPC，不接触订阅 URL，也不会自动获取 Secret。它无法识别 Profile UID 或可靠感知同一运行来源背后的 Profile 切换，因此只适合用户确认仅使用一个订阅 Profile 的场景。指定 Profile 模式需要用户明确授予 Profile 目录只读权限，以 Profile UID 识别和选择订阅，并按 Mihomo Meter 的独立周期通过当前 Mihomo 本地代理查询配额。

正式版本仅通过 GitHub Releases 分发自签名、未公证的 DMG，不上架 Mac App Store。
每个版本提供 Apple Silicon、Intel 和 Universal 三种 DMG，首次打开需要按
[发布与安装](docs/发布与安装.md)处理 macOS Gatekeeper 提示。
README 顶部的下载量徽章汇总所有正式版本 DMG 资产的下载事件，不包含更新清单、校验文件、
草稿或预发布版本，也不代表唯一用户数或安装量。
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
│   ├── Infrastructure/      # Controller、Profile YAML、SQLite、Keychain 与 Sparkle
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

若要启用当前运行订阅轻量追踪，请在连接成功后查看状态栏弹层中的“订阅余额”：只有 Mihomo 恰好暴露一个有效配额候选时才会出现确认入口。确认后应用按自己的 5 分钟观察周期记录；出现零个、多个候选或来源变化时会暂停并要求再次确认。

若要启用指定 Profile 追踪，请打开完整统计窗口并切换到“订阅余额”，点击“管理 Profile”：

1. 选择 Clash Verge 的 Profile 目录，并确认只读授权。
2. 从解析出的远程 Profile 中选择需要追踪的 UID。
3. 为指定 Profile 选择独立查询间隔；该间隔不跟随 Clash Verge 的自动刷新设置。
4. Profile 目录改名或原子替换后，应用会自动重读；移除授权会立即停止目录观察。
5. 保持 Mihomo 已连接且 `/configs` 暴露 mixed、HTTP 或 SOCKS 代理端口；应用会按所选周期查询，也可在弹层或统计窗口手动查询。

主动查询只接受 HTTPS，并始终经过当前 Mihomo 本地代理。查询失败会保留最近有效快照；每日自动重试次数受限，不会因失败持续请求机场。当前阶段尚未完成套餐变化事件、完整清除能力和阶段 2 人工界面验收。

实时口径与异常状态见 [MVP-1 使用与统计口径](docs/MVP-1使用与统计口径.md)，
本机累计和统计任务见 [MVP-2 秒表式流量统计](docs/MVP-2秒表式流量统计.md)。

本地脱敏诊断日志及用户反馈入口说明见[数据与隐私](docs/数据与隐私.md#本地诊断日志)。

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
- [订阅配额架构](docs/订阅配额架构.md)
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
Profile YAML 解析使用开源 [Yams](https://github.com/jpsim/Yams)，适用其
[项目许可声明](https://github.com/jpsim/Yams/blob/6.2.2/LICENSE)。
