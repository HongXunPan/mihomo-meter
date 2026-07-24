# Mihomo Meter

[![持续集成](https://github.com/HongXunPan/mihomo-meter/actions/workflows/ci.yml/badge.svg)](https://github.com/HongXunPan/mihomo-meter/actions/workflows/ci.yml)
[![许可证](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Mihomo Meter 是一款原生 macOS 状态栏应用，通过 Mihomo Controller API 统计真实经过代理出口的实时网速。

> 当前已完成 MVP-1 实时纵切；今日、总累计、统计记录点和订阅余额走势尚未实现。

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

## MVP-1 已实现

- 用户手动填写本机 Mihomo 服务地址和访问密钥
- 仅允许 `127.0.0.1` 或 `::1`
- 使用 `/version` 验证连接和鉴权
- 使用 `/proxies` 建立出口类型目录
- 使用 `/connections?interval=500` WebSocket 采集连接快照
- 独立展示 Proxy、DIRECT、REJECT 和未知实时速度
- 计算分类覆盖率
- 最近两个完整一秒窗口平滑
- 数据超过 2 秒未更新时先归零提示，持续 5 秒后才取消旧流并指数退避重连
- Controller 地址保存到应用设置，Secret 仅保存到 macOS Data Protection Keychain

应用不会读取 Clash Verge 配置文件或私有 IPC，也不会自动获取 Secret。

正式版本计划仅通过 GitHub Releases 分发经 Developer ID 签名和 Apple 公证的独立安装包，不上架 Mac App Store。

## 项目结构

```text
.
├── .github/                 # 公开协作模板与持续集成
├── MihomoMeter.xcodeproj/   # Xcode 工程
├── Sources/
│   ├── Application/         # 应用入口与生命周期
│   ├── Domain/              # 与界面无关的领域模型
│   ├── Infrastructure/      # Controller、WebSocket 与 Keychain
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

Xcode 的 Debug 和 Release 配置会通过公共 `Config.xcconfig` 读取本机 Team ID；不要把个人团队写回 `project.pbxproj`。然后在 Xcode 中选择 `MihomoMeter` Scheme 运行。工程启用 Keychain Sharing capability 以声明应用自身的默认 Keychain 访问组，不配置任何跨应用共享组。Data Protection Keychain 使用签名 App ID 隔离凭据；切换开发团队或签名身份后，需要为新的应用身份重新填写一次 Secret。

首次运行：

1. 确认 Mihomo 已启用本机 External Controller。
2. 点击状态栏中的 Mihomo Meter。
3. 手动填写回环 Mihomo 服务地址，例如 `127.0.0.1:9090`。
4. 手动填写访问密钥；Mihomo 未配置鉴权时可以留空。
5. 点击“连接”。

详细口径与异常状态见 [MVP-1 使用与统计口径](docs/MVP-1使用与统计口径.md)。

Debug 构建的脱敏诊断日志说明见[数据与隐私](docs/数据与隐私.md#debug-诊断日志)。

退出 Xcode GUI 后也可以构建。脚本默认只构建已签名的 Debug 应用，传入 `--run` 时在构建成功后启动：

```bash
scripts/build-debug.sh
scripts/build-debug.sh --run
```

脚本从已忽略的 `Config.local.xcconfig` 读取开发团队，并允许 Xcode 自动生成或下载 Data Protection Keychain 所需的 provisioning profile；构建完成后会检查实际签名权限。首次使用前仍需在本机登录 Xcode 并完成自动签名和开发证书配置。使用 `--run` 前应先退出正在运行的 Mihomo Meter，避免继续使用旧进程。

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
- [开发路线图](docs/路线图.md)
- [贡献指南](CONTRIBUTING.md)
- [安全策略](SECURITY.md)

## 贡献

提交修改前请阅读 [贡献指南](CONTRIBUTING.md)。缺陷报告和功能建议请使用仓库提供的 Issue 模板。

## 独立项目声明

Mihomo Meter 是独立社区项目，与 Mihomo、MetaCubeX 或 Clash Verge Rev 的维护团队不存在隶属或官方合作关系。相关名称仅用于描述兼容性。

## 许可证

本项目采用 [MIT License](LICENSE)。
