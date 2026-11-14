import UIKit

struct SavedListState: Codable, Equatable {
    var anchorID: Int?
    var distance: Double = 0
    var selectedIDs: [Int] = []
    var drafts: [Int: String] = [:]
    var startDistance: Double = 0
    var orthogonalCenters: [Int: Int] = [:]
}

struct SavedPageState: Codable, Equatable {
    enum Route: String, Codable { case home, settings, detail, verticalCollection, horizontalCollection, compositionalGrid, compositionalCarousel, pager, splitMenu, splitSupplementary }
    var route: Route
    var draft: String?
    var list: SavedListState?
    var currentPageID: String?
    var pageDrafts: [String: String] = [:]
}

enum SavedSplitColumn: String, Codable {
    case primary, supplementary, secondary
    var uiKit: UISplitViewController.Column {
        switch self { case .primary: return .primary; case .supplementary: return .supplementary; case .secondary: return .secondary }
    }
    init?(_ column: UISplitViewController.Column) {
        switch column { case .primary: self = .primary; case .supplementary: self = .supplementary; case .secondary: self = .secondary; default: return nil }
    }
}

enum SavedSplitStyle: String, Codable { case doubleColumn, tripleColumn }
enum SavedSplitDisplayMode: String, Codable {
    case secondaryOnly, oneBesideSecondary, twoBesideSecondary, oneOverSecondary, twoOverSecondary, twoDisplaceSecondary
    var uiKit: UISplitViewController.DisplayMode {
        switch self {
        case .secondaryOnly: return .secondaryOnly
        case .oneBesideSecondary: return .oneBesideSecondary
        case .twoBesideSecondary: return .twoBesideSecondary
        case .oneOverSecondary: return .oneOverSecondary
        case .twoOverSecondary: return .twoOverSecondary
        case .twoDisplaceSecondary: return .twoDisplaceSecondary
        }
    }
    init?(_ mode: UISplitViewController.DisplayMode) {
        switch mode {
        case .secondaryOnly: self = .secondaryOnly
        case .oneBesideSecondary: self = .oneBesideSecondary
        case .twoBesideSecondary: self = .twoBesideSecondary
        case .oneOverSecondary: self = .oneOverSecondary
        case .twoOverSecondary: self = .twoOverSecondary
        case .twoDisplaceSecondary: self = .twoDisplaceSecondary
        default: return nil
        }
    }
}

struct SavedSplitState: Codable, Equatable {
    var primary: [SavedPageState]
    var secondary: [SavedPageState]
    var style: SavedSplitStyle = .doubleColumn
    var supplementary: [SavedPageState]?
    var compactColumn: SavedSplitColumn = .primary
    var expandedMode: SavedSplitDisplayMode = .oneBesideSecondary
    var showsSecondary: Bool { compactColumn == .secondary }

    init(primary: [SavedPageState], secondary: [SavedPageState], showsSecondary: Bool,
         style: SavedSplitStyle = .doubleColumn, supplementary: [SavedPageState]? = nil,
         compactColumn: SavedSplitColumn? = nil, expandedMode: SavedSplitDisplayMode = .oneBesideSecondary) {
        self.primary = primary; self.secondary = secondary; self.style = style
        self.supplementary = supplementary
        self.compactColumn = compactColumn ?? (showsSecondary ? .secondary : .primary)
        self.expandedMode = expandedMode
    }
    private enum CodingKeys: String, CodingKey { case primary, secondary, style, supplementary, compactColumn, expandedMode, showsSecondary }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        primary = try c.decode([SavedPageState].self, forKey: .primary)
        secondary = try c.decode([SavedPageState].self, forKey: .secondary)
        style = try c.decodeIfPresent(SavedSplitStyle.self, forKey: .style) ?? .doubleColumn
        supplementary = try c.decodeIfPresent([SavedPageState].self, forKey: .supplementary)
        compactColumn = try c.decodeIfPresent(SavedSplitColumn.self, forKey: .compactColumn)
            ?? ((try c.decodeIfPresent(Bool.self, forKey: .showsSecondary) ?? false) ? .secondary : .primary)
        expandedMode = try c.decodeIfPresent(SavedSplitDisplayMode.self, forKey: .expandedMode) ?? .oneBesideSecondary
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(primary, forKey: .primary); try c.encode(secondary, forKey: .secondary)
        try c.encode(style, forKey: .style); try c.encodeIfPresent(supplementary, forKey: .supplementary)
        try c.encode(compactColumn, forKey: .compactColumn); try c.encode(expandedMode, forKey: .expandedMode)
    }
}

