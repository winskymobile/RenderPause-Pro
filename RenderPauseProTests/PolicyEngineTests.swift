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

    private func snap(
        id: String,
        active: Bool = false,
        hidden: Bool = false,
        finished: Bool = false,
        since: TimeInterval = 0
    ) -> RunningAppSnapshot {
        RunningAppSnapshot(
            bundleID: id,
            isActive: active,
            isHidden: hidden,
            isFinished: finished,
            secondsSinceDeactivated: since
        )
    }

    func testNoRulesNoCommands() {
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            running: []
        )
        XCTAssertTrue(cmds.isEmpty)
    }

    func testOptimizeWhenBackgroundLongEnough() {
        _ = rules.upsert(.makeNew(bundleID: "com.demo.app", displayName: "Demo"))
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            running: [snap(id: "com.demo.app", since: 30)]
        )
        XCTAssertTrue(cmds.contains(where: {
            if case .optimize(let id, .hide, _) = $0, id == "com.demo.app" { return true }
            return false
        }))
    }

    func testDoNotOptimizeWhenFrontmost() {
        _ = rules.upsert(.makeNew(bundleID: "com.demo.app", displayName: "Demo"))
        let cmds = engine.evaluate(
            frontmostBundleID: "com.demo.app",
            running: [snap(id: "com.demo.app", active: true, since: 999)]
        )
        XCTAssertFalse(cmds.contains(where: {
            if case .optimize = $0 { return true }
            return false
        }))
    }

    func testDoNotOptimizeWhenBackgroundTooShort() {
        var rule = AppRule.makeNew(bundleID: "com.demo.app", displayName: "Demo")
        rule.idleSeconds = 60
        _ = rules.upsert(rule)
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            running: [snap(id: "com.demo.app", since: 10)]
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
            running: [snap(id: "com.demo.app", active: true, hidden: true, since: 0)]
        )
        XCTAssertTrue(cmds.contains(.restore(bundleID: "com.demo.app", action: .hide, reason: "activated")))
    }

    func testLockedNeverOptimizes() {
        var rule = AppRule.makeNew(bundleID: "com.demo.app", displayName: "Demo")
        rule.locked = true
        _ = rules.upsert(rule)
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            running: [snap(id: "com.demo.app", since: 999)]
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
            running: [snap(id: "com.demo.app", since: 999)]
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
            running: [snap(id: "com.demo.app", since: 999)]
        )
        XCTAssertTrue(cmds.contains(.setState(bundleID: "com.demo.app", state: .paused)))
    }

    func testHidePathSkipsIfAlreadyHidden() {
        _ = rules.upsert(.makeNew(bundleID: "com.demo.app", displayName: "Demo"))
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            running: [snap(id: "com.demo.app", hidden: true, since: 999)]
        )
        XCTAssertFalse(cmds.contains(where: {
            if case .optimize = $0 { return true }
            return false
        }))
        XCTAssertTrue(cmds.contains(.setState(bundleID: "com.demo.app", state: .optimized)))
    }

    func testSystemInputBusyDoesNotBlockBackgroundOptimize() {
        // Regression: previously used global input idle; moving mouse while another app
        // is frontmost must still allow optimizing background targets.
        _ = rules.upsert(.makeNew(bundleID: "com.demo.app", displayName: "Demo"))
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.Safari",
            running: [snap(id: "com.demo.app", since: 30)]
        )
        XCTAssertTrue(cmds.contains(where: {
            if case .optimize(let id, _, _) = $0, id == "com.demo.app" { return true }
            return false
        }))
    }
}
