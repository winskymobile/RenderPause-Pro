import AppKit

@MainActor
final class RunningAppPickerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private weak var controller: AppController?
    private let onDone: () -> Void
    private var apps: [NSRunningApplication] = []
    private let table = NSTableView()

    init(controller: AppController, onDone: @escaping () -> Void) {
        self.controller = controller
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        refreshApps()

        let title = NSTextField(labelWithString: "选择要添加的应用")
        title.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = NSTextField(labelWithString: "仅显示当前运行中的普通应用。")
        subtitle.font = NSFont.systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let iconCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("icon"))
        iconCol.title = ""
        iconCol.width = 28
        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "应用"
        nameCol.width = 360
        table.addTableColumn(iconCol)
        table.addTableColumn(nameCol)
        table.headerView = nil
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 36
        table.doubleAction = #selector(addSelected)
        table.target = self
        table.allowsMultipleSelection = false

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let addButton = NSButton(title: "添加", target: self, action: #selector(addSelected))
        addButton.keyEquivalent = "\r"
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancel))
        cancelButton.keyEquivalent = "\u{1b}"
        let buttons = NSStackView(views: [cancelButton, addButton])
        buttons.orientation = .horizontal
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(title)
        view.addSubview(subtitle)
        view.addSubview(scroll)
        view.addSubview(buttons)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            scroll.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 14),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scroll.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -14),
            buttons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttons.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
    }

    private func refreshApps() {
        guard let controller else { return }
        let existing = Set(controller.ruleStore.rules.map(\.bundleID))
        apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != nil }
            .filter { $0.bundleIdentifier != BundleIdentity.bundleID }
            .filter { !existing.contains($0.bundleIdentifier!) }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        table.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { apps.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = apps[row]
        let id = tableColumn?.identifier.rawValue
        if id == "icon" {
            let imageView = NSImageView()
            if let path = app.bundleURL?.path {
                imageView.image = NSWorkspace.shared.icon(forFile: path)
            }
            imageView.imageScaling = .scaleProportionallyUpOrDown
            return imageView
        }
        let name = app.localizedName ?? app.bundleIdentifier ?? "?"
        let field = NSTextField(labelWithString: name)
        field.font = NSFont.systemFont(ofSize: 13)
        field.lineBreakMode = .byTruncatingTail
        return field
    }

    @objc private func addSelected() {
        guard let controller else { return }
        let row = table.selectedRow
        guard row >= 0, row < apps.count else { return }
        _ = controller.addRuleFromRunningApp(apps[row])
        dismissSelf()
        onDone()
    }

    @objc private func cancel() {
        dismissSelf()
        onDone()
    }

    private func dismissSelf() {
        if let sheet = view.window, let parent = sheet.sheetParent {
            parent.endSheet(sheet)
        } else if let window = view.window, NSApp.modalWindow == window {
            NSApp.stopModal()
        } else {
            presentingViewController?.dismiss(self)
        }
    }
}
