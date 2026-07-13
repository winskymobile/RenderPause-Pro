import Foundation

enum OptimizeAction: String, Codable, CaseIterable, Sendable {
    case hide
    case minimize

    var titleZH: String {
        switch self {
        case .hide: return "隐藏"
        case .minimize: return "最小化"
        }
    }
}

struct AppRule: Codable, Identifiable, Equatable, Sendable {
    var bundleID: String
    var displayName: String
    var enabled: Bool
    var action: OptimizeAction
    var idleSeconds: TimeInterval
    var locked: Bool

    var id: String { bundleID }

    static let idleRange: ClosedRange<TimeInterval> = 5...600
    static let defaultIdle: TimeInterval = 30

    mutating func normalize() {
        idleSeconds = min(max(idleSeconds, Self.idleRange.lowerBound), Self.idleRange.upperBound)
    }

    static func makeNew(bundleID: String, displayName: String) -> AppRule {
        var rule = AppRule(
            bundleID: bundleID,
            displayName: displayName,
            enabled: true,
            action: .hide,
            idleSeconds: defaultIdle,
            locked: false
        )
        rule.normalize()
        return rule
    }
}
