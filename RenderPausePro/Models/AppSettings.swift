import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var monitoringEnabled: Bool
    var launchAtLogin: Bool
    var hasCompletedOnboarding: Bool

    static let `default` = AppSettings(
        monitoringEnabled: true,
        launchAtLogin: true,
        hasCompletedOnboarding: false
    )
}
