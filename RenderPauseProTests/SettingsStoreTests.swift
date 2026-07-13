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
            $0.backgroundSeconds = 45
        }
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.settings.monitoringEnabled)
        XCTAssertTrue(reloaded.settings.hasCompletedOnboarding)
        XCTAssertFalse(reloaded.settings.launchAtLogin)
        XCTAssertEqual(reloaded.settings.backgroundSeconds, 45)
        defaults.removePersistentDomain(forName: suite)
    }

    func testClampsBackgroundSeconds() {
        let suite = "SettingsStoreClamp.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = SettingsStore(defaults: defaults)
        store.update { $0.backgroundSeconds = 1 }
        XCTAssertEqual(store.settings.backgroundSeconds, 5)
        store.update { $0.backgroundSeconds = 9999 }
        XCTAssertEqual(store.settings.backgroundSeconds, 600)
        defaults.removePersistentDomain(forName: suite)
    }

    func testDefaultBackgroundSecondsIs30() {
        let suite = "SettingsStoreDefault.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings.backgroundSeconds, 30)
        defaults.removePersistentDomain(forName: suite)
    }
}
