import AppKit

@MainActor
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
        menu.autoenablesItems = true

        let monitoring = controller.settingsStore.settings.monitoringEnabled
        let count = controller.actionLog.todayOptimizeCount()
        let secs = Int(controller.settingsStore.settings.backgroundSeconds)

        let header = NSMenuItem(
            title: monitoring ? "监控中 · 后台 \(secs) 秒 · 今日 \(count) 次" : "已暂停监控",
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

        let restore = NSMenuItem(
            title: "立即恢复全部",
            action: #selector(restoreAll),
            keyEquivalent: "r"
        )
        restore.target = self
        menu.addItem(restore)

        menu.addItem(.separator())

        if controller.ruleStore.rules.isEmpty {
            let empty = NSMenuItem(
                title: "名单为空",
                action: nil,
                keyEquivalent: ""
            )
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for rule in controller.ruleStore.rules.prefix(8) {
                let state = controller.sessionStore.state(for: rule.bundleID)
                let mark: String
                switch state {
                case .optimized: mark = "●"
                case .paused: mark = "○"
                case .watched: mark = "·"
                }
                let suffix = rule.enabled ? "" : "（关）"
                let item = NSMenuItem(
                    title: "\(mark)  \(rule.displayName)\(suffix)",
                    action: #selector(toggleRule(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = rule.bundleID
                item.state = rule.enabled ? .on : .off
                item.target = self
                menu.addItem(item)
            }
        }

        let manage = NSMenuItem(
            title: "管理应用…",
            action: #selector(openPrefs),
            keyEquivalent: ""
        )
        manage.target = self
        menu.addItem(manage)

        menu.addItem(.separator())

        let prefs = NSMenuItem(
            title: "偏好设置…",
            action: #selector(openPrefs),
            keyEquivalent: ","
        )
        prefs.target = self
        menu.addItem(prefs)

        let ax = PermissionGate.isAccessibilityTrusted()
        if !ax {
            let axItem = NSMenuItem(
                title: "授权辅助功能…",
                action: #selector(openAX),
                keyEquivalent: ""
            )
            axItem.target = self
            menu.addItem(axItem)
            menu.addItem(.separator())
        }

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
