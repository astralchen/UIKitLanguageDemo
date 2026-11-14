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
    enum Route: String, Codable { case home, settings, detail, verticalCollection, horizontalCollection, compositionalGrid, compositionalCarousel, pager, splitMenu }
    var route: Route
    var draft: String?
    var list: SavedListState?
    var currentPageID: String?
    var pageDrafts: [String: String] = [:]
}

struct SavedSplitState: Codable, Equatable {
    var primary: [SavedPageState]
    var secondary: [SavedPageState]
    var showsSecondary: Bool
}

struct SavedSceneState: Codable, Equatable {
    var version = 1
    var identifier = UUID().uuidString
    var selectedTab = 0
    var stacks: [[SavedPageState]]
    var split: SavedSplitState?
}

/// Only property-list-compatible Data travels through NSUserActivity.
enum SceneStateCodec {
    static let activityType = "com.example.UIKitLanguageDemo.scene"
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
    static func activity(for state: SavedSceneState) -> NSUserActivity? {
        guard valid(state), let data = try? JSONEncoder().encode(state), data.count <= maximumBytes else { return nil }
        let activity = NSUserActivity(activityType: activityType)
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
        guard state.version == 1, UUID(uuidString: state.identifier) != nil,
              state.stacks.count == 2, (0..<2).contains(state.selectedTab),
              state.stacks[0].first?.route == .home, state.stacks[1].first?.route == .settings else { return false }
        let stacks = state.stacks + (state.split.map { [$0.primary, $0.secondary] } ?? [])
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
