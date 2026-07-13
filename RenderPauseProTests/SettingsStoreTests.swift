import XCTest
@testable import RenderPausePro

final class SettingsStoreTests: XCTestCase {
    func testRoundTrip() {
        let suite = "SettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = SettingsStore(defaults: defaults)
        store.update {
            $0.monitoringEnabled = false
            $0.hasCompletedOnboarding = true
            $0.launchAtLogin = false
        }
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.settings.monitoringEnabled)
        XCTAssertTrue(reloaded.settings.hasCompletedOnboarding)
        XCTAssertFalse(reloaded.settings.launchAtLogin)
        defaults.removePersistentDomain(forName: suite)
    }
}
