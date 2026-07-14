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
        since: TimeInterval = 0,
        partiallyVisible: Bool = false
    ) -> RunningAppSnapshot {
        RunningAppSnapshot(
            bundleID: id,
            isActive: active,
            isHidden: hidden,
            isFinished: finished,
            secondsSinceDeactivated: since,
            isPartiallyVisible: partiallyVisible
        )
    }

    func testNoRulesNoCommands() {
        let cmds = engine.evaluate(frontmostBundleID: "com.apple.finder", running: [])
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

    func testUsesGlobalBackgroundSeconds() {
        settings.update { $0.backgroundSeconds = 60 }
        _ = rules.upsert(.makeNew(bundleID: "com.demo.app", displayName: "Demo"))
        let tooSoon = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            running: [snap(id: "com.demo.app", since: 30)]
        )
        XCTAssertFalse(tooSoon.contains(where: {
            if case .optimize = $0 { return true }
            return false
        }))
        let ready = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            running: [snap(id: "com.demo.app", since: 60)]
        )
        XCTAssertTrue(ready.contains(where: {
            if case .optimize = $0 { return true }
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

    func testRestoreWhenBecomesActive() {
        _ = rules.upsert(.makeNew(bundleID: "com.demo.app", displayName: "Demo"))
        session.set("com.demo.app", .optimized)
        let cmds = engine.evaluate(
            frontmostBundleID: "com.demo.app",
            running: [snap(id: "com.demo.app", active: true, hidden: true, since: 0)]
        )
        XCTAssertTrue(cmds.contains(.restore(bundleID: "com.demo.app", action: .hide, reason: "activated")))
    }

    func testDisabledRulePauses() {
        var rule = AppRule.makeNew(bundleID: "com.demo.app", displayName: "Demo")
        rule.enabled = false
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

    func testUsesGlobalOptimizeAction() {
        settings.update { $0.optimizeAction = .minimize }
        _ = rules.upsert(.makeNew(bundleID: "com.demo.app", displayName: "Demo"))
        let cmds = engine.evaluate(
            frontmostBundleID: "com.apple.finder",
            running: [snap(id: "com.demo.app", since: 30)]
        )
        XCTAssertTrue(cmds.contains(where: {
            if case .optimize(_, .minimize, _) = $0 { return true }
            return false
        }))
    }
}
