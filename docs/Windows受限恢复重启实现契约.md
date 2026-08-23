# Windows 受限恢复重启实现契约

## 1. 文档定位

- 状态：源码实现完成，待 Windows CI 与 Windows 10 22H2 x64 实机验收
- 更新日期：2026-08-23
- 适用范围：非打包、自包含的 Mihomo Meter Windows 主应用

本文是 Windows 系统崩溃或挂起后受限恢复重启的公开实现真相源。它不定义应用内更新重启，也不引入守护进程、服务、计划任务、管理员权限或第三方依赖。

系统机制采用 Win32 [`RegisterApplicationRestart`](https://learn.microsoft.com/windows/win32/api/winbase/nf-winbase-registerapplicationrestart)。Windows Error Reporting 只在应用发生未处理崩溃或被判定无响应时向用户提供重启选择，并要求应用在故障前至少运行 60 秒；应用不绕过该系统条件主动拉起自身。

## 2. 触发与排除条件

注册标志固定为 `RESTART_NO_PATCH | RESTART_NO_REBOOT`，因此只保留崩溃和挂起恢复，不参与补丁安装或系统重启。应用不调用 Windows App SDK 的主动 Restart API，也不注册 Recovery 回调。

以下状态不得调用恢复重启：

- 用户从通知区域明确退出；
- Controller 配置错误或鉴权失败；
- 普通网络断开、stale、休眠、锁屏或网络恢复；
- 更新检查、下载页面跳转、补丁安装或系统重启；
- 应用服务与窗口生命周期尚未装配完成的初始化失败。

配置、鉴权与网络错误继续由既有连接状态机表达，不能转换为进程级重启条件。

## 3. 启动与注册时序

1. `Program` 先完成当前会话单实例判定；带恢复参数的次实例直接退出，不前置既有窗口。
2. 主实例读取恢复状态并验证一次性令牌。未知、重复、过期或时间窗内的恢复参数直接结束本次进程。
3. 普通启动或获准的恢复启动继续走同一 App、服务、窗口与通知区域装配链路，不恢复任意页面、输入或连接目标。
4. `App.OnLaunched` 全部装配成功后才注册当前进程；初始化期间的异常不会形成恢复循环。
5. 用户明确退出时，先调用 `UnregisterApplicationRestart` 并清除待用令牌，再收口账本和服务。

注册命令行只追加 `--system-recovery-restart=<令牌>`。令牌使用随机 GUID 的 32 位十六进制格式，不携带页面、文件、地址、Secret 或业务参数。

## 4. 单次与时间窗限制

恢复状态保存到 `%LOCALAPPDATA%\HongXunPan\MihomoMeter\recovery-restart.json`，版本 1 只包含：

- 待用令牌；
- 注册 UTC 时间；
- 最近一次获准恢复启动的 UTC 时间。

每个令牌只能消费一次，并在注册 30 分钟后失效。首次获准恢复启动后进入滚动 10 分钟窗口：窗口内不注册新的系统恢复；应用持续存活至窗口结束时才重新注册。这样即使恢复后的进程再次崩溃或挂起，也不会形成连续重启。

状态使用同目录临时文件后覆盖写入。状态缺失允许普通启动；状态损坏、写入失败、系统注册失败或带恢复参数却无法验证状态时一律关闭本次恢复能力，不阻断普通主应用，也不放宽限流。

## 5. 分层与隐私

- Domain：`CrashRecoveryRestartPolicy` 负责参数、一次性令牌、30 分钟有效期和 10 分钟窗口。
- Application：`CrashRecoveryRestartCoordinator` 编排状态、延迟注册、系统调用和明确退出注销。
- Infrastructure：JSON 状态存储和 Win32 Application Restart P/Invoke。
- Presentation：不增加设置项、提示框或业务状态，不复制恢复规则。

状态文件不是业务账本，不得加入 Controller 地址、Credential、订阅/Profile 标识、连接目标、页面状态、错误原文或诊断事件。固定阶段码可以进入当前会话的隐私收缩诊断导出，但随机令牌和文件路径不得导出。

## 6. 验证边界

Core 自动测试至少覆盖普通启动、匹配令牌首次放行、窗口内第二次恢复抑制、令牌不匹配或过期拒绝，以及窗口结束后重新注册。静态门禁锁定必需文件、注册标志、状态路径、参数前缀和明确退出注销。

非 Windows 主机只运行 `python3 scripts/validate_windows.py`。完整编译和 Core 测试交由 Windows CI；最终必须在 Windows 10 22H2 x64 标准用户环境分别验证：运行至少 60 秒后的崩溃恢复选择、挂起恢复选择、10 分钟内二次故障不重启、窗口结束后重新具备恢复资格、明确退出不重启、状态损坏安全降级，以及安装版与便携版均不提权。
