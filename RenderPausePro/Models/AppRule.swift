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

    var id: String { bundleID }

    static func makeNew(bundleID: String, displayName: String) -> AppRule {
        AppRule(
            bundleID: bundleID,
            displayName: displayName,
            enabled: true,
            action: .hide
        )
    }

    /// Tolerate legacy payloads that still contain idleSeconds/locked.
    init(bundleID: String, displayName: String, enabled: Bool, action: OptimizeAction) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.enabled = enabled
        self.action = action
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bundleID = try c.decode(String.self, forKey: .bundleID)
        displayName = try c.decode(String.self, forKey: .displayName)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        action = try c.decodeIfPresent(OptimizeAction.self, forKey: .action) ?? .hide
    }

    private enum CodingKeys: String, CodingKey {
        case bundleID, displayName, enabled, action
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(bundleID, forKey: .bundleID)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(action, forKey: .action)
    }
}
