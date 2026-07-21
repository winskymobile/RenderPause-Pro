import AppKit
import Combine
import Foundation
import SwiftUI

/// Thin UI-facing model so SwiftUI views refresh when stores change.
@MainActor
final class UIAppModel: ObservableObject {
    let controller: AppController

    @Published private(set) var rules: [AppRule] = []
    @Published private(set) var settings: AppSettings = .default
    @Published private(set) var logEntries: [LogEntry] = []
    @Published private(set) var accessibilityTrusted: Bool = false
    @Published private(set) var todayOptimizeCount: Int = 0
    /// Per-rule session state for prefs list (mirrors menu bar).
    @Published private(set) var ruleStatuses: [String: WatchState] = [:]
    @Published var selectedRuleIDs: Set<String> = []

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(controller: AppController) {
        self.controller = controller
        bind()
        refresh()
        // Lightweight poll for AX status + session-driven menu parity while prefs open.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshLight() }
        }
        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private func bind() {
        controller.ruleStore.onChange = { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        controller.settingsStore.onChange = { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        controller.actionLog.onChange = { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        // Forward update service changes into this ObservableObject.
        controller.updateService.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.objectWillChange.send() }
        }.store(in: &cancellables)
    }

    func refresh() {
        rules = controller.ruleStore.rules
        settings = controller.settingsStore.settings
        logEntries = Array(controller.actionLog.entries.prefix(80))
        todayOptimizeCount = controller.actionLog.todayOptimizeCount()
        accessibilityTrusted = PermissionGate.isAccessibilityTrusted()
        refreshRuleStatuses()
    }

    func refreshLight() {
        accessibilityTrusted = PermissionGate.isAccessibilityTrusted()
        todayOptimizeCount = controller.actionLog.todayOptimizeCount()
        refreshRuleStatuses()
    }

    private func refreshRuleStatuses() {
        var map: [String: WatchState] = [:]
        for rule in controller.ruleStore.rules {
            map[rule.bundleID] = controller.sessionStore.state(for: rule.bundleID)
        }
        ruleStatuses = map
    }

    /// Same copy as menu bar app rows: 已隐藏 / 监控中 / 未运行 / 已关闭.
    func statusText(for rule: AppRule) -> String {
        let session = ruleStatuses[rule.bundleID] ?? .watched
        let running = controller.workspace.runningApp(bundleID: rule.bundleID) != nil
        return MenuBarMenuItemFactory.statusText(
            enabled: rule.enabled,
            session: session,
            isRunning: running
        )
    }

    // MARK: - Actions

    func setMonitoring(_ enabled: Bool) {
        controller.settingsStore.update { $0.monitoringEnabled = enabled }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            controller.settingsStore.update { $0.launchAtLogin = enabled }
        } catch {
            // Re-sync UI to actual state
            refresh()
            let alert = NSAlert()
            alert.messageText = "无法更新登录项"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    // MARK: - Updates

    var updatePhase: UpdateService.Phase { controller.updateService.phase }
    var updateStatusText: String { controller.updateService.statusText }
    var updateButtonTitle: String { controller.updateService.buttonTitle }
    var updateButtonEnabled: Bool { controller.updateService.isButtonEnabled }

    func performUpdatePrimaryAction() {
        controller.updateService.primaryAction()
    }

    func setBackgroundSeconds(_ value: TimeInterval) {
        controller.settingsStore.update { $0.backgroundSeconds = value }
    }

    func setOptimizeAction(_ action: OptimizeAction) {
        controller.settingsStore.update { $0.optimizeAction = action }
    }

    func openAccessibilitySettings() {
        PermissionGate.openAccessibilitySettings()
        refreshLight()
    }

    /// Prompt for Accessibility trust (or open settings if prompt unavailable).
    func requestAccessibilityAuthorization() {
        _ = PermissionGate.isAccessibilityTrusted(prompt: true)
        PermissionGate.openAccessibilitySettings()
        refreshLight()
    }

    func addRunningApps() {
        let picker = RunningAppPickerViewController(controller: controller) { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        let host = preferredHostWindow()
        if let host {
            host.contentViewController?.presentAsSheet(picker)
        } else {
            let win = NSWindow(contentViewController: picker)
            win.title = "添加运行中的应用"
            win.styleMask = [.titled, .closable]
            win.setContentSize(NSSize(width: 440, height: 400))
            win.center()
            NSApp.runModal(for: win)
            win.close()
            refresh()
        }
    }

    private func preferredHostWindow() -> NSWindow? {
        if let key = NSApp.keyWindow, key.contentViewController != nil { return key }
        return NSApp.windows.first {
            $0.title.contains("偏好设置") || $0.title.contains("欢迎")
        }
    }

    func removeSelectedRules() {
        for id in selectedRuleIDs {
            controller.ruleStore.remove(bundleID: id)
        }
        selectedRuleIDs.removeAll()
        refresh()
    }

    func removeRule(bundleID: String) {
        controller.ruleStore.remove(bundleID: bundleID)
        selectedRuleIDs.remove(bundleID)
        refresh()
    }

    func setRuleEnabled(bundleID: String, enabled: Bool) {
        controller.ruleStore.setEnabled(bundleID: bundleID, enabled: enabled)
    }

    func setRuleAction(bundleID: String, action: OptimizeAction) {
        guard var rule = controller.ruleStore.rule(for: bundleID) else { return }
        rule.action = action
        _ = controller.ruleStore.upsert(rule)
    }

    func restoreAll() {
        controller.restoreAll(reason: "manual")
        refresh()
    }

    func finishOnboarding() {
        controller.settingsStore.update { $0.hasCompletedOnboarding = true }
        if controller.settingsStore.settings.launchAtLogin {
            try? LaunchAtLogin.setEnabled(true)
        }
        controller.closeOnboarding()
    }

    func icon(for bundleID: String) -> NSImage {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }
}
