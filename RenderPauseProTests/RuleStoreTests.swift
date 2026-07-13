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
            action: .hide
        )
        XCTAssertTrue(store.upsert(rule))
        XCTAssertEqual(store.rules.count, 1)

        let reloaded = RuleStore(defaults: defaults)
        XCTAssertEqual(reloaded.rules.first?.bundleID, "com.apple.Notes")
        XCTAssertEqual(reloaded.rules.first?.action, .hide)
    }

    func testUpsertReplacesSameBundle() {
        _ = store.upsert(AppRule(bundleID: "a.b", displayName: "A", enabled: true, action: .hide))
        _ = store.upsert(AppRule(bundleID: "a.b", displayName: "A2", enabled: false, action: .minimize))
        XCTAssertEqual(store.rules.count, 1)
        XCTAssertEqual(store.rules[0].displayName, "A2")
        XCTAssertEqual(store.rules[0].action, .minimize)
        XCTAssertFalse(store.rules[0].enabled)
    }

    func testRemove() {
        _ = store.upsert(AppRule(bundleID: "a.b", displayName: "A", enabled: true, action: .hide))
        store.remove(bundleID: "a.b")
        XCTAssertTrue(store.rules.isEmpty)
    }

    func testRejectSelfBundle() {
        let selfID = BundleIdentity.bundleID
        let ok = store.upsert(AppRule(bundleID: selfID, displayName: "Self", enabled: true, action: .hide))
        XCTAssertFalse(ok)
        XCTAssertTrue(store.rules.isEmpty)
    }

    func testLoadsLegacyPayloadIgnoringExtraFields() {
        let legacy = """
        [{"bundleID":"com.legacy.app","displayName":"Legacy","enabled":true,"action":"hide","idleSeconds":45,"locked":true}]
        """.data(using: .utf8)!
        defaults.set(legacy, forKey: "rules.v1")
        let reloaded = RuleStore(defaults: defaults)
        XCTAssertEqual(reloaded.rules.count, 1)
        XCTAssertEqual(reloaded.rules[0].bundleID, "com.legacy.app")
        XCTAssertEqual(reloaded.rules[0].action, .hide)
    }
}
