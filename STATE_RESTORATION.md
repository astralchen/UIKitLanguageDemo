# 系统语言切换后的 NSUserActivity 状态恢复

Apple 的系统单 App 语言路径可能结束现有进程。本工程把业务状态保存为 `NSUserActivity`，重新启动后使用当前 Bundle 语言构建新控制器图。App 内热切换继续使用现有控制器实例。

## 生命周期

1. 每个业务页导航栏的“系统 App 语言设置”调用 `SystemLanguageSettings.open(from:)`：先设为 `.system`，记录当前 Scene，再通过公开的 `UIApplication.openSettingsURLString` 打开此 App 的设置入口。该 URL 不保证直接定位“语言”子项。
2. `sceneWillResignActive`、`sceneDidEnterBackground`、`sceneDidDisconnect` 和 `stateRestorationActivity(for:)` 都可建立最新快照。`checkpoint` 把 activity 交给 `scene.userActivity` 与 `session.stateRestorationActivity`，同时原子保存本地降级检查点。
3. `scene(_:willConnectTo:options:)` 优先解码 `session.stateRestorationActivity`；缺失或无效时尝试当前 session 的检查点，仍无有效数据则正常进入首页。
4. 工厂按路由重建两个导航栈和选中 Tab，恢复详情草稿、Page 当前业务页及各页草稿、全屏 Split 的两列／三列业务导航栈、紧凑模式当前列与展开边栏显示模式。
5. 列表先注入草稿模型，再在 `viewDidAppear`、视图进入窗口后应用选择和锚点，避免在零尺寸或未测量布局中恢复。
6. UIKit 也可能通过 `restoreInteractionStateWith` 延迟交回数据。协调器只在尚未应用 activity 且业务状态仍等于启动基线时接受；重复数据不会把用户新输入回滚。`continue userActivity` 共用验证入口。
7. `application(_:didDiscardSceneSessions:)` 删除已丢弃 session 的本地检查点。

## 保存内容

| 状态 | 编码与恢复方式 |
| --- | --- |
| 导航栈、当前 Tab | 路由白名单 + 每栈按顺序的页面状态 |
| 详情草稿 | 字符串，恢复到新输入框 |
| UIPageViewController | 当前页稳定 ID + 全部三页的草稿；重新建立当前语言的邻接关系 |
| UISplitViewController | 双列／三列的 primary/supplementary/secondary 业务导航栈、草稿、紧凑当前列及展开显示模式 |
| UITableView | 顶部业务项 ID + 相对顶部距离、选择 ID、按项 ID 存储的草稿 |
| Flow 纵向／Compositional 网格 | 逻辑起始项 ID + 顶部相对距离，翻译测量后恢复 |
| Flow 横向 | 业务项 ID + 逻辑 leading 相对距离；跨 LTR/RTL 不复用旧物理 x |
| Compositional 正交分页 | section → 中心业务项 ID，并独立恢复外层纵向位置 |

快照会合并可见输入框的实际文本，即使业务还没收到 `editingChanged`。未加载或尚未应用的列表状态保留为 pending，不为保存而加载整个导航栈。重启快照可读取拖动／减速中的当前视口；它不会主动滚动正在交互的旧界面。正交范围为一组一项的 `.groupPagingCentered`，保存离中心最近的业务项，不保存连续滚动的小数偏移。

不序列化语言选择、翻译文案、UIViewController、IndexPath、布局实例、键盘或 first responder。系统语言仍来自 `Bundle.main.preferredLocalizations`；输入草稿按原内容恢复。弹出警告、系统弹层、未提交的交互式翻页、输入法 marked text、任意业务页面和任意第三方容器的恢复不属于此示例的已实现范围。新增业务路由需扩展 DTO、工厂和测试。

## 数据与降级

`SceneStateCodec` 的 activity type 为 `com.example.UIKitLanguageDemo.scene`，userInfo 中仅放属性列表兼容的 JSON Data（key 为 `sceneState.v1`）。兼容版本 1 / 2（新快照为版本 2）、两 Tab 的根路由、UUID、枚举路由、页 ID、数组规模和有限数值；无效数据不会用于建页面。当前示例上限：快照 512 KiB、每个草稿 16 KiB、每栈 16 页、每列表 200 个草稿／选择。超限快照不会保存；生产项目应按真实草稿体积拆分到独立业务存储。

