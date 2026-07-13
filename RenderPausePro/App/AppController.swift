import AppKit
import Foundation

final class AppController {
    static let shared = AppController()

    let ruleStore = RuleStore()
    let sessionStore = SessionStore()
    let settingsStore = SettingsStore()
    let actionLog = ActionLog()
    let workspace = WorkspaceSensor()
    lazy var engine = PolicyEngine(
        ruleStore: ruleStore,
        sessionStore: sessionStore,
        settingsStore: settingsStore
    )

    private var timer: Timer?
    private var menuBar: MenuBarController?
    private var preferences: PreferencesWindowController?
    private var onboardingWindow: NSWindow?

    private init() {}

    func start() {
        menuBar = MenuBarController(controller: self)
        workspace.onChange = { [weak self] in self?.tick() }
        workspace.start()
        ruleStore.onChange = { [weak self] in
            self?.menuBar?.reload()
            self?.tick()
        }
        settingsStore.onChange = { [weak self] in
            self?.menuBar?.reload()
            self?.tick()
        }
        actionLog.onChange = { [weak self] in self?.menuBar?.reload() }
        startTimer()
        tick()
        if !settingsStore.settings.hasCompletedOnboarding {
            DispatchQueue.main.async { [weak self] in
                self?.showOnboarding()
            }
        }
    }

    func stopAndRestoreAll() {
        timer?.invalidate()
        timer = nil
        restoreAll(reason: "app_quit")
        workspace.stop()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func tick() {
        let ids = Set(ruleStore.rules.map(\.bundleID))
        let running = workspace.snapshots(for: ids)
        let commands = engine.evaluate(
            frontmostBundleID: workspace.frontmostBundleID(),
            running: running
        )
        apply(commands)
        menuBar?.reload()
    }

    private func apply(_ commands: [PolicyCommand]) {
        for command in commands {
            switch command {
            case .setState(let id, let state):
                let previous = sessionStore.state(for: id)
                sessionStore.set(id, state)
                // Engine can mark hide-rules as optimized when already hidden (no optimize cmd).
                if previous != .optimized, state == .optimized,
                   let rule = ruleStore.rule(for: id), rule.action == .hide {
                    actionLog.append(LogEntry(
                        bundleID: id,
                        displayName: rule.displayName,
                        event: "optimized",
                        action: rule.action.rawValue,
                        reason: "already_hidden"
                    ))
                }
            case .optimize(let id, let action, let reason):
                guard let app = workspace.runningApp(bundleID: id) else { continue }
                if let err = RestoreCoordinator.optimize(app: app, action: action) {
                    actionLog.append(LogEntry(
                        bundleID: id,
                        displayName: ruleStore.rule(for: id)?.displayName ?? id,
                        event: "error",
                        action: action.rawValue,
                        reason: err
                    ))
                    sessionStore.set(id, .watched)
                } else {
                    sessionStore.set(id, .optimized)
                    actionLog.append(LogEntry(
                        bundleID: id,
                        displayName: ruleStore.rule(for: id)?.displayName ?? id,
                        event: "optimized",
                        action: action.rawValue,
                        reason: reason
                    ))
                }
            case .restore(let id, let action, let reason):
                guard let app = workspace.runningApp(bundleID: id) else {
                    sessionStore.set(id, .watched)
                    continue
                }
                RestoreCoordinator.restore(app: app, action: action)
                sessionStore.set(id, .watched)
                actionLog.append(LogEntry(
                    bundleID: id,
                    displayName: ruleStore.rule(for: id)?.displayName ?? id,
                    event: "restored",
                    action: action.rawValue,
                    reason: reason
                ))
            }
        }
    }

    func restoreAll(reason: String) {
        for id in sessionStore.optimizedBundleIDs() {
            guard let rule = ruleStore.rule(for: id),
                  let app = workspace.runningApp(bundleID: id) else {
                sessionStore.set(id, .watched)
                continue
            }
            RestoreCoordinator.restore(app: app, action: rule.action)
            sessionStore.set(id, .watched)
            actionLog.append(LogEntry(
                bundleID: id,
                displayName: rule.displayName,
                event: "restored",
                action: rule.action.rawValue,
                reason: reason
            ))
        }
    }


    func showPreferences() {
        if preferences == nil {
            preferences = PreferencesWindowController(controller: self)
        }
        preferences?.show()
    }

    func showOnboarding() {
        let vc = OnboardingViewController(controller: self)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "欢迎使用 RenderPause Pro"
        window.contentViewController = vc
        window.center()
        window.isReleasedWhenClosed = false
        onboardingWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }

    func addRuleFromRunningApp(_ app: NSRunningApplication) -> Bool {
        guard let id = app.bundleIdentifier else { return false }
        guard id != BundleIdentity.bundleID else { return false }
        let name = app.localizedName ?? id
        return ruleStore.upsert(AppRule.makeNew(bundleID: id, displayName: name))
    }
}