struct SavedSceneState: Codable, Equatable {
    var version = 2
    var sceneSessionID: String?
    var windowNumber: Int?
    var identifier = UUID().uuidString
    var selectedTab = 0
    var stacks: [[SavedPageState]]
    var split: SavedSplitState?
}

/// Only property-list-compatible Data travels through NSUserActivity.
enum SceneStateCodec {
    static let activityType = "com.example.UIKitLanguageDemo.scene"
    static let activationType = "com.example.UIKitLanguageDemo.scene.copy"
    static let payloadKey = "sceneState.v1"
    static let maximumBytes = 512 * 1024

    static func decode(_ activity: NSUserActivity) -> SavedSceneState? {
        guard activity.activityType == activityType,
              let data = activity.userInfo?[payloadKey] as? Data else { return nil }
        return decode(data)
    }
    static func decode(_ data: Data) -> SavedSceneState? {
        guard data.count <= maximumBytes,
              let state = try? JSONDecoder().decode(SavedSceneState.self, from: data), valid(state) else { return nil }
        return state
    }
    static func activation(for state: SavedSceneState) -> NSUserActivity? {
        var copy = state
        copy.identifier = UUID().uuidString
        copy.sceneSessionID = nil
        copy.windowNumber = nil
        return activity(for: copy, type: activationType)
    }
    static func decodeActivation(_ activity: NSUserActivity) -> SavedSceneState? {
        guard activity.activityType == activationType,
              let data = activity.userInfo?[payloadKey] as? Data,
              let state = decode(data), state.sceneSessionID == nil else { return nil }
        return state
    }
    static func activity(for state: SavedSceneState) -> NSUserActivity? { activity(for: state, type: activityType) }
    private static func activity(for state: SavedSceneState, type: String) -> NSUserActivity? {
        guard valid(state), let data = try? JSONEncoder().encode(state), data.count <= maximumBytes else { return nil }
        let activity = NSUserActivity(activityType: type)
        activity.title = "UIKit Language Demo"
        activity.userInfo = [payloadKey: data]
        activity.requiredUserInfoKeys = [payloadKey]
        activity.isEligibleForHandoff = false
        activity.isEligibleForSearch = false
        activity.isEligibleForPublicIndexing = false
        activity.isEligibleForPrediction = false
        return activity
    }
    private static func valid(_ state: SavedSceneState) -> Bool {
        guard [1, 2].contains(state.version), (state.sceneSessionID?.utf8.count ?? 0) <= 256,
              (state.windowNumber == nil || (1...1_000_000).contains(state.windowNumber!)), UUID(uuidString: state.identifier) != nil,
              state.stacks.count == 2, (0..<2).contains(state.selectedTab),
              state.stacks[0].first?.route == .home, state.stacks[1].first?.route == .settings else { return false }
        if let split = state.split {
            if split.style == .tripleColumn {
                guard split.supplementary?.isEmpty == false else { return false }
            } else {
                guard split.supplementary == nil, split.compactColumn != .supplementary,
                      ![.twoBesideSecondary, .twoOverSecondary, .twoDisplaceSecondary].contains(split.expandedMode) else { return false }
            }
        }
        let stacks = state.stacks + (state.split.map { [$0.primary, $0.secondary] + ($0.supplementary.map { [$0] } ?? []) } ?? [])
        return stacks.allSatisfy { stack in
            !stack.isEmpty && stack.count <= 16 && stack.allSatisfy { page in
                (page.draft?.utf8.count ?? 0) <= 16_384 && page.pageDrafts.count <= 3
                && page.pageDrafts.allSatisfy { ["page-1", "page-2", "page-3"].contains($0.key) && $0.value.utf8.count <= 16_384 }
                && (page.currentPageID == nil || ["page-1", "page-2", "page-3"].contains(page.currentPageID!))
                && (page.list.map { list in
                    list.distance.isFinite && abs(list.distance) <= 100_000 && list.startDistance.isFinite
                    && abs(list.startDistance) <= 1_000_000 && list.selectedIDs.count <= 200 && list.drafts.count <= 200
                    && list.orthogonalCenters.count <= 10 && list.drafts.values.allSatisfy { $0.utf8.count <= 16_384 }
                } ?? true)
            }
        }
    }
}
