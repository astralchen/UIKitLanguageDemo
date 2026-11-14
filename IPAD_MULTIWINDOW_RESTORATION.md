# iPad 三列分栏、尺寸变化与多窗口恢复

本文补充 STATE_RESTORATION.md。业务状态仍由 NSUserActivity 携带，语言由当前 Bundle 匹配。

## 三列 DTO 与兼容

版本 2 保留原 payload key `sceneState.v1`，以便读取上一版保存的数据。读取支持版本 1 / 2，写入新的捕获快照为版本 2。旧双列的 showsSecondary 映射到 compactColumn；缺省 style 为 doubleColumn，expandedMode 为 oneBesideSecondary。旧数据不会凭空生成 supplementary。

新状态保存 primary、supplementary、secondary 三个业务导航栈，样式、紧凑模式当前业务列、上次展开的显示模式。每一栈内仍使用原有稳定路由，所以详情草稿、Page 页 ID 和各页草稿、Table / Flow / Compositional 的草稿、选择和锚点都能组合使用。验证拒绝缺少中间栈的三列数据和选择不存在中间列的双列数据。

UIKit 自动折叠生成的内部导航控制器不序列化。业务导航控制器在工厂创建时单独保存引用，避免把系统包装层当作业务路由。

## 展开与折叠

示例工厂拥有 SplitRestorationPolicy 这个 UISplitViewControllerDelegate：

- topColumnForCollapsing 返回保存的 compactColumn。
- displayModeForExpanding 返回保存的 expandedMode。
- 实际宽度适配期间不把临时 secondaryOnly 覆盖到上次展开模式。
- selectColumn 立即记录业务请求的目标列；UIKit 自身的 show 调整只在稳定的紧凑模式中更新记录，页面显示回调记录原生紧凑返回后的业务列。
- 用户显式显示或隐藏边栏会更新 expandedMode。

恢复先建立三列和各列栈，再设置展开偏好；进入紧凑宽度时才显示 compactColumn。尺寸变化期间保留业务控制器实例。不要把 isCollapsed 当作永久用户偏好强制保存；实际是否折叠由恢复时的可用窗口宽度决定。

通用 LocalizedSplitViewController 不主动替换业务 delegate。只有 ContainerDemos.makeSplit 安装示例自有 policy。接入已有业务 delegate 时，应合并相同的恢复回调和业务选择规则；不要再调用 installDemoRestorationPolicy 覆盖它。模型会保留 UIKit 可用的显示模式，实际展示仍受当前窗口空间约束。

使用自定义工厂时，安装三列的同时保留业务导航引用：

```swift
split.restorationPrimary = primaryNavigation
split.restorationSupplementary = supplementaryNavigation
split.restorationSecondary = secondaryNavigation
split.setViewController(primaryNavigation, for: .primary)
split.setViewController(supplementaryNavigation, for: .supplementary)
split.setViewController(secondaryNavigation, for: .secondary)
// 用户选择中间列时记录业务意图；恢复及后续折叠使用同一模型。
split.selectColumn(.supplementary)
```

这里的导航控制器使用 `LocalizedNavigationController`。自定义页面还需在 `SavedPageState.Route`、`capturePage` 和 `makePage` 注册双向映射。工厂中的 `SplitRestorationPolicy` 由示例持有；已有 delegate 应合并对应回调。

## 多窗口

SceneWindowService 提供窗口菜单：复制当前窗口到新窗口、激活已有窗口、关闭当前窗口。使用 iOS 17+ 的 UISceneSessionActivationRequest，iOS 15/16 使用兼容 API。新窗口通过 `com.example.UIKitLanguageDemo.scene.copy` 携带显式业务副本，connectionOptions.userActivities 只在创建时消费该副本；它不作为系统恢复 activity 解码。

SceneDelegate 为每个 session 分配并保存 windowNumber，并把普通恢复快照绑定 sceneSessionID。新窗口副本会移除源 session ID、窗口编号并生成新的快照 ID；连接后新 Scene 再写入自身 session ID。普通恢复或迟到回调收到其它 session 的绑定数据时直接忽略。

切换已有窗口只激活该 session，不附加另一窗口的 userActivity。离开当前窗口、打开系统设置或请求窗口切换前保存相关 Scene，系统语言重启时优先按各 session 的 stateRestorationActivity 恢复；本地降级检查点继续按 persistentIdentifier 隔离。系统丢弃 session 时只删除那个 session 的文件。

语言选择仍是整个 App 的设置，窗口间共用 LanguageService；导航、草稿、列表和分栏状态各自独立。窗口菜单是临时 UI，不恢复菜单本身。

## 官方 MCP 验证

复用已有 iPad Pro 13-inch (M5) / iOS 26.5，UDID 为 0CE21EE5-82A1-4D1C-9554-7E17B54341DA。此设备原处于关机状态，由 Xcode 为测试启动一次；未新建设备，未重启原 iPhone 17 Pro，也未开启并行克隆。

新增单元测试覆盖旧数据迁移、session 归属校验、三列全部导航栈与隐藏列表、通过公开 Trait 覆盖触发 UIKit 实际折叠／展开、边栏隐藏模式恢复，以及两个真实 UISceneSession 的创建、独立 activity 重建和关闭清理。

新增 UI 测试实际从三列页面复制新窗口，写入不同草稿，通过系统设置改变 App 语言，断言旧进程终止。返回后分别切换两个 session，检查三列及不同草稿从各自 activity 恢复。最终计数和截图以 verification 中的验收记录为准。

参考：[UISplitViewControllerDelegate](https://developer.apple.com/documentation/uikit/uisplitviewcontrollerdelegate)、[Scene 连接选项与恢复](https://developer.apple.com/documentation/uikit/uiscenedelegate/scene(_:willconnectto:options:))、[UISceneSessionActivationRequest](https://developer.apple.com/documentation/uikit/uiscenesessionactivationrequest-swift.struct)。

## 已释放 Tab 视图的生命周期

Scene 重建后，旧导航控制器可能暂时仍被 UIKit 过渡或外部业务引用保留。iOS 18+ 的 Tab 标题由稳定 UITab 模型统一更新，导航控制器不再同时写入桥接的 tabBarItem.title；这避免旧 Tab 视图已经释放时，语言刷新访问 UIKit 无主引用而崩溃。iOS 15–17 继续更新传统 tabBarItem，两个路径均保留原导航控制器与栈。

最终官方 MCP 验收：**23 passed / 0 failed / 0 skipped / 0 not run**。结果见 [完整测试 JSON](verification/official-mcp-tests.json)，截图与系统交回状态的文本附件见 [iPad UI 证据目录](verification/ipad-ui/manifest.json)。

附件说明：原始 XCTest 截图保留了模拟器界面方向不同步时的黑边／截断，不能单独作为三列完整视觉截图。23 项测试的状态断言与文本附件独立有效。验收结束后，通过 Simulator 旋转同步显示方向，并在同一 iPad 手动打开三列页面，确认 RTL 的 primary／supplementary／secondary 均完整显示；补充截图见 [三列视觉核对](verification/ipad-ui/rtl-three-columns-visual-check.jpg)。该补充截图由 MobileBuildMCP 捕获，保留了原始传感器的 180° 方向；Simulator 窗口中显示正常。不对证据图片做旋转或裁切处理，也不计作 Apple 官方 MCP 测试结果。
