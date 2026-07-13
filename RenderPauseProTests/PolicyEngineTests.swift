import XCTest
@testable import RenderPausePro

final class PolicyEngineTests: XCTestCase {
    private var rules: RuleStore!
    private var session: SessionStore!
    private var settings: SettingsStore!
    private var engine: PolicyEngine!
    private var suites: [String] = []

    override func setUp() {
        super.setUp()
        let rSuite = UUID().uuidString
        let sSuite = UUID().uuidString
        suites = [rSuite, sSuite]
        rules = RuleStore(defaults: UserDefaults(suiteName: rSuite)!)
        session = SessionStore()
        settings = SettingsStore(defaults: UserDefaults(suiteName: sSuite)!)
        engine = PolicyEngine(ruleStore: rules, sessionStore: session, settingsStore: settings)
    }

    override func tearDown() {
        for s in suites {
            UserDefaults().removePersistentDomain(forName: s)
        }
        super.tearDown()
    }

    func testNoRulesNoCommands() {
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            idleSeconds: 120,
            running: []
        )
        XCTAssertTrue(cmds.isEmpty)
    }

    func testOptimizeWhenInactiveAndIdle() {
        _ = rules.upsert(.makeNew(bundleID: "com.demo.app", displayName: "Demo"))
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            idleSeconds: 30,
            running: [RunningAppSnapshot(bundleID: "com.demo.app", isActive: false, isHidden: false, isFinished: false)]
        )
        XCTAssertTrue(cmds.contains(.optimize(bundleID: "com.demo.app", action: .hide, reason: "inactive+idle")))
    }

    func testDoNotOptimizeWhenFrontmost() {
        _ = rules.upsert(.makeNew(bundleID: "com.demo.app", displayName: "Demo"))
        let cmds = engine.evaluate(
            frontmostBundleID: "com.demo.app",
            idleSeconds: 999,
            running: [RunningAppSnapshot(bundleID: "com.demo.app", isActive: true, isHidden: false, isFinished: false)]
        )
        XCTAssertFalse(cmds.contains(where: {
            if case .optimize = $0 { return true }
            return false
        }))
    }

    func testDoNotOptimizeWhenIdleTooLow() {
        var rule = AppRule.makeNew(bundleID: "com.demo.app", displayName: "Demo")
        rule.idleSeconds = 60
        _ = rules.upsert(rule)
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            idleSeconds: 10,
            running: [RunningAppSnapshot(bundleID: "com.demo.app", isActive: false, isHidden: false, isFinished: false)]
        )
        XCTAssertFalse(cmds.contains(where: {
            if case .optimize = $0 { return true }
            return false
        }))
    }

    func testRestoreWhenBecomesActive() {
        _ = rules.upsert(.makeNew(bundleID: "com.demo.app", displayName: "Demo"))
        session.set("com.demo.app", .optimized)
        let cmds = engine.evaluate(
            frontmostBundleID: "com.demo.app",
            idleSeconds: 0,
            running: [RunningAppSnapshot(bundleID: "com.demo.app", isActive: true, isHidden: true, isFinished: false)]
        )
        XCTAssertTrue(cmds.contains(.restore(bundleID: "com.demo.app", action: .hide, reason: "activated")))
    }

    func testLockedNeverOptimizes() {
        var rule = AppRule.makeNew(bundleID: "com.demo.app", displayName: "Demo")
        rule.locked = true
        _ = rules.upsert(rule)
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            idleSeconds: 999,
            running: [RunningAppSnapshot(bundleID: "com.demo.app", isActive: false, isHidden: false, isFinished: false)]
        )
        XCTAssertTrue(cmds.contains(.setState(bundleID: "com.demo.app", state: .paused)))
        XCTAssertFalse(cmds.contains(where: {
            if case .optimize = $0 { return true }
            return false
        }))
    }

    func testMonitoringDisabledSkipsOptimize() {
        settings.update { $0.monitoringEnabled = false }
        _ = rules.upsert(.makeNew(bundleID: "com.demo.app", displayName: "Demo"))
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            idleSeconds: 999,
            running: [RunningAppSnapshot(bundleID: "com.demo.app", isActive: false, isHidden: false, isFinished: false)]
        )
        XCTAssertFalse(cmds.contains(where: {
            if case .optimize = $0 { return true }
            return false
        }))
    }

    func testTempExemptionPreventsOptimize() {
        _ = rules.upsert(.makeNew(bundleID: "com.demo.app", displayName: "Demo"))
        engine.exempt(bundleID: "com.demo.app", until: Date().addingTimeInterval(600))
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            idleSeconds: 999,
            running: [RunningAppSnapshot(bundleID: "com.demo.app", isActive: false, isHidden: false, isFinished: false)]
        )
        XCTAssertTrue(cmds.contains(.setState(bundleID: "com.demo.app", state: .paused)))
    }

    func testHidePathSkipsIfAlreadyHidden() {
        _ = rules.upsert(.makeNew(bundleID: "com.demo.app", displayName: "Demo"))
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            idleSeconds: 999,
            running: [RunningAppSnapshot(bundleID: "com.demo.app", isActive: false, isHidden: true, isFinished: false)]
        )
        XCTAssertFalse(cmds.contains(.optimize(bundleID: "com.demo.app", action: .hide, reason: "inactive+idle")))
        XCTAssertTrue(cmds.contains(.setState(bundleID: "com.demo.app", state: .optimized)))
    }
}
