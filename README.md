# UIKit 应用内语言切换示例（Xcode 原生工程）

工程由 Xcode 原生 iOS App 模板创建，源码与资源通过 Apple 官方 `xcrun mcpbridge` 的 MCP 工具迁入。完整 UIKit / Swift 6 工程，应用最低部署版本 iOS 15.0，模板测试目标为 iOS 15.6。包含中文、英文、阿拉伯语、跟随系统、运行时刷新通知、LTR/RTL 切换，以及 XCTest 回归测试。

语言切换沿用现有 UIWindow、根控制器、UITab、导航控制器、页面和输入框实例。根控制器只在 Scene 创建时设置一次，切换时不重新创建页面，也不重设导航栈或选中的 Tab。

## 运行

1. 用支持 Swift 6 的 Xcode 打开 `UIKitLanguageDemo.xcodeproj`。
2. 选择 `UIKitLanguageDemo` Scheme 和一个 iOS 模拟器，Run。
3. 首页点击“打开详情”，输入草稿，再点击详情页中的语言按钮。
4. 验证详情页仍在、返回按钮仍可返回首页、草稿不变，中文/阿拉伯语切换时方向改变。
5. 设置 Tab 演示可变行高 Table；首页可进入 FlowLayout 网格/横向列表，以及 Compositional 网格/正交分页分区，滚动、选择、编辑草稿后切换语言。
6. 使用 Product → Test 运行随工程附带的十二项 XCTest。默认测试不主动唤起系统键盘；如需额外验证焦点与光标，在 Scheme 的 Test 环境变量中设置 `VERIFY_KEYBOARD_FOCUS=1`。

测试计划已禁用并行执行，复用选中的现有模拟器；Test 不附加调试器，App Run 仍可正常调试。

测试计划已禁用并行执行，复用选中的现有模拟器；Test 不附加调试器，App Run 仍可正常调试。

模拟器无需配置开发团队。真机运行时，设置自己的 Bundle Identifier 和 Signing Team。

## 文件职责

| 文件 | 职责 |
| --- | --- |
| `Localization/LanguageContext.swift` | 语言枚举、系统语言匹配、语言资源、不可变快照、文案与格式化访问 |
| `Localization/LanguageService.swift` | 主线程语言切换事务、持久化、弱引用窗口注册、刷新通知 |
| `Localization/LayoutDirection.swift` | Scene 方向、旧系统兼容、启动时安装的稳定根容器 |
| `Localization/LocalizedControllers.swift` | 页面刷新协议、基类、导航容器、Tab 容器及 UITab 标题刷新 |
| `Localization/LocalizedSplitViewController.swift` | 分栏容器刷新，保留各列和折叠策略 |
| `Localization/LocalizedPageContainerController.swift` | 稳定 Page 容器、当前页 ID、RTL 邻接与翻页过渡处理 |
| `Screens/ContainerDemos.swift` | 分栏与翻页的可运行示例 |
| `Localization/TextInputSnapshot.swift` | 聚焦输入框的选区保存与恢复 |
| `Screens/LanguagePickerView.swift` | 可复用的语言选择组件 |
| `Screens/HomeViewController.swift` | 导航入口、应用自有返回按钮文案 |
| `Screens/DetailViewController.swift` | 草稿保留、格式化数字和固定 LTR 电话组件 |
| `Localization/ListLocalizationCoordinator.swift` | Table/Collection 三阶段刷新、稳定 ID 选择和滚动锚点、FlowLayout RTL |
| `Screens/SettingsViewController.swift` | 可变行高 Table、Header、复用与草稿 |
| `Screens/CollectionDemoViewController.swift` | 两列网格与横向卡片列表 |
| `Screens/ListDemoContent.swift` | Cell 内容、草稿绑定和 supplementary 示例 |
| `Screens/CompositionalDemoViewController.swift` | 自适应组合网格、正交分页分区及运行时镜像 |
| `Localization/OrthogonalLocalizationCoordinator.swift` | 正交 section 中心业务页与外层阅读位置保留 |
| `SceneDelegate.swift` | 创建并注册每个 Scene 的窗口 |
| `UIKitLanguageDemoTests/UIKitLanguageDemoTests.swift` | 导航栈、草稿、选区、弹层、持久化、回退和方向回归测试 |

