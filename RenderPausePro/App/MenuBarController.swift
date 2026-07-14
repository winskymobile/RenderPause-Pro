import AppKit

/// Status-item menu — pixel-aligned to `docs/ui-mockups/menubar-menu-v1.html` (v1.4).
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private weak var controller: AppController?
    private var menu = NSMenu()

    init(controller: AppController) {
        self.controller = controller
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.image = Self.statusItemImage()
            button.toolTip = "RenderPause Pro"
        }
        menu.delegate = self
        menu.autoenablesItems = false
        // Minimum width matches HTML --menu-w
        menu.minimumWidth = MenuBarChrome.menuWidth
        statusItem.menu = menu
        reload()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(into: menu)
    }

    func reload() {
        rebuild(into: menu)
    }

    private func rebuild(into menu: NSMenu) {
        guard let controller else { return }
        menu.removeAllItems()

        let monitoring = controller.settingsStore.settings.monitoringEnabled
        let count = controller.actionLog.todayOptimizeCount()
        let secs = Int(controller.settingsStore.settings.backgroundSeconds)

        // ── A. Header: desktop icon + status ──
        let header = MenuBarHeaderView()
        header.configure(
            title: monitoring ? "监控中" : "已暂停监控",
            subtitle: monitoring
                ? "后台 \(secs) 秒 · 今日 \(count) 次"
                : "今日 \(count) 次 · 恢复后继续优化",
            icon: MenuBarMenuItemFactory.symbol("desktopcomputer", pointSize: 14)
        )
        menu.addItem(MenuBarMenuItemFactory.wrap(header))
        menu.addItem(.separator())

        // ── B. Pause / resume only ──
        let toggleRow = MenuBarActionRowView()
        toggleRow.configure(
            title: monitoring ? "暂停监控" : "恢复监控",
            icon: MenuBarMenuItemFactory.symbol(monitoring ? "pause.fill" : "play.fill", pointSize: 13),
            keyEquivalent: ""
        )
        toggleRow.onActivate = { [weak self] in
            self?.toggleMonitoring()
        }
        menu.addItem(MenuBarMenuItemFactory.wrap(toggleRow, height: MenuBarChrome.rowHeight))
        menu.addItem(.separator())

        // ── C. Section + apps ──
        let section = MenuBarSectionLabelView()
        section.configure(title: "应用名单")
        menu.addItem(MenuBarMenuItemFactory.wrap(section))

        if controller.ruleStore.rules.isEmpty {
            let empty = MenuBarPlainDisabledView()
            empty.configure(title: "名单为空 — 打开窗口后添加应用")
            menu.addItem(MenuBarMenuItemFactory.wrap(empty))
        } else {
            let checkOn = MenuBarMenuItemFactory.bareCheckImage()
            let checkOff = MenuBarMenuItemFactory.emptyCheckImage()
            for rule in controller.ruleStore.rules.prefix(8) {
                let session = controller.sessionStore.state(for: rule.bundleID)
                let row = MenuBarAppRowView()
                let bundleID = rule.bundleID
                row.configure(
                    title: rule.displayName,
                    appIcon: MenuBarMenuItemFactory.appIcon(bundleID: bundleID),
                    enabled: rule.enabled,
                    status: MenuBarMenuItemFactory.statusText(enabled: rule.enabled, session: session),
                    checkOn: checkOn,
                    checkOff: checkOff
                )
                row.onActivate = { [weak self] in
                    self?.toggleRule(bundleID: bundleID)
                }
                menu.addItem(MenuBarMenuItemFactory.wrap(row, height: MenuBarChrome.rowHeight))
            }
        }

        menu.addItem(.separator())

        // ── D. Footer ──
        let openRow = MenuBarActionRowView()
        openRow.configure(
            title: "打开 RenderPause Pro",
            icon: MenuBarMenuItemFactory.symbol("macwindow", pointSize: 13),
            keyEquivalent: "⌘,"
        )
        openRow.onActivate = { [weak self] in
            self?.openPrefs()
        }
        menu.addItem(MenuBarMenuItemFactory.wrap(openRow, height: MenuBarChrome.rowHeight))

        if FeatureFlags.allowMinimizeMode {
            let ax = PermissionGate.isAccessibilityTrusted()
            let needsAX = controller.settingsStore.settings.optimizeAction == .minimize
            if needsAX && !ax {
                let axRow = MenuBarActionRowView()
                axRow.configure(
                    title: "授权辅助功能…",
                    icon: MenuBarMenuItemFactory.symbol("hand.raised", pointSize: 13),
                    keyEquivalent: ""
                )
                axRow.onActivate = { [weak self] in
                    self?.openAX()
                }
                menu.addItem(MenuBarMenuItemFactory.wrap(axRow, height: MenuBarChrome.rowHeight))
            }
        }

        let quitRow = MenuBarActionRowView()
        quitRow.configure(
            title: "退出",
            icon: MenuBarMenuItemFactory.symbol("power", pointSize: 13),
            keyEquivalent: "⌘Q"
        )
        quitRow.onActivate = {
            NSApp.terminate(nil)
        }
        menu.addItem(MenuBarMenuItemFactory.wrap(quitRow, height: MenuBarChrome.rowHeight))

        // Hidden standard items so ⌘, / ⌘Q still work (custom views don't receive keyEquiv).
        let openKey = NSMenuItem(title: "", action: #selector(openPrefsFromKey), keyEquivalent: ",")
        openKey.target = self
        openKey.isHidden = true
        menu.addItem(openKey)

        let quitKey = NSMenuItem(title: "", action: #selector(quitFromKey), keyEquivalent: "q")
        quitKey.target = self
        quitKey.isHidden = true
        menu.addItem(quitKey)
    }

    @objc private func openPrefsFromKey() {
        openPrefs()
    }

    @objc private func quitFromKey() {
        NSApp.terminate(nil)
    }

    // MARK: - Actions

    private func toggleMonitoring() {
        controller?.settingsStore.update { $0.monitoringEnabled.toggle() }
        // menu rebuilds on next open; force refresh if still open
        reload()
    }

    private func toggleRule(bundleID: String) {
        guard let rule = controller?.ruleStore.rule(for: bundleID) else { return }
        controller?.ruleStore.setEnabled(bundleID: bundleID, enabled: !rule.enabled)
        reload()
    }

    private func openPrefs() {
        controller?.showPreferences()
    }

    private func openAX() {
        _ = PermissionGate.isAccessibilityTrusted(prompt: true)
        PermissionGate.openAccessibilitySettings()
    }

    /// Menu bar template icon from `MenuBarIcon`.
    private static func statusItemImage() -> NSImage {
        let pointSize = NSSize(width: 18, height: 18)
        let candidates: [NSImage?] = [
            Bundle.main.image(forResource: "MenuBarIcon"),
            NSImage(named: "MenuBarIcon"),
            {
                guard let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "tiff")
                        ?? Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png")
                else { return nil }
                return NSImage(contentsOf: url)
            }()
        ]
        if let source = candidates.compactMap({ $0 }).first {
            let image = NSImage(size: pointSize)
            image.addRepresentations(source.representations)
            image.size = pointSize
            image.isTemplate = true
            return image
        }
        let symbol = NSImage(
            systemSymbolName: "pause.rectangle",
            accessibilityDescription: "RenderPause Pro"
        ) ?? NSImage()
        symbol.isTemplate = true
        return symbol
    }
}
