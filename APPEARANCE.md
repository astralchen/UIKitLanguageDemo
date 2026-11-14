# UIKit 外观切换

外观偏好与语言／RTL 方向分别管理。用户选择保存在 UserDefaults，AppearanceService 原地更新所有已注册 UIWindow，不替换根控制器、页面、导航栈或输入框。Scene 恢复时应用当前全局外观偏好，不把旧外观放进 NSUserActivity 覆盖用户新选择。

## 官方 API 与选择规则

| 用户选择 | UIWindow.overrideUserInterfaceStyle | 行为 |
| --- | --- | --- |
| 跟随系统 | `.unspecified` | 移除外观覆盖，继续继承系统当前及后续变化 |
| 浅色 | `.light` | 此窗口固定浅色 |
| 深色 | `.dark` | 此窗口固定深色 |

保存的是选择 system／light／dark；跟随系统时不保存当前解析出的 light／dark。读取实际外观使用 `view.traitCollection.userInterfaceStyle`，不能把 overrideUserInterfaceStyle 当作实际外观，尤其是 unspecified 时。[Apple：UIUserInterfaceStyle.unspecified](https://developer.apple.com/documentation/uikit/uiuserinterfacestyle/unspecified)、[UIView.overrideUserInterfaceStyle](https://developer.apple.com/documentation/uikit/uiview/overrideuserinterfacestyle)

选择 UIWindow 层设置，因为它覆盖根控制器、子控制器和窗口内的呈现内容。工程的 SceneDelegate 在创建窗口后立即注册，SceneStateCoordinator 在显示恢复内容前再次幂等注册；断开时注销，重返前台时重新注册。新 Scene 和恢复窗口应用同一服务中的当前选择。额外创建的业务浮窗也需主动注册，不能只获取某个 keyWindow。[Apple：选择特定外观](https://developer.apple.com/documentation/uikit/choosing-a-specific-interface-style-for-your-ios-app)、[Scenes](https://developer.apple.com/documentation/uikit/scenes)

```swift
AppearanceService.shared.register(window: window)
AppearanceService.shared.setSelection(.dark)   // 也可 .light / .system
AppearanceService.shared.unregister(window: window)
```

服务只弱引用窗口。`.appAppearanceDidChange` 表示用户偏好改变，在保存并更新窗口后发送；设置入口据此同步选中项。系统自动变更外观由 UIKit Trait 传播，不伪造用户偏好通知，也不把 System 改成 Light／Dark。

工程没有在 Info.plist 或构建设置中固定 UIUserInterfaceStyle 为 Light／Dark。Info.plist 方案是静态选择／退出深色适配的配置，不适合这里的三态运行时设置。SDK 声明 preferredUserInterfaceStyle、childViewControllerForUserInterfaceStyle、setNeedsUserInterfaceAppearanceUpdate 在 iOS 不可用，因此不使用 tvOS 的外观请求路径。

## 动态颜色与 CALayer

系统控件和 `.label`、`.systemBackground`、`.secondarySystemBackground` 等语义 UIColor 由 UIKit 自动刷新，不需要重载页面或递归替换颜色。符号图片沿用系统渲染。用户输入内容与手机号没有被主题切换重写。[Apple：Supporting Dark Mode](https://developer.apple.com/documentation/uikit/supporting-dark-mode-in-your-interface)

CALayer 持有的 CGColor 是静态值。DemoCollectionCell 的选中边框以前只在 isSelected 变化时设置 systemBlue.cgColor；现在依据该 Cell 的 traitCollection 重新解析颜色，确保已选中 Cell 在外观切换后也更新。

- iOS 17+：注册 `UITraitCollection.systemTraitsAffectingColorAppearance`，同时涵盖外观、对比度等颜色相关 Trait。
- iOS 15/16：在 `traitCollectionDidChange` 中用 `hasDifferentColorAppearance(comparedTo:)` 判断。
- 初始化、加入窗口和选中状态改变时也更新边框；注册变化回调不能代替首次配置。

更新时使用 `UIColor.systemBlue.resolvedColor(with: traitCollection).cgColor`，依据视图实际环境解析，不在任意异步位置依赖 UITraitCollection.current。[Apple：Trait 变化适配](https://developer.apple.com/documentation/uikit/adapting-your-app-when-traits-change)、[WWDC23 Trait 系统](https://developer.apple.com/videos/play/wwdc2023/10057/)

## 判断当前外观与监听系统环境

视图接入窗口后，`view.traitCollection.userInterfaceStyle == .dark` 判断当前页面的有效深色外观。`view.window?.windowScene?.traitCollection.userInterfaceStyle` 读取所在 Scene 的环境；窗口手动覆盖不会改变 Scene 的环境值。当前工程不在生产代码中覆盖 Scene 的 userInterfaceStyle Trait。

若只是跟随系统，窗口设为 unspecified 即可；只有额外业务逻辑需要通知时才监听。在每个 Scene 的连接处，iOS 17+ 可注册：

```swift
if #available(iOS 17.0, *) {
    windowScene.registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
        (scene: UIWindowScene, previous: UITraitCollection) in
        let current = scene.traitCollection.userInterfaceStyle
        guard current != previous.userInterfaceStyle else { return }
        // 在此处理 Scene 环境的外观变化；不要把它赋给窗口的覆盖值。
    }
}
// 注册不触发首次回调，连接时也要读取一次初始值。
let initialSystemStyle = windowScene.traitCollection.userInterfaceStyle
```

iOS 15/16 在 UIWindowSceneDelegate 中比较新旧值：

```swift
func windowScene(_ windowScene: UIWindowScene,
                 didUpdate previousCoordinateSpace: UICoordinateSpace,
                 interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
                 traitCollection previousTraitCollection: UITraitCollection) {
    guard #unavailable(iOS 17.0) else { return }
    let current = windowScene.traitCollection.userInterfaceStyle
    guard current != previousTraitCollection.userInterfaceStyle else { return }
    // 处理环境变化。
}
```

此旧代理方法已在 iOS 26 弃用，现代系统采用 Trait 注册。每个 Scene 独立注册，避免随意取 connectedScenes.first，或用某个手动覆盖过的页面推断整个系统外观。[Apple：旧 Scene Trait 回调](https://developer.apple.com/documentation/uikit/uiwindowscenedelegate/windowscene(_:didupdate:interfaceorientation:traitcollection:))

## 本地化与最低系统

设置页提供稳定的 UISegmentedControl，标题随当前语言即时更新。新增四项 String Catalog 条目仍通过 AppText 使用 Xcode 生成符号；iOS 15 使用已有 legacy 适配和英文回退。外观服务基于 iOS 13 已提供的窗口覆盖 API，工程最低部署版本仍为 iOS 15。iOS 17 的 Trait 注册有 availability 保护。

验证范围、官方 MCP 原始结果和截图在 README 与 verification 中记录；测试模拟的继承外观只覆盖测试 Scene 的 Trait，不修改模拟器全局外观设置。
