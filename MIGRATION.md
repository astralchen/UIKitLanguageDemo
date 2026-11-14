# Xcode 原生工程与官方 MCP 迁移记录

当前生成符号迁移：38 项文案经 AppText 接入 Xcode 原生生成资源，保留 iOS 15 旧路径及英文回退。构建成功；25 项全量验收 24 passed / 1 failed，全部 23 项单元测试与单窗口 UI 用例通过，双窗口 UI 最新复验仍受 AX 超时阻塞。没有将本轮标记为全绿。源码均通过官方 XcodeWrite 写入；当前哈希见 MIGRATION.json。

原始全量与复验见 verification/official-mcp-tests.json 和 official-mcp-symbols-ipad-recheck.json。iOS 15 仅完成最低部署、弱链接和旧路径检查，未在该运行时执行。

以下为生成符号迁移前的 iPad 扩展历史记录：

2026-11-14 历史验收：Apple 官方 `xcrun mcpbridge` / `xcode-tools 24939` 的 `BuildProject` 构建成功，`GetTestList` 发现 23 项且全部启用，`RunSomeTests` 按这 23 个 ID 完整执行：23 passed、0 failed、0 skipped、0 expected failures、0 not run。原始结果见 verification/official-mcp-ipad-twenty-three-tests.json / .txt 和 official-mcp-ipad-twenty-three-console.txt。

本轮复用已有 iPad Pro 13-inch (M5) / iOS 26.5（0CE21EE5-82A1-4D1C-9554-7E17B54341DA）。该设备原为关机状态，由 Xcode 启动一次；未新建设备；结束清点时该 iPad 仍处于 Booted，原 iPhone 17 Pro 为 Shutdown，未由本轮操作重启。首次 UI 测试的强制方向切换遇到 SpringBoard AX 超时；恢复该 iPad 的 SpringBoard 界面服务后，测试移除不必要的强制旋转并继续复用同一设备。未重启或擦除模拟器。

工程最初由 Xcode 原生 iOS App 模板创建（Storyboard / Swift / XCTest）。该版本官方 MCP 无创建工程工具，创建使用 Xcode 原生 UI；源码、资源及测试均通过官方 XcodeWrite 迁入。没有复制旧工程的手写 project.pbxproj。应用最低 iOS 15.0，测试目标 iOS 15.6，Swift 6 / MainActor。

初始 14 个应用 Swift 文件和六项 XCTest 的迁移哈希保留在 MIGRATION.json.initialMigrationSourceMatches。当前 Swift 与 String Catalog 哈希见 currentSourceFiles，配置哈希见 currentProjectConfigurationFiles。String Catalog 当前为 38 个 key（en、zh-Hans、ar）。

当前 21 项单元测试保留此前 17 项，并新增旧数据迁移与 session 归属、三列栈与列表、UIKit 实际展开／折叠和两个真实 UISceneSession 的独立恢复。Trait 覆盖测试使用 iPadOS 17+ 公共 API，本轮 iPadOS 26.5 无跳过。另有两项 UI 测试：原详情／组合列表系统语言重启，以及双窗口三列不同草稿的系统语言重启。截图与文本附件见 verification/ipad-ui/。

快照版本 2 兼容版本 1 的双列数据。三列 primary、supplementary、secondary 业务导航栈、紧凑当前列和展开显示模式均可恢复。新的窗口副本使用独立 activation activity，连接后绑定新的 session；普通恢复不能覆盖其它绑定 session。详细规则见 IPAD_MULTIWINDOW_RESTORATION.md。

测试计划包含单元及 UI 两个目标，禁用并行，不附加测试调试器。两个测试目标 Debug/Release 的四项 OTHER_CODE_SIGN_FLAGS=--verbose=2 保留，签名保持启用。UI Runner 的 SDK TestingInterop 查找路径仅放在测试计划中。最新严格签名校验见 verification/ipad-signature-verification.json。

历史六项、十项、十二项、十三项和十八项验收分别单独保存在 verification/ 中。最新 iPhone 18 项记录为 official-mcp-restoration-eighteen-tests.*，该轮完整 iPad 23 项归档为 official-mcp-ipad-twenty-three-*。iOS 15/16 和真机未在本轮运行。
