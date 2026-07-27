# 贡献指南

感谢你参与 Mihomo Meter。

## 开发前提

- 能够运行 Xcode 26 的 macOS
- Xcode 26 或更高版本
- Swift 6

应用 Target 最低支持 macOS 13；测试 Target 因当前 Xcode XCTest 运行库要求使用 macOS 14。

项目固定依赖 Sparkle 2.9.4 处理应用内更新，并使用 Yams 6.2.2 类型化解析用户授权目录中的 `profiles.yaml`。Yams 不得扩展为通用配置加载入口。请勿为了局部功能继续引入未经讨论的框架、代码生成器或包管理脚本。

## 开始开发

1. Fork 并克隆仓库。
2. 从 `main` 创建目标明确的分支。
3. 使用 Xcode 打开 `MihomoMeter.xcodeproj`。
4. 修改前先阅读相关公开文档和现有实现。
5. 开始编码前阅读并遵守 [Swift 代码规范](docs/Swift代码规范.md)。
6. 为领域逻辑补充或更新测试。

## 本地签名与诊断

- 在仓库根目录创建被 Git 忽略的 `Config.local.xcconfig`，填写 `DEVELOPMENT_TEAM = 你的 Apple Developer Team ID`；Xcode 通过公共 `Config.xcconfig` 加载本机配置。
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

日常修改 Swift 源码或测试后，默认只执行严格格式检查：

```bash
xcrun swift format lint --recursive --strict Sources Tests
```

该检查只证明代码格式符合规范，不代表应用已编译或测试已通过。涉及脚本、配置或文档时，还应执行与变更直接相关的语法检查和定向复核，不扩大到无关门禁。

完整无签名构建与测试属于重型门禁，不作为每次任务完成或普通提交前的默认本地验证。所有分支 Push 和 Pull Request 都会由持续集成自动执行；用户明确要求本机完整验证时，可执行：

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
- Profile 目录只能在用户明确授权后以只读安全范围访问；持久化层只能保存 UID、脱敏展示字段和应用本地 HMAC 指纹，不得保存原始订阅地址。
- 不把 DIRECT 或未知流量静默合并到 Proxy。
- 不提交本机构建产物、用户级 Xcode 配置、日志或真实响应数据。

## Pull Request

Pull Request 应说明：

1. 解决的问题。
2. 采用的方案和边界。
3. 用户可见变化。
4. 已执行的验证。
5. 隐私、安全或兼容性影响。

一次 Pull Request 只处理一个主题。大规模重构应先通过 Issue 讨论分阶段方案。
