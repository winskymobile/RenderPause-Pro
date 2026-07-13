import AppKit

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private weak var controller: AppController?

    init(controller: AppController) {
        self.controller = controller
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "pause.rectangle",
                accessibilityDescription: "RenderPause Pro"
            )
            button.image?.isTemplate = true
        }
        reload()
    }

    func reload() {
        guard let controller else { return }
        let menu = NSMenu()

        let monitoring = controller.settingsStore.settings.monitoringEnabled
        let count = controller.actionLog.todayOptimizeCount()
        let secs = Int(controller.settingsStore.settings.backgroundSeconds)
        let header = NSMenuItem(
            title: monitoring ? "监控中 · 后台 \(secs)s · 今日 \(count) 次" : "已暂停监控",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let toggle = NSMenuItem(
            title: monitoring ? "暂停监控" : "恢复监控",
            action: #selector(toggleMonitoring),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        let restore = NSMenuItem(title: "立即恢复全部", action: #selector(restoreAll), keyEquivalent: "r")
        restore.target = self
        menu.addItem(restore)
        menu.addItem(.separator())

        if controller.ruleStore.rules.isEmpty {
            let empty = NSMenuItem(title: "名单为空 — 请在偏好设置添加应用", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for rule in controller.ruleStore.rules.prefix(12) {
                let state = controller.sessionStore.state(for: rule.bundleID)
                let mark: String
                switch state {
                case .optimized: mark = "●"
                case .paused: mark = "○"
                case .watched: mark = "·"
                }
                let item = NSMenuItem(
                    title: "\(mark) \(rule.displayName)\(rule.enabled ? "" : "（关）")",
                    action: #selector(toggleRule(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = rule.bundleID
                item.state = rule.enabled ? .on : .off
                item.target = self
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let prefs = NSMenuItem(title: "偏好设置…", action: #selector(openPrefs), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let ax = PermissionGate.isAccessibilityTrusted()
        let axItem = NSMenuItem(
            title: ax ? "辅助功能：已授权" : "辅助功能：未授权（最小化需要）…",
            action: ax ? nil : #selector(openAX),
            keyEquivalent: ""
        )
        axItem.target = self
        if ax { axItem.isEnabled = false }
        menu.addItem(axItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "退出 RenderPause Pro",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu
    }

    @objc private func toggleMonitoring() {
        controller?.settingsStore.update { $0.monitoringEnabled.toggle() }
        reload()
    }

    @objc private func restoreAll() {
        controller?.restoreAll(reason: "manual")
        reload()
    }

    @objc private func toggleRule(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let rule = controller?.ruleStore.rule(for: id) else { return }
        controller?.ruleStore.setEnabled(bundleID: id, enabled: !rule.enabled)
        reload()
    }

    @objc private func openPrefs() {
        controller?.showPreferences()
    }

    @objc private func openAX() {
        _ = PermissionGate.isAccessibilityTrusted(prompt: true)
        PermissionGate.openAccessibilitySettings()
    }
}
