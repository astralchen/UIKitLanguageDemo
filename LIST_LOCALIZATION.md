# UITableView / UICollectionView 运行时语言切换

实现位于 `UIKitLanguageDemo/Localization/ListLocalizationCoordinator.swift`。设置 Tab 是可变行高 UITableView；首页提供两列网格和横向卡片 UICollectionView。示例包含 80 个稳定业务 ID、中英阿三语、Header、可编辑草稿及多选。

## 刷新事务

LanguageService 在 MainActor 同步发送三个通知，object 都是当前服务：

1. `appLanguageWillChange`：尚未修改语言和布局方向，记录选中项业务 ID、首个可见业务 ID 及其相对阅读边的距离。
2. `appLanguageDidChange`：已更新 context 和窗口方向；刷新页面、可见 Cell 和 Header/Footer，并标记列表需要重新测量。
3. `appLanguageDidApplyLayout`：所有注册窗口已执行布局；Table 通过空 beginUpdates/endUpdates 重测自动行高，Collection 执行失效后的布局，再按业务 ID 恢复选择和锚点。Collection 使用布局新计算的 attributes，而不是失效期间 Cell 尚未更新的旧 frame。

恢复结束后，服务才恢复仍聚焦输入框的文本选区。不替换根控制器，不重建导航栈、列表或数据源。语言刷新不调用 reloadData，也不反转业务数组。

## 接入 UITableView

页面强持有协调器；协调器弱引用列表，所有捕获页面的闭包使用 weak self。`itemID` / `indexPath` 必须映射同一份当前业务数据。

```swift
private var localization: TableLocalizationCoordinator!

// buildUI 中，在设置 datasource、delegate、注册 Cell 之后：
localization = TableLocalizationCoordinator(
    tableView: tableView,
    itemID: { [weak self] path in self?.modelID(at: path) },
    indexPath: { [weak self] id in self?.indexPath(for: id) },
    renderCell: { [weak self] cell, path, context in
        self?.render(cell, at: path, context: context)
    },
    renderSupplementary: { [weak self] context in
        self?.refreshVisibleHeadersAndFooters(context)
    }
)
```

以上模型方法由业务实现；可直接参考完整 `SettingsViewController.swift`。自动行高需完整上下约束、`rowHeight = .automaticDimension` 和合理 estimatedRowHeight。翻译会改变行高，不能只保存旧 contentOffset。顶部锚点使用稳定 ID 和行顶相对可视区顶部的距离，恢复时使用新行高，并限制在合法滚动范围；靠近内容首尾时距离可能因边界约束而改变。

## 接入 UICollectionView

```swift
localization = CollectionLocalizationCoordinator(
    collectionView: collectionView,
    axis: .horizontal, // 或 .vertical
    itemID: { [weak self] path in self?.modelID(at: path) },
    indexPath: { [weak self] id in self?.indexPath(for: id) },
    renderCell: { [weak self] cell, path, context in
        self?.render(cell, at: path, context: context)
    },
    renderSupplementary: { [weak self] context in
        self?.refreshVisibleSupplementaryViews(context)
    }
)
```

可运行版本见 `CollectionDemoViewController.swift`。`LocalizedCollectionFlowLayout` 直接继承系统 FlowLayout 的 RTL 排列，不额外启用自动镜像、变换或反转业务数组。切换时通过 `UICollectionViewFlowLayoutInvalidationContext` 同时使 delegate metrics 和 attributes 失效，重新查询翻译后的尺寸。纵向列表保持顶部业务项；横向列表保持逻辑起始边的业务项和距离，LTR 为左边、RTL 为右边。选中项按 ID 映射回新 IndexPath。

示例使用 delegate 依据当前翻译测量卡片高度，横向示例还故意在 RTL 改变卡片宽度，用于检验锚点恢复。本工程现已增加 Compositional 的 estimated 自适应网格和每组一项的 groupPagingCentered 正交分区，见 [组合布局接入说明](COMPOSITIONAL_LAYOUT.md)。任意自定义 Layout、多项 group 和 continuous 正交偏移不在验收范围。

## 复用、Header 和输入状态

协调器只原地配置当前可见视图；所有 `cellForRowAt` / `cellForItemAt` 和 `willDisplay` 都必须从最新 context 渲染，确保预取或已缓存但尚未显示的 Cell 不带旧文案。Header/Footer 和 supplementary 同样在创建、willDisplay 及可见刷新三处处理。

草稿保存在按业务 ID 索引的模型字典中。Cell 绑定新 ID 时从模型恢复，editingChanged 写回模型；同一 ID 的语言刷新仅改 label、placeholder、accessibility，不覆盖用户输入。真实业务应把该字典放在持久化 ViewModel 中。尺寸和方向变化可能触发 UIKit 正常回收/显示 Cell，因此不承诺 Collection Cell 实例恒定；草稿由稳定 ID 模型保留，选区只对仍聚焦且文本未变的输入框恢复。

## 页面隐藏、手势和业务更新

在 viewDidAppear 调用 `localization.refreshAfterAppearance()`，使隐藏期间尚未完成的测量和锚点在重新显示时完成。协调器遇到未提交的批量更新会暂缓测量；业务 batch/snapshot completion 中也应调用此方法。

不要在语言通知回调里同时替换业务 snapshot、重排数据或再次提交 batch。请由页面串行安排业务更新与语言事务；稳定 ID 映射可以适配 diffable datasource，但本示例不代管其 snapshot 动画。用户正在拖动或减速时仍更新文案和布局，不强制恢复旧锚点，以免抢夺手势。首尾无法满足的锚点偏移会被裁剪到内容边界。

## 回归测试

新增四项 XCTest：Table 同一 Cell 的草稿/选择和自动行高；Table 多次切换后的阅读锚点与复用草稿；Collection 网格 RTL 镜像、Header、草稿/选择及滚动锚点；横向 Collection 改变卡片宽度后的逻辑起始项保留。原六项容器、导航、资源测试保留。实际官方 MCP 结果见 verification/。

组合布局扩展：新增两项 XCTest，当前共十二项；Compositional 默认 reconfigure 分支使用普通数据源，Diffable 需自行通过 snapshot 刷新，详见 COMPOSITIONAL_LAYOUT.md。

## 系统语言重启恢复

新增 `NSUserActivity` 桥接：保存稳定业务项、相对阅读距离、选择、草稿；正交分区还保存中心业务项 ID。重启后的新列表在进入窗口并完成测量后应用 pending 状态。接入和已测范围见 [STATE_RESTORATION.md](STATE_RESTORATION.md)。
