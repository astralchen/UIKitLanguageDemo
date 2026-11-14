# Xcode 原生工程与官方 MCP 迁移记录

2026-11-14 最新验收：Apple 官方 `xcrun mcpbridge` / `xcode-tools 24939` 的 `BuildProject` 构建成功；`GetTestList` 发现 18 项、全部启用；`RunSomeTests` 使用这 18 个实际 ID，18 passed、0 failed、0 skipped、0 expected failures、0 not run。结果见 `verification/official-mcp-tests.json`、`.txt` 和 `official-mcp-console.txt`。

工程最初由 Xcode 原生 iOS App 模板创建（Storyboard / Swift / XCTest）。该版本官方 MCP 无创建工程工具，因此创建使用 Xcode 原生 UI；随后全部业务源码、资源与测试通过官方 MCP 写入。没有复制旧工程的手写 project.pbxproj。应用最低 iOS 15.0，测试目标 iOS 15.6，Swift 6 / MainActor。

初始 14 个应用 Swift 文件与六项 XCTest 文件的逐字节迁移哈希保留在 `MIGRATION.json.initialMigrationSourceMatches`。之后依次加入 Table/Flow、Compositional、Bundle App 语言偏好与 Scene 状态恢复。当前全部 Swift 与 String Catalog 的 SHA-256 位于 `currentSourceFiles`；配置哈希在 `currentProjectConfigurationFiles`。String Catalog 当前为 30 个 key，支持 en、zh-Hans、ar。

当前 17 项单元测试包含最初六项、四项 Table/Flow、两项 Compositional、一项 Bundle 偏好、四项 NSUserActivity 恢复；另有一项真实系统 Settings UI 测试。新恢复测试重新创建 UIWindow 与页面，覆盖两个导航栈、Tab、Page、Split、草稿、选择和列表位置，并检查无效数据、分 Scene 检查点、迟到／重复交付。UI 测试实际改变 App 系统语言、断言旧进程终止，然后验证系统交回 activity 后的详情与组合列表恢复，最后还原原语言选项。截图和文本附件保存在 `verification/restoration-ui/`。

测试计划包含单元与 UI 两个目标，禁用并行，不附加测试调试器。复用现有 iPhone 17 Pro / iOS 26.5（07EFF63F-CD81-40CE-B872-428175F5D3C2），没有为本次验证创建或重启模拟器。App Run 的 LLDB 配置保留。

两个测试目标 Debug/Release 的四项 `OTHER_CODE_SIGN_FLAGS=--verbose=2` 继续保留，未关闭签名。UI Runner 的本机 SDK 动态库缺失通过测试环境的 `DYLD_LIBRARY_PATH=$(PLATFORM_DIR)/Developer/usr/lib` 处理，没有修改生产 App 路径。签名校验见 `verification/restoration-signature-verification.json`。

历史六项、十项、十二项、十三项官方结果分别保存在 `verification/official-mcp-original-six-tests.*`、`official-mcp-list-ten-tests.*`、`official-mcp-compositional-twelve-tests.*` 和 `official-mcp-system-thirteen-tests.*`。历史空 UI 目标的 RunAllTests 输出不是本次验收结果。

本次运行平台为 iPhone 17 Pro / iOS 26.5。真机、iOS 15/16 和 iPad 展开分栏未在本轮验证；Page 仅横向单页 scroll，状态恢复支持示例的双列 Split 和一项一组的正交分页。详细范围见 [STATE_RESTORATION.md](STATE_RESTORATION.md)、[LIST_LOCALIZATION.md](LIST_LOCALIZATION.md)、[COMPOSITIONAL_LAYOUT.md](COMPOSITIONAL_LAYOUT.md) 与 [SYSTEM_LANGUAGE.md](SYSTEM_LANGUAGE.md)。
