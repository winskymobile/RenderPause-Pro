import AppKit

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
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 360))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        refreshApps()

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        col.title = "运行中的应用"
        col.width = 380
        table.addTableColumn(col)
        table.dataSource = self
        table.delegate = self
        table.doubleAction = #selector(addSelected)
        table.target = self

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let addButton = NSButton(title: "添加", target: self, action: #selector(addSelected))
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancel))
        let buttons = NSStackView(views: [cancelButton, addButton])
        buttons.orientation = .horizontal
        buttons.spacing = 8
        buttons.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scroll)
        view.addSubview(buttons)

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scroll.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -12),
            buttons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
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
        let name = app.localizedName ?? app.bundleIdentifier ?? "?"
        let field = NSTextField(labelWithString: "\(name)  (\(app.bundleIdentifier ?? ""))")
        field.lineBreakMode = .byTruncatingMiddle
        return field
    }

    @objc private func addSelected() {
        guard let controller else { return }
        let row = table.selectedRow
        guard row >= 0, row < apps.count else { return }
        _ = controller.addRuleFromRunningApp(apps[row])
        onDone()
    }

    @objc private func cancel() {
        onDone()
    }
}