## 切换语言

所有调用在主线程/MainActor 执行：

```swift
LanguageService.shared.setSelection(.simplifiedChinese)
LanguageService.shared.setSelection(.english)
LanguageService.shared.setSelection(.arabic)
LanguageService.shared.setSelection(.system)
```

异步业务代码中可使用：

```swift
await MainActor.run {
    LanguageService.shared.setSelection(.arabic)
}
```

读取当前文案：

```swift
let context = LanguageService.shared.context
label.text = context.text("detail.title")
label.textAlignment = context.isRTL ? .right : .left
```

资源查找顺序为当前语言 → 英文兜底 → key。示例 `fallback.example` 故意只提供英文资源，用于测试回退。新增语言要同时添加枚举与 String Catalog 翻译；启动时会校验编译后的 `.lproj` 是否打入 target。

不要缓存已经翻译好的 `static let String`，应在渲染时通过当前快照读取。动态 key 封装不会自动生成所有翻译项，资源文件需要随工程维护。此原生工程将三套文案合并保存到 `UIKitLanguageDemo/Localizable.xcstrings`，由 Xcode 编译为 en、zh-Hans、ar 的 `.lproj/Localizable.strings`，原有 Bundle 读取逻辑保持不变。新增语言也需要在 String Catalog 中添加翻译。

## 接入页面

继承 `LocalizedViewController`。在 `buildUI()` 中创建控件、注册操作和设置约束；在 `applyLocalization(_:)` 中更新文案、资源和与方向有关的布局。基类在控件创建完成后自动执行首次刷新，因此子类不必自己观察通知。

```swift
@MainActor
final class ProfileViewController: LocalizedViewController {
    private let nameLabel = UILabel()

    override func buildUI() {
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            nameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    override func applyLocalization(_ context: LanguageContext) {
        // 请在 Localizable.xcstrings 中添加这些 key 和三套翻译。
        title = context.text("profile.title")
        nameLabel.text = context.text("profile.name")
        nameLabel.textAlignment = context.isRTL ? .right : .left
    }
}
```

已加载页面会同步收到通知，包括仍在导航栈内但当前不可见的页面。尚未加载的页面保持懒加载，首次显示时读取最新语言；`viewWillAppear` 还会检查 revision。不要为了刷新文案强行加载整个导航栈的 view。

普通组件实现 `LocalizationUpdatable`，由所属页面在 `applyLocalization` 中调用。不能继承基类的控制器，可以像基类一样使用 selector 观察 `.appLanguageDidChange`，随后从 `LanguageService.shared.context` 读取最新状态。示例不使用 swizzling。

## 页面刷新通知

页面刷新通知为 `.appLanguageDidChange`，另有切换前的 `.appLanguageWillChange` 与布局后的 `.appLanguageDidApplyLayout`，object 是执行切换的 `LanguageService`。通过单例管理的页面应限定 `object: LanguageService.shared`，避免收到测试或其它服务实例的通知。

`userInfo` 包含 `oldLanguageID`、`newLanguageID`、`directionChanged` 和 `revision`。通知在 MainActor 上同步发送。执行顺序是切换前记录列表锚点、更新资源快照、保存选择、更新所有已注册窗口方向、通知页面刷新、窗口布局、通知列表重测并恢复锚点、恢复仍聚焦输入框的选区。

复用基类的页面不应再重复观察通知。不要在通知回调中反复切换语言；服务会将重入请求延后执行。

## 多窗口与容器接入

`SceneDelegate` 展示了完整启动代码。`LocalizationHostController` 只在窗口创建时包裹实际根控制器，iOS 15/16 通过该容器覆盖子控制器的布局 Trait。每个业务窗口，包括自建悬浮窗口，都需注册：

```swift
LanguageService.shared.register(window: window)
```

