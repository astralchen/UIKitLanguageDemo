# Xcode 原生工程与官方 MCP 迁移记录

最新验收：2026-11-14，Apple 官方 MCP RunSomeTests 十项全部通过，0 failed、0 skipped、0 expected failures、0 not run。本次 RunSomeTests 使用 GetTestList 返回的全部十个实际测试 ID，原始结果见 verification/official-mcp-tests.json / .txt，控制台见 official-mcp-console.txt。RunAllTests 同样十项通过，但 Xcode 仍将内存中空的 UI 测试目标汇总为 No result；该原始输出另存 official-mcp-runall-with-empty-target.json，不作为最终验收计数。导出的显式计划已移除空目标。历史六项结果单独保存在 official-mcp-original-six-tests.*。

工程由 Xcode 原生 iOS App 模板创建（Storyboard、Swift、XCTest）。本机官方 MCP 服务器为 xcode-tools / 24939，通过 xcrun mcpbridge 连接；该版本无创建工程工具，因此创建使用 Xcode 原生 UI，源码、资源和测试通过官方工具迁入。没有复制旧工程的手写 project.pbxproj。

初次迁移的 14 个应用 Swift 文件和六项 XCTest 文件与原版逐字节一致，历史 SHA-256 保留在 MIGRATION.json 的 initialMigrationSourceMatches。随后添加 Table / Collection 支持，有意修改 LanguageService、Home、Settings、测试和 String Catalog，新增协调器与列表视图文件；当前改动及哈希记录在 listExtension。三套文案现在共 25 个 key。

应用最低 iOS 15.0，测试目标 iOS 15.6，Swift 6，显式 MainActor 隔离。签名修复保留为两个测试目标 Debug/Release 的 OTHER_CODE_SIGN_FLAGS=--verbose=2，没有关闭签名。详情及最初六项验收见 SIGNING_FIX.md。

原六项覆盖导航栈与草稿、弹层、持久化和资源回退、Split 各列导航栈、Page 当前页和 RTL 邻接、取消翻页后的方向。新增四项覆盖 Table 自动行高、草稿/选择、复用与滚动锚点，以及 Collection 网格镜像、Header、草稿/选择、纵向和横向尺寸变化后的锚点。

当前 Scheme 绑定显式 UIKitLanguageDemo.xctestplan，验收计划只包含有实际测试的单元测试目标并禁用并行，不附加测试调试器，App Run 的 LLDB 设置保留。自动测试计划曾继续使用并行缓存并触发克隆设备等待，之后关闭本工程并加载显式计划；最终官方测试复用现有 iPhone 17 Pro / iOS 26.5（07EFF63F-CD81-40CE-B872-428175F5D3C2）。

本次未在真机、iOS 15/16、iPad 重跑。Page 支持横向单页 scroll；Collection 验收范围为系统 FlowLayout 的两列网格和横向卡片，不包含正交滚动 Compositional Layout。列表接入与并发业务更新约束见 LIST_LOCALIZATION.md。
