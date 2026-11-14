# UIKit 应用内语言切换示例（Xcode 原生工程）

工程由 Xcode 原生 iOS App 模板创建，源码与资源通过 Apple 官方 `xcrun mcpbridge` 的 MCP 工具迁入。完整 UIKit / Swift 6 工程，应用最低部署版本 iOS 15.0，模板测试目标为 iOS 15.6。包含中文、英文、阿拉伯语、跟随系统、运行时刷新通知、LTR/RTL 切换，以及 XCTest 回归测试。

App 内热切换沿用现有 UIWindow、根控制器、UITab、导航控制器、页面和输入框实例，不重新创建页面，也不重设导航栈或选中的 Tab。系统语言引发进程重启时，则按保存的业务路由重建控制器图。

## 系统 App 语言与热切换边界

Apple 在 [WWDC19 Session 403](https://developer.apple.com/videos/play/wwdc2019/403/) 推荐通过系统设置切换单 App 语言，并配合重新启动后的状态恢复。本工程为满足 App 内即时刷新要求，提供应用自有 UI 的内容语言热切换；它不改变系统单 App 语言设置，也不统一控制系统或第三方内建文案。现已提供 `NSUserActivity` 的跨进程状态恢复，重新建立导航栈、当前 Tab／Page／双列或三列 Split、草稿和列表阅读位置。

“跟随系统”现在读取资源 Bundle 的 preferredLocalizations（默认 Bundle.main），尊重系统为 App 匹配的语言；不再以 Locale.preferredLanguages 代替当前 App 语言。完整说明见 [系统语言与热切换](SYSTEM_LANGUAGE.md)。

## 运行

1. 用支持 Generate String Catalog Symbols 的 Xcode（本轮为 Xcode 26.5）打开 `UIKitLanguageDemo.xcodeproj`。
2. 选择 `UIKitLanguageDemo` Scheme 和一个 iOS 模拟器，Run。
3. 首页点击“打开详情”，输入草稿，再点击详情页中的语言按钮。
4. 验证详情页仍在、返回按钮仍可返回首页、草稿不变，中文/阿拉伯语切换时方向改变。
5. 设置 Tab 演示可变行高 Table；首页可进入 FlowLayout 网格/横向列表，以及 Compositional 网格/正交分页分区，滚动、选择、编辑草稿后切换语言。
6. 在任意示例页点击导航栏地球图标（“系统 App 语言设置”），在系统中选择语言并返回 App，验证当前位置、草稿和滚动位置恢复。该入口先切回“跟随系统”，以便新进程采用系统选择。
7. 使用 Product → Test 运行随工程附带的三十一项 XCTest（28 项单元测试和 3 项 UI 测试，含返回手势与系统设置重启）。UI 测试会暂改此 App 的语言，结束后还原原选项；不会修改模拟器全局语言。默认测试不主动唤起系统键盘；如需额外验证焦点与光标，在 Scheme 的 Test 环境变量中设置 `VERIFY_KEYBOARD_FOCUS=1`。

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
| `Localization/AppText.swift` | 类型化文案、Xcode 生成符号桥接及 iOS 15 映射 |
| `Localization/SceneState.swift` | 版本化业务 DTO、NSUserActivity 编解码与输入校验 |
| `Localization/SceneStateCoordinator.swift` | 重建导航／Page／Split、按 Scene 隔离的持久化检查点、系统设置入口 |
| `Localization/ListStateRestoration.swift` | 列表草稿、选择、逻辑阅读锚点及正交中心页的持久化桥接 |
| `Localization/SceneWindowService.swift` | 新窗口副本、已有 session 激活、窗口关闭与全 Scene 检查点 |
| `SceneDelegate.swift` | Scene 生命周期、NSUserActivity 保存与恢复、窗口注册 |
| `UIKitLanguageDemoTests/GeneratedSymbolTests.swift` | 38 项生成符号、参数类型、即时语言选择与英文回退／旧路径一致性 |
| `UIKitLanguageDemoTests/UIKitLanguageDemoTests.swift` | 热切换与新控制器图的恢复回归测试 |
| `UIKitLanguageDemoUITests/UIKitLanguageDemoUITests.swift` | 系统设置改语言、进程终止、导航和组合列表恢复 |

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
label.text = context.text(.detailTitle)
label.accessibilityLabel = context.text(.pagesNumber(3))
label.textAlignment = context.isRTL ? .right : .left
```

目录中的条目均提供英文；当前语言缺少翻译时使用英文兜底。iOS 15 的动态查找对未知 key 保留原 key。示例 `fallback.example` 故意只提供英文资源，用于测试回退。新增语言要同时添加枚举与 String Catalog 翻译；启动时会校验编译后的 `.lproj` 是否打入 target。

不要缓存已经翻译好的 `static let String`，应在渲染时通过当前快照读取。三套文案保存到 `UIKitLanguageDemo/Localizable.xcstrings`，由 Xcode 编译为 en、zh-Hans、ar 的 `.lproj/Localizable.strings`，同时自动生成本地化符号。

## Xcode 生成的本地化符号

按照 [Apple 官方文档](https://developer.apple.com/documentation/xcode/using-generated-localizable-symbols-in-your-code)，工程保持 `STRING_CATALOG_GENERATE_SYMBOLS = YES`。Xcode 为无参数文案生成 `LocalizedStringResource` 静态属性，为参数文案生成带类型参数的函数；例如 `.detailTitle`、`.pagesNumber(Int)`、`.detailNumber(String)`、`.windowName(Int32)`。生成文件位于 DerivedSources，由 Xcode 维护，不复制到仓库。

页面统一接收 `AppText`，而不是原始字符串 key。`AppText.resource` 在 iOS 16+ 返回实际生成的符号，`LanguageContext.text` 每次取一份资源值、设置当前语言的 locale，再调用 `String(localized:)`。带参数的资源保留生成函数的插值和参数类型，现代路径不使用 CVarArg 格式化。Tab、Page、Header 的标题元数据也已改为 AppText。

生成资源在缺少指定语言翻译时可能返回 key，因此解析前先检查当前 `.lproj` 中是否存在该条目；缺失时以英文 locale 解析同一生成资源。资源的 bundle 来自生成代码，不尝试修改只读的 bundle 属性，也不修改进程的 AppleLanguages。即时切换继续使用 LanguageService 的快照和原有刷新通知，导航栈、草稿、列表锚点及多窗口恢复协议不变。

iOS 15 不提供 LocalizedStringResource。相同的 AppText 在旧系统走集中维护的 legacyKey／legacyArguments 适配，使用当前语言 Bundle → 英文 Bundle → key，并保留格式化 Locale。所有 iOS 16 API 均有 availability 保护，最低部署版本仍为 iOS 15.0。`legacyText` 是生产中实际使用的旧路径，测试也会显式运行它，避免只验证新系统分支。

新增文案时：

1. 在 String Catalog 添加 key、英文及其它翻译，构建后从 Xcode 检查生成符号的名称和参数类型。
2. 在 AppText 添加对应 case；resource 分支引用生成符号，legacyKey／legacyArguments 分支补上 iOS 15 映射。占位符类型变更会使不匹配的生成函数调用编译失败。
3. 在 GeneratedSymbolTests 的样本文案列表中加入新项，比较三种语言的生成路径和旧路径，并更新目录条目数断言。

当前 iOS 15 适配覆盖目录中的普通字符串、`%@`、`%ld` 和 `%d`。新增复数、性别或其它变体时，需要同时扩展旧系统适配与测试；不把普通 String(format:) 当作完整的 String Catalog 变体解释器。

## 接入页面

继承 `LocalizedViewController`。在 `buildUI()` 中创建控件、注册操作和设置约束；在 `applyLocalization(_:)` 中更新文案、资源和与方向有关的布局。基类在控件创建完成后自动执行首次刷新，因此子类不必自己观察通知。

```swift
@MainActor
final class DraftPreviewViewController: LocalizedViewController {
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
        // 使用目录中已有文案；新增条目时同时扩展 AppText。
        title = context.text(.detailTitle)
        nameLabel.text = context.text(.detailDraft)
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

`SceneDelegate` 展示了完整启动代码。`LocalizationHostController` 在创建或恢复 Scene 时包裹业务根控制器，热切换不替换它，iOS 15/16 通过该容器覆盖子控制器的布局 Trait。每个业务窗口，包括自建悬浮窗口，都需注册：

```swift
LanguageService.shared.register(window: window)
```

关闭/断开窗口时可调用 `unregister(window:)`。服务只弱引用窗口，不延长窗口生命周期。新窗口注册时立即应用当前方向。

iOS 17+ 在 Scene 层设置 `traitOverrides.layoutDirection`，后续展示的控制器继承该方向。iOS 15/16 同时使用根容器 Trait 覆盖，以及业务页面、导航栏、TabBar 和自定义布局容器的 `semanticContentAttribute`。

自定义容器在旧系统调用 `LayoutDirection.applyBoundary(context, to: container)`；不要递归强制覆盖全部子视图的语义方向。iOS 18+ 的 Tab 由稳定的 UITab 实例管理，切换时直接更新 `UITab.title`，保留原来的导航控制器实例和选中项。

## 状态保留与方向适配

- 输入框：刷新 placeholder、accessibilityLabel 等静态文案，不重新赋用户输入的 `text`。选区恢复仅在仍为 first responder、文本未变且没有 marked text 时执行；有输入法组词中的内容时不主动改选区。
- 导航：沿用当前导航栈和页面。导航视图、导航栏及工具栏在所有系统版本显式设置 `semanticContentAttribute`，使原生返回手势和转场跟随当前语言的起始边；iOS 17+ 的 Scene Trait 覆盖继续负责其余界面。返回标题由导航容器统一刷新整个栈的 `navigationItem.backButtonTitle`，包含尚未加载视图的恢复页面；初始化、push 和 setViewControllers 也应用当前语言。
- Table：原地重新配置可见 Cell，复用时读取最新快照，按业务 ID 保留选择、草稿和顶部阅读锚点，并重新测量自动行高。
- Collection：刷新 Cell 与 Header 并使布局失效，业务数组保持不变，FlowLayout 使用自身的 RTL 排列；横向锚点使用逻辑起始边。详见 [列表接入说明](LIST_LOCALIZATION.md)。
- 自定义布局：使用 leading/trailing、方向性边距；计算 frame 时读取 `effectiveUserInterfaceLayoutDirection`。
- 语言按钮：四个语言名称统一按 App 起始边对齐（中文／英文靠左，阿拉伯语靠右），名称保留原文。切换方向时清除按钮旧配置，再应用新的 `.tinted()` 配置、显式语义方向与左右对齐；勾选图标保持逻辑 trailing。按钮与点击动作原地保留。
- 标签：需要跟随 App 起始边的文字显式使用当前语言左右对齐。草稿输入框显式按 App 起始边对齐，输入文字内部保留 Unicode 自然书写方向；多语言正文可独立按内容处理。
- 例外组件：手机号跟随 App 左右对齐，同时使用 LTR 段落及 `.forceLeftToRight` 保持完整号码顺序；账号可按业务保留 LTR，播放和物理方向组件保留 `.playback`/`.spatial`。示例不会递归覆盖这些标记。
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
], initialPageID: "details", titleMessage: .pagesTitle)

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

