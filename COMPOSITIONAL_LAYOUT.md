# UICollectionViewCompositionalLayout 接入

首页新增“组合布局网格”和“组合布局横向分区”。完整页面为 `UIKitLanguageDemo/Screens/CompositionalDemoViewController.swift`，沿用同一个 CollectionView、数据源、页面和导航栈；不重建根控制器、不反转业务数组、不调用 reloadData。

## 布局与 RTL

网格使用二列 horizontal group，item 和 group 的高度都设置为 `.estimated(220)`，Cell 通过 Auto Layout 测量翻译后的高度。Header 同样使用 estimated 高度；边距使用 NSDirectionalEdgeInsets。

```swift
final class LocalizedCompositionalLayout: UICollectionViewCompositionalLayout {
    override var developmentLayoutDirection: UIUserInterfaceLayoutDirection { .leftToRight }
    override var flipsHorizontallyInOppositeLayoutDirection: Bool { true }
}
```

布局采用固定 LTR 开发坐标，由 UIKit 在相反方向下镜像。切换时显式更新 CollectionView 的 semanticContentAttribute；跨越 LTR/RTL 边界时通过 makeLayout() 重建布局对象，以刷新双向镜像缓存，CollectionView 和业务页面仍是原实例。不要叠加 transform 或手动反转数据；验证视觉顺序时，将 Cell bounds 转换到 UIWindow 坐标。内部 Cell frame 可能仍处于布局开发坐标，不能据此判断屏幕左右顺序。这与本工程 FlowLayout 自带 RTL 排列的分支不同。

语言事务仍为 willChange → didChange → didApplyLayout。主列表协调器先记录稳定业务 ID 和阅读边距离，再更新 Cell/Header，使用 iOS 15 的 reconfigureItems 请求重新测量自适应 Cell，使布局失效，最后根据新 attributes 恢复纵向阅读锚点和选择。

该默认 reconfigureItems 分支针对普通 UICollectionViewDataSource，正如两个示例。Diffable Data Source 应由业务通过 snapshot.reconfigureItems 刷新并在 apply completion 后完成布局恢复，不应直接使用普通数据源的 reconfigureItems(at:) 刷新路径。当前示例没有实现 Diffable 适配器。

## 横向分页 section

混合布局第 0 个 section 使用 `.groupPagingCentered`，一组一个卡片；第 1 个 section 是纵向网格。横向卡片在 RTL 中故意变宽，用于验证尺寸变化后的当前页保留。

```swift
section.orthogonalScrollingBehavior = .groupPagingCentered
section.visibleItemsInvalidationHandler = { [weak self] items, offset, environment in
    self?.orthogonalLocalization?.record(
        section: sectionIndex, items: items, offset: offset, environment: environment
    )
}
```

`OrthogonalLocalizationCoordinator` 从公开回调记录中心卡片的业务 ID，在语言切换前冻结快照；主列表布局完成后，使用公开的 scrollToItem(.centeredHorizontally) 恢复该业务页，再恢复外层纵向位置。它不查找 UIKit 私有子视图，不使用 KVC 或私有滚动容器类型。

此策略保留“中心业务页”，不保存系统内部横向 scroll view 的像素 contentOffset。切换发生在横向滑动中间时，以最近中心项重新居中。验收范围为 `.groupPagingCentered` 且每组一个 item；多 item group、continuous 与任意小数偏移需要不同的状态定义和测试。

主列表的 `anchorFilter` 排除正交 section；当视口顶部仍在横向区域时保留外层 offset，进入网格区域后按网格业务 ID 保存锚点。这样下方翻译变高不会把顶部横向页面推走。正交 section 隐藏时恢复它的业务页，也不能把外层网格拉回顶部。

## Cell 与页面生命周期

Cell 创建和 willDisplay 始终读取最新 context；Header 也在创建、willDisplay 与可见刷新时更新。草稿保存在业务 ID 字典里，切换只更新静态文案和 placeholder。尺寸更新可能触发系统正常复用；不依赖 Cell 实例存储草稿。

页面强持有两个协调器，闭包 weak self。viewDidAppear 先刷新主列表，再完成正交页恢复。业务 batch/snapshot 与语言事务应串行安排；示例不接管并发数据重排。业务 ID 被删除时跳过该项恢复。

## 验证范围

新增两项 XCTest 分别验证网格的 RTL 视觉顺序、自适应高度、草稿/选择、阅读锚点及导航栈；正交 section 的中心业务页、相邻项物理方向、宽度变化、草稿/选择、外层锚点和隐藏后恢复。对应官方 MCP 结果见 verification/official-mcp-tests.json。运行环境为现有 iPhone 17 Pro / iOS 26.5；iOS 15/16、iPad 和真机尚未重跑此扩展。

官方参考：[Compositional Layout](https://developer.apple.com/documentation/uikit/uicollectionviewcompositionallayout)、[镜像规则](https://developer.apple.com/documentation/uikit/uicollectionviewlayout/flipshorizontallyinoppositelayoutdirection)、[reconfigureItems](https://developer.apple.com/documentation/uikit/uicollectionview/reconfigureitems(at:))、[正交滚动行为](https://developer.apple.com/documentation/uikit/nscollectionlayoutsection/orthogonalscrollingbehavior)。

## 系统语言重启恢复

新增 `NSUserActivity` 桥接：保存稳定业务项、相对阅读距离、选择、草稿；正交分区还保存中心业务项 ID。重启后的新列表在进入窗口并完成测量后应用 pending 状态。接入和已测范围见 [STATE_RESTORATION.md](STATE_RESTORATION.md)。