activity 禁止 Handoff、搜索、公开索引和预测。检查点放在 Application Support/SceneCheckpoints，文件名为 session.persistentIdentifier 的 SHA-256，使用 `.atomic` 与 `.completeFileProtectionUntilFirstUserAuthentication` 写入。不同 Scene 不共用文件；它是系统未交回 activity 时的降级，不把进程退出等同于 UIKit 必然提供恢复数据。卸载、清除 App 数据或丢弃 Scene 会失去对应状态，不能用来替代业务草稿的长期存储。

新增页面时：在 `SavedPageState.Route` 增加稳定路由，在 `SceneStateCoordinator.capturePage` 和 `makePage` 增加双向映射；列表实现 `ListStateRestorable` 并在 `viewDidAppear` 调用 `applyIfNeeded`。业务数据变化后由 ID 查找当前位置，已删除 ID 可忽略，不能存储旧 indexPath 作为身份。

## 官方 MCP 验证

全部源码与测试通过 Apple 官方 `xcrun mcpbridge` / `XcodeWrite` 写入原生工程。使用既有 iPhone 17 Pro / iOS 26.5（07EFF63F-CD81-40CE-B872-428175F5D3C2），测试计划关闭并行，不创建或重启模拟器。

新增四项单元测试通过新的 UIWindow／控制器图验证：两个导航栈、选中 Tab、Page 当前页和隐藏页草稿、Table 锚点与选择、四种 Collection 布局及正交中心页、Split 各列、无效数据、分 Scene 存储、迟到和重复交付。

UI 测试通过真正的系统 Settings 界面修改此 App 的语言，断言旧 App `.notRunning` 后再激活；检查系统交回 activity 的恢复来源、阿拉伯语详情／草稿／返回栈，以及切回英文后的组合网格业务锚点／相对距离／草稿。测试最后还原原 App 语言选项，不修改模拟器全局语言。完整结果、控制台与截图位于 `verification/`。

最终官方结果为 **18 passed / 0 failed / 0 skipped / 0 not run**。UI 恢复来源断言为 `activity|ar` 和 `activity|en`。组合网格实测锚点 `list.cell.10`，顶部距离恢复前后均为 `-49.33333333333326 pt`，草稿为 `Saved list draft`。

- [完整官方测试结果](verification/official-mcp-tests.json)
- [阿拉伯语详情恢复截图](verification/restoration-ui/arabic-detail.png)
- [英文组合网格恢复截图](verification/restoration-ui/english-compositional-grid.png)
- [锚点测量附件](verification/restoration-ui/list-anchor.txt)

本机 SDK 的 UI Runner 启动时曾报 `@rpath/lib_TestingInterop.dylib` 缺失；SDK 自带库实际存在。测试计划以 `DYLD_LIBRARY_PATH=$(PLATFORM_DIR)/Developer/usr/lib` 补充查找路径，UI 测试将该路径转交被测 App。它仅用于测试进程，不改变正式 App 的资源或运行路径。两个测试目标的四项签名参数修复继续保留，没有关闭签名。

当前验证平台为 iPhone 17 Pro / iOS 26.5。iOS 15/16、真机上的系统设置路径尚未运行；不得把这里的模拟器结果视为这些平台已通过。

参考：[Apple — stateRestorationActivity(for:)](https://developer.apple.com/documentation/uikit/uiscenedelegate/staterestorationactivity(for:))、[UISceneSession.stateRestorationActivity](https://developer.apple.com/documentation/uikit/uiscenesession/staterestorationactivity)、[Restoring your app’s state](https://developer.apple.com/documentation/uikit/restoring-your-app-s-state)、[WWDC19 Session 403](https://developer.apple.com/videos/play/wwdc2019/403/)。

## iPad 与多窗口扩展

三列导航栈、UIKit 实际展开／折叠、紧凑当前列、展开边栏模式和多个 UISceneSession 的独立恢复现已接入；迁移规则、delegate 接入约束与新窗口副本语义见 [IPAD_MULTIWINDOW_RESTORATION.md](IPAD_MULTIWINDOW_RESTORATION.md)。上方 18 项及截图为此前 iPhone 验证记录，最新 iPad 验收以 verification/official-mcp-tests.json 为准。
