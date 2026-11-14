# 签名修复与官方 MCP 验收

> 六项签名验收为历史记录；列表扩展后的最新验收为官方 MCP RunSomeTests 23/23（含 iPad 双窗口三列系统重启测试），见 verification/official-mcp-tests.json。

2026-11-14（Asia/Shanghai）。

最终验收使用 Apple 官方 `xcode-tools` MCP 服务器（版本 24939）的 `RunSomeTests`：六项全部 Passed，failed / skipped / expectedFailures / notRun 均为 0。测试本体耗时约 5.54 秒，模拟器启动和构建时间另计。

## 问题与定位

原失败发生在 `UIKitLanguageDemoTests.xctest` 的 CodeSign 步骤，错误为 `No such file or directory`。清理构建目录后仍然复现；启用签名的命令行构建也复现，因此没有将它简单归因于 MCP 或缓存。

失败命令在 `--sign -` 后带有空参数。对独立的测试包副本进行参数对照：传入空字符串参数时返回 1，并输出完全相同的错误；改用有效的 `--verbose=2` 参数后返回 0，签名成功。详见 `verification/signing-argument-repro.json`。

## 工程修复

在以下两个测试目标的 Debug / Release 配置中设置：

```
OTHER_CODE_SIGN_FLAGS = --verbose=2
```

- UIKitLanguageDemoTests
- UIKitLanguageDemoUITests

这是正常的签名日志选项，使本机构建环境不再向 codesign 传入空参数。保留自动签名，未设置 `CODE_SIGNING_ALLOWED=NO`，未关闭系统安全设置，未依赖手工预签测试产物。用于排查的自定义 entitlements 文件已撤销，测试目标的 entitlements 保持默认空值。

14 个应用 Swift 文件和包含六项 XCTest 的 Swift 文件均与迁移前逐字节一致。SHA-256 记录见 `MIGRATION.json`。

## 验证证据

- `verification/official-mcp-original-six-tests.json`：最初六项签名修复验收；`official-mcp-tests.json` 为最新 23 项结果。
- `verification/official-mcp-original-six-tests.txt`：最初六项摘要；`official-mcp-tests.txt` 为最新摘要。
- `verification/codesign-build-evidence.txt`：官方测试构建实际执行的签名命令与签名成功输出。
- `verification/signature-verification.json`：测试 bundle 严格签名校验，以及宿主应用 deep / strict 校验，退出码均为 0。
- `verification/signing-argument-repro.json`：独立副本的空参数错误对照。

本次验收没有使用其他测试工具的结果代替官方 MCP。此前的模拟器构建工具复核只作为迁移过程的历史记录。

## 模拟器复用

沿用已有 `iPhone 17 Pro` 运行目标，设备标识为 `07EFF63F-CD81-40CE-B872-428175F5D3C2`。拿到六项通过结果后，没有再次触发测试、创建新模拟器或重启设备。后续需要验证时继续选择这台已有设备；不为重复验证创建新设备。

本次环境为 iOS 26.5 Simulator。真机及 iOS 15/16 未在本轮运行验证。键盘焦点检查仍为可选模式，默认六项回归不主动唤起系统键盘。

最新状态恢复验收继续保留签名，App、单元测试包和 UI Runner 的严格校验见 `verification/restoration-signature-verification.json`。本机 UI Runner 的 `lib_TestingInterop.dylib` 查找路径修正仅放在测试计划中，说明见 `STATE_RESTORATION.md`。

iPad 扩展的 App、单元测试包与 UI Runner 严格签名校验见 `verification/ipad-signature-verification.json`，测试计划继续启用签名并关闭并行克隆。
