import XCTest
@testable import RenderPausePro

final class RuleStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: RuleStore!

    override func setUp() {
        super.setUp()
        suiteName = "RuleStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = RuleStore(defaults: defaults)
    }

    override func tearDown() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        super.tearDown()
    }

    func testStartsEmpty() {
        XCTAssertTrue(store.rules.isEmpty)
    }

    func testAddAndPersist() {
        let rule = AppRule(
            bundleID: "com.apple.Notes",
            displayName: "Notes",
            enabled: true,
            action: .hide,
            idleSeconds: 30,
            locked: false
        )
        XCTAssertTrue(store.upsert(rule))
        XCTAssertEqual(store.rules.count, 1)

        let reloaded = RuleStore(defaults: defaults)
        XCTAssertEqual(reloaded.rules.first?.bundleID, "com.apple.Notes")
        XCTAssertEqual(reloaded.rules.first?.action, .hide)
    }

    func testUpsertReplacesSameBundle() {
        _ = store.upsert(AppRule(bundleID: "a.b", displayName: "A", enabled: true, action: .hide, idleSeconds: 30, locked: false))
        _ = store.upsert(AppRule(bundleID: "a.b", displayName: "A2", enabled: false, action: .minimize, idleSeconds: 60, locked: true))
        XCTAssertEqual(store.rules.count, 1)
        XCTAssertEqual(store.rules[0].displayName, "A2")
        XCTAssertEqual(store.rules[0].action, .minimize)
        XCTAssertEqual(store.rules[0].idleSeconds, 60)
        XCTAssertTrue(store.rules[0].locked)
        XCTAssertFalse(store.rules[0].enabled)
    }

    func testRemove() {
        _ = store.upsert(AppRule(bundleID: "a.b", displayName: "A", enabled: true, action: .hide, idleSeconds: 30, locked: false))
        store.remove(bundleID: "a.b")
        XCTAssertTrue(store.rules.isEmpty)
    }

    func testClampIdleSeconds() {
        _ = store.upsert(AppRule(bundleID: "a.b", displayName: "A", enabled: true, action: .hide, idleSeconds: 1, locked: false))
        XCTAssertEqual(store.rules[0].idleSeconds, 5)
        _ = store.upsert(AppRule(bundleID: "a.b", displayName: "A", enabled: true, action: .hide, idleSeconds: 9999, locked: false))
        XCTAssertEqual(store.rules[0].idleSeconds, 600)
    }

    func testRejectSelfBundle() {
        let selfID = BundleIdentity.bundleID
        let ok = store.upsert(AppRule(bundleID: selfID, displayName: "Self", enabled: true, action: .hide, idleSeconds: 30, locked: false))
        XCTAssertFalse(ok)
        XCTAssertTrue(store.rules.isEmpty)
    }
}