## 系统语言重启后的状态恢复

`SceneDelegate` 在离开前把稳定路由、业务 ID 和用户草稿写入 `NSUserActivity`；新 Scene 优先读取系统交回的 activity，再按当前 Bundle 语言重建页面。仅恢复业务状态，不保存旧语言、翻译文案、控制器或键盘。列表在视图进入窗口并完成测量后恢复锚点；正交分页恢复中心业务 ID。

每个 Scene 另有原子、文件保护的本地检查点，作为系统未交回 activity 时的降级。迟到或重复的 activity 不覆盖已恢复状态或用户新操作。完整生命周期、接入方式和已测边界见 [NSUserActivity 状态恢复](STATE_RESTORATION.md)。

## iPad 三列与多窗口

首页“三列分栏”演示三列独立导航和草稿；“显示或隐藏边栏”切换展开模式。窗口变窄时由 UIKit 折叠到保存的业务列，变宽后恢复边栏模式。导航栏窗口图标支持复制当前页面到新窗口、切回已有窗口及关闭当前窗口；每个 session 的导航栈、Page、草稿和列表位置独立恢复。

新窗口使用独立 activation activity 接收副本；普通恢复快照绑定自己的 session ID，不能覆盖其它窗口。详细实现与已有业务 delegate 的接入方式见 [iPad 与多窗口恢复](IPAD_MULTIWINDOW_RESTORATION.md)。