关闭/断开窗口时可调用 `unregister(window:)`。服务只弱引用窗口，不延长窗口生命周期。新窗口注册时立即应用当前方向。

iOS 17+ 在 Scene 层设置 `traitOverrides.layoutDirection`，后续展示的控制器继承该方向。iOS 15/16 同时使用根容器 Trait 覆盖，以及业务页面、导航栏、TabBar 和自定义布局容器的 `semanticContentAttribute`。

自定义容器在旧系统调用 `LayoutDirection.applyBoundary(context, to: container)`；不要递归强制覆盖全部子视图的语义方向。iOS 18+ 的 Tab 由稳定的 UITab 实例管理，切换时直接更新 `UITab.title`，保留原来的导航控制器实例和选中项。

## 状态保留与方向适配

- 输入框：刷新 placeholder、accessibilityLabel 等静态文案，不重新赋用户输入的 `text`。选区恢复仅在仍为 first responder、文本未变且没有 marked text 时执行；有输入法组词中的内容时不主动改选区。
- 导航：不调用 `setViewControllers`、不 pop、不替换根控制器。应用自有返回标题用 `navigationItem.backButtonTitle` 刷新。
- Table：原地重新配置可见 Cell，复用时读取最新快照，按业务 ID 保留选择、草稿和顶部阅读锚点，并重新测量自动行高。
- Collection：刷新 Cell 与 Header 并使布局失效，业务数组保持不变，FlowLayout 使用自身的 RTL 排列；横向锚点使用逻辑起始边。详见 [列表接入说明](LIST_LOCALIZATION.md)。
- 自定义布局：使用 leading/trailing、方向性边距；计算 frame 时读取 `effectiveUserInterfaceLayoutDirection`。
- 标签：需要跟随 App 起始边的文字显式使用当前语言左右对齐。用户输入或多语言正文按内容处理，自然对齐不等于把 App 全局语言切换为目标语言。
- 例外组件：电话/账号可保留 `.forceLeftToRight`，播放和物理方向组件保留 `.playback`/`.spatial`。示例不会递归覆盖这些标记。
- 图片：只镜像具有阅读/导航方向含义的图片；Logo、照片等按资源语义处理。
- 格式化：示例将数字格式 Locale 绑定到所选 UI 语言。需要独立地区偏好的产品可单独注入区域规则。
- 弹层：沿用现有弹层实例，应用自己提供的文案参与刷新。系统权限对话框、键盘及第三方 SDK 的内建文案不由此服务统一控制。

## UISplitViewController 接入

新增 `LocalizedSplitViewController` 直接继承系统分栏控制器，支持 `.doubleColumn` 和 `.tripleColumn`。首页“分栏示例”以全屏弹层展示双列示例。

```swift
let split = LocalizedSplitViewController(style: .tripleColumn)
split.setViewController(primaryNavigation, for: .primary)
split.setViewController(supplementaryNavigation, for: .supplementary)
split.setViewController(detailNavigation, for: .secondary)
split.preferredDisplayMode = .twoBesideSecondary
```

上面的导航控制器由业务在初始化时创建。语言切换时不重新调用 `setViewController`，不交换列，不修改 `preferredDisplayMode`，不调用 `show`/`hide`，不覆盖业务 delegate。各列中的页面和导航控制器沿用原刷新机制。业务选择的条目 ID 应保存在原页面或 ViewModel 中。

默认 `primaryEdge = .leading`：LTR 时在左侧、RTL 时在右侧。这里是逻辑边，不要再在 RTL 时改成 `.trailing`。如有业务自己的主列边缘策略，可在初始化后设置，语言刷新不会重置它。折叠/展开逻辑仍由业务原来的 `UISplitViewControllerDelegate` 处理。

## UIPageViewController 接入

新增 `LocalizedPageContainerController` 通过组合持有一个稳定的 `UIPageViewController`，支持**横向、单页、`.scroll`**。首页“翻页示例”有三页，从中间页开始，提供草稿、上一页/下一页与语言按钮。

