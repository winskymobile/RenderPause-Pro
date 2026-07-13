import Foundation

enum PolicyCommand: Equatable {
    case optimize(bundleID: String, action: OptimizeAction, reason: String)
    case restore(bundleID: String, action: OptimizeAction, reason: String)
    case setState(bundleID: String, state: WatchState)
}

struct RunningAppSnapshot: Equatable {
    var bundleID: String
    var isActive: Bool
    var isHidden: Bool
    var isFinished: Bool
    /// Seconds the app has continuously not been frontmost/active **and** fully occluded.
    var secondsSinceDeactivated: TimeInterval
    /// True when any significant on-screen window still has residual visible area.
    var isPartiallyVisible: Bool
}
