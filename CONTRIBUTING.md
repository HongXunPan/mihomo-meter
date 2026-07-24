# 贡献指南

感谢你参与 Mihomo Meter。

## 开发前提

- 能够运行 Xcode 26 的 macOS
- Xcode 26 或更高版本
- Swift 6

应用 Target 最低支持 macOS 13；测试 Target 因当前 Xcode XCTest 运行库要求使用 macOS 14。

项目不依赖第三方包。请勿为了局部功能引入未经讨论的框架、代码生成器或包管理脚本。

## 开始开发

1. Fork 并克隆仓库。
2. 从 `main` 创建目标明确的分支。
3. 使用 Xcode 打开 `MihomoMeter.xcodeproj`。
4. 修改前先阅读相关公开文档和现有实现。
5. 为领域逻辑补充或更新测试。

## 本地签名与诊断

- 在 `MihomoMeter` Target 的 `Signing & Capabilities` 中选择自己的开发团队并保持自动签名。
- 不要将 macOS 签名身份强制设为 `-`；ad-hoc 临时签名会导致 Keychain 在重新构建后重复请求授权。
- 个人 Team ID 和用户级 Xcode 配置不得提交到开源仓库。
- Debug 诊断日志位于应用沙盒，不得复制到仓库；提交日志用于 Issue 前必须再次确认其中不含本机敏感信息。

## 验证

本地已完成开发团队配置时，可以在不启动 Xcode GUI 的情况下构建或运行 Debug 应用：

```bash
scripts/build-debug.sh
scripts/build-debug.sh --run
```

提交 Pull Request 前至少执行：

```bash
xcrun swift format lint --recursive --strict Sources Tests

xcodebuild \
  -project MihomoMeter.xcodeproj \
  -scheme MihomoMeter \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build test
```

成功标准：

- Swift 格式检查无输出并返回退出码 `0`
- 命令退出码为 `0`
- 应用 Target 编译通过
- `MihomoMeterTests` 全部通过

## 代码要求

- 保持原生 Swift 与系统框架优先。
- 注释使用简体中文，只解释必要的约束与原因。
- 不记录 Controller Secret、订阅地址、节点信息或完整连接目标。
- 不把 DIRECT 或未知流量静默合并到 Proxy。
- 不在界面层直接实现连接分类和累计算法。
- 不提交本机构建产物、用户级 Xcode 配置、日志或真实响应数据。

## Pull Request

Pull Request 应说明：

1. 解决的问题。
2. 采用的方案和边界。
3. 用户可见变化。
4. 已执行的验证。
5. 隐私、安全或兼容性影响。

一次 Pull Request 只处理一个主题。大规模重构应先通过 Issue 讨论分阶段方案。