```swift
let pager = LocalizedPageContainerController(pages: [
    .init(id: "overview", controller: overviewController),
    .init(id: "details", controller: detailsController),
    .init(id: "history", controller: historyController)
], initialPageID: "details", titleKey: "pages.title")

pager.onCurrentPageChanged = { id in
    // 同步业务状态或埋点。页 ID 始终按业务定义保持稳定。
}
pager.showPage(id: "history", animated: true)
pager.nextPage()
pager.previousPage()
```

`showPage`/`nextPage`/`previousPage` 返回是否接受请求；翻页进行中或到达边界时返回 false，调用方可在当前页变化回调后重试。不要直接替换内部 `pageViewController` 的 dataSource/delegate，也不要绕过这些方法重设其当前页，否则会破坏页 ID 和过渡管理。

业务页数组永远不反转。容器将底层翻页表面固定为物理 LTR，每个稳定的内容包装控制器再独立应用当前语言方向，因此页面内容仍为 RTL。相邻页关系如下：

| 翻页表面的位置 | LTR | RTL |
| --- | --- | --- |
| `viewControllerBefore`，物理左侧 | 业务上一页 | 业务下一页 |
| `viewControllerAfter`，物理右侧 | 业务下一页 | 业务上一页 |
| 程序化进入业务下一页 | `.forward` | `.reverse` |

方向变化时重新绑定 dataSource，并把同一组可见控制器以无动画方式交回系统，重新查询邻接页；业务页、当前页 ID 和包装控制器都保留。跨越相反布局方向的容器边界故意用 `leftAnchor/rightAnchor` 绑定物理边，避免将 RTL 的 leading 与 LTR 的 leading 错接而产生负宽度。

交互式或程序化翻页中收到语言变化时，页面文案先刷新，邻接方向等过渡完成或取消后再更新；连续多次切换只应用最新快照。页面变化回调在旧事务收尾之后执行，业务可以在回调中继续导航或切换语言。

本实现不支持 `.pageCurl`、竖向翻页和双面书页；`.pageCurl` 需要另行管理 `spineLocation`、`isDoubleSided` 与可见页组合，不能直接套用这套相邻页刷新逻辑。页数量较大时，可在同一状态模型上添加按 ID 缓存/回收页面的策略。

## UICollectionViewCompositionalLayout 接入

首页新增组合网格与 `.groupPagingCentered` 混合分区，item/group 使用 estimated 高度，翻译改变后重新测量。跨 LTR/RTL 时仅更新布局对象，保留 CollectionView、数据源、业务 ID、页面和导航栈。正交 section 通过公开可见项回调和 scrollToItem 恢复中心业务页，外层按独立锚点保留阅读位置。

完整实现与边界见 [Compositional Layout 接入说明](COMPOSITIONAL_LAYOUT.md)。本例使用普通数据源；正交恢复范围为每组一项的居中分页，不承诺连续滚动的小数偏移。

## 工程创建与迁移记录

当前 Apple 官方 MCP 服务器未提供创建新工程的工具，因此创建步骤使用 Xcode 原生 iOS App 模板（Storyboard / Swift / XCTest）；分组、源码、Info.plist、String Catalog 和测试通过官方 MCP 写入。工程文件由 Xcode 创建与维护，没有复制旧工程的手写 project.pbxproj。

官方 MCP `BuildProject` 已构建成功，`RunSomeTests` 已执行全部十二项测试：12 passed、0 failed、0 skipped、0 not run。原十项测试保留，并新增两项组合布局回归测试；结果保存在 `verification/official-mcp-tests.json`。测试签名问题已修复，详情见 `SIGNING_FIX.md` 和 `verification/`；源码一致性见 `MIGRATION.json`。

本机已确认新构建产物包含 en、zh-Hans、ar 三套本地化文件。iOS 15/16 兼容分支尚未在对应系统版本运行。

参考：[Apple 官方 MCP 接入说明](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode)、[Apple UIKit Trait 系统](https://developer.apple.com/videos/play/wwdc2023/10057/)。
