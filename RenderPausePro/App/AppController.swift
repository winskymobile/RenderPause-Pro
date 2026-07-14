import AppKit
import Foundation
import SwiftUI

@MainActor
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
        // Product currently ships hide-only; keep minimize code but force hide at launch.
        if !FeatureFlags.allowMinimizeMode,
           settingsStore.settings.optimizeAction != .hide {
            settingsStore.update { $0.optimizeAction = .hide }
        }
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
            frontmostBundleID: workspace.regularFrontmostBundleID(),
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
                   settingsStore.settings.optimizeAction == .hide {
                    actionLog.append(LogEntry(
                        bundleID: id,
                        displayName: ruleStore.rule(for: id)?.displayName ?? id,
                        event: "optimized",
                        action: settingsStore.settings.optimizeAction.rawValue,
                        reason: "already_hidden"
                    ))
                }
            case .optimize(let id, let action, let reason):
                guard let app = workspace.runningApp(bundleID: id) else { continue }
                // Hard safety: never hide/minimize frontmost or Split View partner apps.
                if workspace.isProtectedFromOptimize(bundleID: id) {
                    sessionStore.set(id, .watched)
                    continue
                }
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
            let action = settingsStore.settings.optimizeAction
            RestoreCoordinator.restore(app: app, action: action)
            sessionStore.set(id, .watched)
            actionLog.append(LogEntry(
                bundleID: id,
                displayName: rule.displayName,
                event: "restored",
                action: action.rawValue,
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

    /// Close preferences window (⌘W / traffic-light / explicit) without quitting the agent.
    func closePreferences() {
        preferences?.hideWindow()
    }

    /// If the key window is a utility window (偏好设置 / 欢迎), close it and return true.
    /// Used so ⌘Q does not quit the menu-bar agent while a sheet-like window is frontmost.
    @discardableResult
    func closeKeyUtilityWindowIfNeeded() -> Bool {
        guard let key = NSApp.keyWindow else { return false }
        if let prefsWindow = preferences?.window, key === prefsWindow {
            preferences?.hideWindow()
            return true
        }
        if let onboarding = onboardingWindow, key === onboarding {
            closeOnboarding()
            return true
        }
        // Picker / other app-owned windows: close instead of quit.
        if key.isVisible, key !== preferences?.window {
            let title = key.title
            if title.contains("添加") || title.contains("应用") || title.contains("欢迎") {
                key.orderOut(nil)
                return true
            }
        }
        return false
    }

    func showOnboarding() {
        let model = UIAppModel(controller: self)
        let hosting = NSHostingController(rootView: OnboardingView(model: model))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "欢迎使用 RenderPause Pro"
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 440, height: 380))
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
