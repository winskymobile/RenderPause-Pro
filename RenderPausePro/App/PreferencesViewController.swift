import AppKit

final class PreferencesViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private weak var controller: AppController?

    private let monitoringCheckbox = NSButton(checkboxWithTitle: "启用监控", target: nil, action: nil)
    private let launchCheckbox = NSButton(checkboxWithTitle: "登录时启动", target: nil, action: nil)
    private let axStatusLabel = NSTextField(labelWithString: "")
    private let axButton = NSButton(title: "打开辅助功能设置", target: nil, action: nil)

    private let rulesTable = NSTableView()
    private let logTable = NSTableView()
    private var rulesScroll: NSScrollView!
    private var logScroll: NSScrollView!

    init(controller: AppController) {
        self.controller = controller
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 760, height: 540))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        reload()
    }

    func reload() {
        guard let controller else { return }
        monitoringCheckbox.state = controller.settingsStore.settings.monitoringEnabled ? .on : .off
        launchCheckbox.state = controller.settingsStore.settings.launchAtLogin ? .on : .off
        let trusted = PermissionGate.isAccessibilityTrusted()
        axStatusLabel.stringValue = trusted ? "辅助功能：已授权" : "辅助功能：未授权（最小化策略需要）"
        rulesTable.reloadData()
        logTable.reloadData()
    }

    private func buildUI() {
        monitoringCheckbox.target = self
        monitoringCheckbox.action = #selector(toggleMonitoring)
        launchCheckbox.target = self
        launchCheckbox.action = #selector(toggleLaunch)
        axButton.target = self
        axButton.action = #selector(openAX)

        let topStack = NSStackView(views: [monitoringCheckbox, launchCheckbox, axStatusLabel, axButton])
        topStack.orientation = .horizontal
        topStack.spacing = 16
        topStack.alignment = .centerY
        topStack.translatesAutoresizingMaskIntoConstraints = false

        rulesScroll = makeTableScroll(
            table: rulesTable,
            columns: [
                ("enabled", "启用", 50),
                ("name", "名称", 140),
                ("bundle", "Bundle ID", 180),
                ("action", "策略", 80),
                ("idle", "空闲秒", 70),
                ("locked", "锁定", 50)
            ]
        )
        rulesTable.dataSource = self
        rulesTable.delegate = self
        rulesTable.allowsMultipleSelection = false
        rulesTable.target = self
        rulesTable.doubleAction = #selector(cycleAction)

        let addButton = NSButton(title: "添加运行中应用…", target: self, action: #selector(addRunning))
        let removeButton = NSButton(title: "移除", target: self, action: #selector(removeSelected))
        let exempt10 = NSButton(title: "豁免 10 分钟", target: self, action: #selector(exempt10))
        let exempt60 = NSButton(title: "豁免 1 小时", target: self, action: #selector(exempt60))
        let exemptLong = NSButton(title: "豁免直到重启", target: self, action: #selector(exemptLong))
        let toggleAction = NSButton(title: "切换策略", target: self, action: #selector(cycleAction))
        let toggleLock = NSButton(title: "切换锁定", target: self, action: #selector(toggleLock))

        let buttonStack = NSStackView(views: [addButton, removeButton, toggleAction, toggleLock, exempt10, exempt60, exemptLong])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let rulesLabel = NSTextField(labelWithString: "优化名单")
        rulesLabel.font = NSFont.boldSystemFont(ofSize: 13)

        logScroll = makeTableScroll(
            table: logTable,
            columns: [
                ("time", "时间", 140),
                ("app", "应用", 120),
                ("event", "事件", 80),
                ("action", "动作", 70),
                ("reason", "原因", 180)
            ]
        )
        logTable.dataSource = self
        logTable.delegate = self

        let logLabel = NSTextField(labelWithString: "最近操作日志")
        logLabel.font = NSFont.boldSystemFont(ofSize: 13)

        let root = NSStackView(views: [topStack, rulesLabel, rulesScroll, buttonStack, logLabel, logScroll])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.translatesAutoresizingMaskIntoConstraints = false
        root.setHuggingPriority(.defaultLow, for: .horizontal)
        view.addSubview(root)

        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            rulesScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 180),
            logScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 140),
            rulesScroll.widthAnchor.constraint(equalTo: root.widthAnchor),
            logScroll.widthAnchor.constraint(equalTo: root.widthAnchor),
            buttonStack.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])
    }

    private func makeTableScroll(table: NSTableView, columns: [(String, String, CGFloat)]) -> NSScrollView {
        table.headerView = NSTableHeaderView()
        table.usesAlternatingRowBackgroundColors = true
        table.rowHeight = 24
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        for (id, title, width) in columns {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            col.title = title
            col.width = width
            table.addTableColumn(col)
        }
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }

    // MARK: - Actions

    @objc private func toggleMonitoring() {
        controller?.settingsStore.update { $0.monitoringEnabled = monitoringCheckbox.state == .on }
    }

    @objc private func toggleLaunch() {
        let enabled = launchCheckbox.state == .on
        do {
            try LaunchAtLogin.setEnabled(enabled)
            controller?.settingsStore.update { $0.launchAtLogin = enabled }
        } catch {
            launchCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
            let alert = NSAlert()
            alert.messageText = "无法更新登录项"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func openAX() {
        _ = PermissionGate.isAccessibilityTrusted(prompt: true)
        PermissionGate.openAccessibilitySettings()
        reload()
    }

    @objc private func addRunning() {
        guard let controller else { return }
        let picker = RunningAppPickerViewController(controller: controller) { [weak self] in
            self?.reload()
            self?.dismissPicker()
        }
        presentAsSheet(picker)
    }

    private func dismissPicker() {
        if let sheet = presentedViewControllers?.first {
            dismiss(sheet)
        }
    }

    @objc private func removeSelected() {
        guard let controller else { return }
        let row = rulesTable.selectedRow
        guard row >= 0, row < controller.ruleStore.rules.count else { return }
        let id = controller.ruleStore.rules[row].bundleID
        controller.ruleStore.remove(bundleID: id)
        reload()
    }

    @objc private func cycleAction() {
        guard let controller else { return }
        let row = rulesTable.selectedRow
        guard row >= 0, row < controller.ruleStore.rules.count else { return }
        var rule = controller.ruleStore.rules[row]
        rule.action = rule.action == .hide ? .minimize : .hide
        _ = controller.ruleStore.upsert(rule)
        reload()
    }

    @objc private func toggleLock() {
        guard let controller else { return }
        let row = rulesTable.selectedRow
        guard row >= 0, row < controller.ruleStore.rules.count else { return }
        var rule = controller.ruleStore.rules[row]
        rule.locked.toggle()
        _ = controller.ruleStore.upsert(rule)
        reload()
    }

    @objc private func exempt10() { exempt(duration: 600) }
    @objc private func exempt60() { exempt(duration: 3600) }
    @objc private func exemptLong() { exempt(duration: 60 * 60 * 24 * 30) }

    private func exempt(duration: TimeInterval) {
        guard let controller else { return }
        let row = rulesTable.selectedRow
        guard row >= 0, row < controller.ruleStore.rules.count else { return }
        controller.exempt(bundleID: controller.ruleStore.rules[row].bundleID, duration: duration)
        reload()
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int {
        guard let controller else { return 0 }
        if tableView === rulesTable { return controller.ruleStore.rules.count }
        if tableView === logTable { return min(controller.actionLog.entries.count, 50) }
        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let controller, let tableColumn else { return nil }
        let id = tableColumn.identifier.rawValue
        let field = NSTextField(labelWithString: "")
        field.lineBreakMode = .byTruncatingTail

        if tableView === rulesTable {
            let rule = controller.ruleStore.rules[row]
            switch id {
            case "enabled": field.stringValue = rule.enabled ? "✓" : "—"
            case "name": field.stringValue = rule.displayName
            case "bundle": field.stringValue = rule.bundleID
            case "action": field.stringValue = rule.action.titleZH
            case "idle": field.stringValue = "\(Int(rule.idleSeconds))"
            case "locked": field.stringValue = rule.locked ? "✓" : "—"
            default: break
            }
            return field
        }

        if tableView === logTable {
            let entry = controller.actionLog.entries[row]
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm:ss"
            switch id {
            case "time": field.stringValue = formatter.string(from: entry.date)
            case "app": field.stringValue = entry.displayName
            case "event": field.stringValue = entry.event
            case "action": field.stringValue = entry.action ?? "—"
            case "reason": field.stringValue = entry.reason
            default: break
            }
            return field
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
}

// Toggle enable on single click of enabled column via selection + space alternative: double-click name cycles enable
extension PreferencesViewController {
    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            guard let controller else { return }
            let row = rulesTable.selectedRow
            guard row >= 0, row < controller.ruleStore.rules.count else { return }
            let rule = controller.ruleStore.rules[row]
            controller.ruleStore.setEnabled(bundleID: rule.bundleID, enabled: !rule.enabled)
            reload()
            return
        }
        if event.charactersIgnoringModifiers == "+" || event.charactersIgnoringModifiers == "=" {
            guard let controller else { return }
            let row = rulesTable.selectedRow
            guard row >= 0, row < controller.ruleStore.rules.count else { return }
            var rule = controller.ruleStore.rules[row]
            rule.idleSeconds = min(600, rule.idleSeconds + 5)
            _ = controller.ruleStore.upsert(rule)
            reload()
            return
        }
        if event.charactersIgnoringModifiers == "-" {
            guard let controller else { return }
            let row = rulesTable.selectedRow
            guard row >= 0, row < controller.ruleStore.rules.count else { return }
            var rule = controller.ruleStore.rules[row]
            rule.idleSeconds = max(5, rule.idleSeconds - 5)
            _ = controller.ruleStore.upsert(rule)
            reload()
            return
        }
        super.keyDown(with: event)
    }
}
