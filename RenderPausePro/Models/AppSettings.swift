import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var monitoringEnabled: Bool
    var launchAtLogin: Bool
    var hasCompletedOnboarding: Bool
    /// Global seconds an app must stay fully occluded in background before optimize.
    var backgroundSeconds: TimeInterval
    /// Global hide mode for all watched apps.
    var optimizeAction: OptimizeAction

    static let backgroundRange: ClosedRange<TimeInterval> = 5...600
    static let defaultBackgroundSeconds: TimeInterval = 30

    static let `default` = AppSettings(
        monitoringEnabled: true,
        launchAtLogin: true,
        hasCompletedOnboarding: false,
        backgroundSeconds: defaultBackgroundSeconds,
        optimizeAction: .hide
    )

    mutating func normalize() {
        backgroundSeconds = min(
            max(backgroundSeconds, Self.backgroundRange.lowerBound),
            Self.backgroundRange.upperBound
        )
    }

    init(
        monitoringEnabled: Bool,
        launchAtLogin: Bool,
        hasCompletedOnboarding: Bool,
        backgroundSeconds: TimeInterval,
        optimizeAction: OptimizeAction = .hide
    ) {
        self.monitoringEnabled = monitoringEnabled
        self.launchAtLogin = launchAtLogin
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.backgroundSeconds = backgroundSeconds
        self.optimizeAction = optimizeAction
        normalize()
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        monitoringEnabled = try c.decodeIfPresent(Bool.self, forKey: .monitoringEnabled) ?? true
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        backgroundSeconds = try c.decodeIfPresent(TimeInterval.self, forKey: .backgroundSeconds)
            ?? Self.defaultBackgroundSeconds
        optimizeAction = try c.decodeIfPresent(OptimizeAction.self, forKey: .optimizeAction) ?? .hide
        normalize()
    }

    private enum CodingKeys: String, CodingKey {
        case monitoringEnabled, launchAtLogin, hasCompletedOnboarding, backgroundSeconds, optimizeAction
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(monitoringEnabled, forKey: .monitoringEnabled)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
        try c.encode(backgroundSeconds, forKey: .backgroundSeconds)
        try c.encode(optimizeAction, forKey: .optimizeAction)
    }
}