## 工程创建与迁移记录

当前 Apple 官方 MCP 服务器未提供创建新工程的工具，因此创建步骤使用 Xcode 原生 iOS App 模板（Storyboard / Swift / XCTest）；分组、源码、Info.plist、String Catalog 和测试通过官方 MCP 写入。工程文件由 Xcode 创建与维护，没有复制旧工程的手写 project.pbxproj。

官方 MCP `BuildProject` 构建成功，发现 25 项测试且全部启用。生成符号迁移阶段的全量结果为 **24 passed / 1 failed / 0 skipped / 0 not run**：23 项单元测试（含新增的两个生成符号测试）及单窗口系统语言重启 UI 测试通过；双窗口 UI 用例在启动时出现 AX 错误，后续单项复验仍发生 UI 查询超时。该轮未完成全部 25 项验收；本次手势修复采用独立的定向回归。原始全量结果见 `verification/official-mcp-tests.json`，最近单项复验见 `verification/official-mcp-symbols-ipad-recheck.json`。测试签名保持启用，源码一致性见 `MIGRATION.json`。

本机 Xcode 的 UI Runner 曾缺少 SDK 自带的 `lib_TestingInterop.dylib`；测试计划用 `$(PLATFORM_DIR)/Developer/usr/lib` 补充测试进程的动态库路径，保持签名启用，详见状态恢复文档。

