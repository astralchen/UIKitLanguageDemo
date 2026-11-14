# 系统 App 语言与应用内容热切换

官方参考为 WWDC19 Session 403：[Creating Great Localized Experiences with Xcode 11](https://developer.apple.com/videos/play/wwdc2019/403/)。这场讲座讨论系统单 App 语言、本地化资源与测试工具，并没有提供在现有进程中统一切换整个 App 语言的公开 API。

## 系统推荐路径

讲座推荐让用户在系统设置里选择 App 语言。可以从 App 打开自身设置页：

```swift
if let url = URL(string: UIApplication.openSettingsURLString) {
    UIApplication.shared.open(url)
}
```

这个 URL 打开 App 设置入口，不保证直接定位“语言”子项。根据讲座介绍，系统语言选择变化后，App 会以目标语言重新启动；通过状态恢复 API（例如 NSUserActivity）重新建立用户所在位置、业务 ID 和草稿。跨进程恢复会重新创建控制器，并非保留原控制器实例。本示例尚未实现跨进程的业务状态恢复流程。

不要写入 AppleLanguages 或通过 swizzling 替换系统 Bundle 行为。

## 本工程保留的产品要求

用户要求在 App 内即时刷新，并保留当前页面和导航栈。因此 LanguageService 提供的是应用自有 UI 的内容语言选择：显式读取指定语言 Bundle，刷新文案、格式化策略和业务布局方向，并保留当前进程的页面与业务状态。

它不会改变系统的单 App 语言设置，不保证系统权限提示、系统控件内建字符串、系统菜单、键盘或第三方 SDK 文案随之切换。手动读取语言资源 Bundle 也不应被理解为 Apple 推荐的系统 App 语言切换方案。若产品要求系统 UI 和 App 文案统一，应采用上面的系统设置路径，并实现跨进程状态恢复。

## “跟随系统”的正确含义

本工程 `.system` 跟随资源 Bundle 经系统匹配后的 App 语言，默认读取：

```swift
Bundle.main.preferredLocalizations
```

系统设置中的单 App 语言优先级也应体现在这一路径中。随后仅在示例支持的 en、zh-Hans、ar 中做匹配。初始化和切回 `.system` 都重新读取 Bundle 偏好；显式 `.english` / `.simplifiedChinese` / `.arabic` 则保持应用内容选择。

`Locale.preferredLanguages` 描述用户的语言偏好列表，不能拿它的首项当成当前 App 的运行语言。对服务器返回的另一组可用语言，可以使用 `Bundle.preferredLocalizations(from:forPreferences:)` 与正确的 App 内容语言偏好做匹配；显式热切换模式下，请求语言应来自 `LanguageService.context`，避免页面与远程内容语言不一致。

`LanguageContext.locale` 当前采用“格式化跟随内容语言”的示例策略，没有宣称修改系统 Region。真实产品可把语言、地区和数字格式偏好拆开配置。

## 验证

新增 `testSystemSelectionUsesAppBundlePreferences`，通过可注入的 Bundle 偏好提供器验证初始化、显式选择优先级、切回跟随、偏好变化和重新实例化，并检查默认路径与主 Bundle 匹配。测试不修改 AppleLanguages，也不改变模拟器系统语言。

此测试与既有运行时状态保留测试区分：它没有代替系统设置切换后的真实重启与状态恢复测试。
