import Foundation

final class SessionStore {
    private var states: [String: WatchState] = [:]

    func state(for bundleID: String) -> WatchState {
        states[bundleID] ?? .watched
    }

    func set(_ bundleID: String, _ state: WatchState) {
        states[bundleID] = state
    }

    func clear(_ bundleID: String) {
        states.removeValue(forKey: bundleID)
    }

    func optimizedBundleIDs() -> [String] {
        states.compactMap { $0.value == .optimized ? $0.key : nil }.sorted()
    }

    func resetAll() {
        states.removeAll()
    }
}