本轮复用已有 iPad Pro 13-inch (M5) / iOS 26.5，未创建、重启或擦除模拟器。曾单独恢复 SpringBoard 界面服务及重开设置 App；桌面界面连接随后也超时。此前完整 iPad 23/23 通过的报告已归档为 `official-mcp-ipad-twenty-three-*`，属于生成符号迁移前的历史记录。

本机已确认新构建产物包含 en、zh-Hans、ar 三套本地化文件。iOS 15/16 兼容分支尚未在对应系统版本运行。

参考：[Apple 官方 MCP 接入说明](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode)、[Apple UIKit Trait 系统](https://developer.apple.com/videos/play/wwdc2023/10057/)。

测试夹具优先选择前台 Scene，弹层呈现使用可让出 MainActor 的异步等待，并断言完成呈现且仍挂在原窗口。系统设置中的可选确认按钮采用一次标签集合查询，避免无弹窗时重复扫描无障碍树；真实语言更改、旧进程终止和恢复状态断言均保留。

iPad UI 用例通过 Runner 设备类型判断运行条件，并等待设置页的 App 入口或语言行加载完成，再执行选择；不会在 App AX 服务刚启动时读取主窗口尺寸。

iOS 15 兼容已进行最低部署构建、弱链接检查及生产旧路径测试；本轮实际运行系统为 iOS 26.5，未在 iOS 15 运行时执行。最新四项签名校验见 `verification/symbols-signature-verification.json`。

## 返回手势方向

阿拉伯语（RTL）从屏幕右边缘向左滑动返回；中文／英文（LTR）从左边缘向右滑动返回。切换语言时，LocalizedNavigationController 显式更新其 view、navigationBar 和 toolbar 的语义方向；loadView 阶段也应用当前方向，以覆盖初次加载就是 RTL 的情况。保留 UIKit 原有边缘返回手势、iOS 26 内容返回手势及代理，导航栈和草稿继续沿用。

手动复验：在详情页切到阿拉伯语，左边缘向右滑动应留在详情页，右边缘向左滑动应返回首页；再次打开详情，切回中文，右边缘向左不应返回，左边缘向右应返回。

本次返回手势修复已通过 Apple 官方 MCP 定向验证：方向与状态保留单元用例通过，真实左右边缘滑动 UI 用例通过；复用已有 iPhone 17 Pro / iOS 26.5。原始运行与范围说明见 [返回手势验证记录](verification/navigation-gesture-verification.json)。本次未重跑全部 27 项，前述生成符号阶段的 iPad AX 阻塞记录保留。

## 语言按钮对齐修复

修复热切换后 `English` 或未选中语言按钮仍停在旧边的问题。回归用例先在旧实现复现，再检查同一组按钮经 EN → AR → ZH → EN → AR 切换后的实际文字／图标 frame，并覆盖按下与松开状态。

Apple 官方 MCP 构建通过；复用现有 iPhone 17 Pro / iOS 26.5，最终三项定向回归全部通过（按钮布局、导航状态、真实边缘返回手势）。本轮未重跑全部 28 项，未执行 iOS 15 运行时。原始结果与范围见 [按钮对齐验证记录](verification/language-picker-alignment-verification.json)。

## 恢复后的返回标题

修复英文界面仍显示“返回”的问题。恢复后直接显示详情页时，前一页可能尚未加载，页面级通知尚未注册；原来只在恢复时赋值的标题因而残留。现在由 LocalizedNavigationController 在每次语言切换时刷新整个栈的返回标题，并在初始化、push 和 setViewControllers 时设置当前语言，不触发前序页面加载。

UIKit 的返回标题来自栈中前一个 navigationItem，见 [Apple backButtonTitle 文档](https://developer.apple.com/documentation/uikit/uinavigationitem/backbuttontitle)。保留系统返回按钮与手势，不安装自定义 leftBarButtonItem。

复用现有 iPhone 17 Pro / iOS 26.5，Apple 官方 MCP 构建及四项定向回归全部通过。UI 用例包含真实后台、终止、重启后直接恢复详情，再检查 Back／رجوع／返回及正确的返回手势；单元用例检查三层导航栈、未加载页面、草稿与实例保留。本轮未全量重跑 29 项，未运行 iOS 15 设备。原始失败复现与最终结果见 [返回标题验证记录](verification/navigation-back-title-verification.json)。

## 输入框与手机号方向

`LayoutDirection.applyTextField(context, to:)` 在每次本地化刷新时设置草稿框的显式语义方向和左右对齐：阿拉伯语靠右，中文／英文靠左；占位文字同步更新。详情、分栏、翻页和 Table／Collection 共用草稿视图均已接入。仅更新布局属性，不重写用户文本、选区或输入法 marked text；已有 TextInputSnapshot 继续负责焦点选区保留。

对齐位置与文字书写顺序分别处理：手机号标签在 RTL 页面靠右，在 LTR 页面靠左，但 NSParagraphStyle.baseWritingDirection 始终为 leftToRight，保持 `+86 138 0000 0000` 完整顺序。普通草稿不强行覆盖字符书写方向。

依据 [Apple UITextField.textAlignment](https://developer.apple.com/documentation/uikit/uitextfield/textalignment) 的占位文字对齐规则，以及 [Apple RTL 指南](https://developer.apple.com/design/human-interface-guidelines/right-to-left) 的数字顺序规则实现。

复用现有 iPhone 17 Pro / iOS 26.5，官方 MCP 构建成功，五项单元测试通过，UI 用例单项复验通过。首次 UI 运行在重启后回到首页，夹具补充后台状态等待后复验成功；两次运行之间生产代码不变。焦点测试使用真实 UITextField first responder 和测试专用 inputView，覆盖空光标位置、混合文本选区及中文组词保留；未声称验证系统键盘 UI。本轮未全量重跑 31 项或执行 iOS 15 运行时。

原始记录见 [输入方向验证](verification/text-direction-verification.json)；未修改的 XCTest 截图见 [英文页面](verification/text-direction-ui/english.png)、[阿拉伯语页面](verification/text-direction-ui/arabic.png)。
