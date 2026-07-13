import AppKit

final class OnboardingViewController: NSViewController {
    private weak var controller: AppController?

    init(controller: AppController) {
        self.controller = controller
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 360))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let title = NSTextField(labelWithString: "RenderPause Pro")
        title.font = NSFont.systemFont(ofSize: 22, weight: .semibold)

        let body = NSTextField(wrappingLabelWithString: """
        把「非活跃窗口的自动隐藏/最小化」做成无感后台服务，降低 WindowServer 合成开销，减少发热与耗电。

        1. 默认不会优化任何应用，请先把需要的应用加入名单。
        2. 默认策略是「隐藏」；「最小化」需要辅助功能权限。
        3. 切回应用时会立即恢复。
        """)
        body.font = NSFont.systemFont(ofSize: 13)

        let axButton = NSButton(title: "授权辅助功能（可选，最小化需要）", target: self, action: #selector(openAX))
        let addButton = NSButton(title: "添加第一个应用…", target: self, action: #selector(addApp))
        let doneButton = NSButton(title: "开始使用", target: self, action: #selector(finish))
        doneButton.keyEquivalent = "\r"

        let stack = NSStackView(views: [title, body, axButton, addButton, doneButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            body.widthAnchor.constraint(lessThanOrEqualToConstant: 420)
        ])
    }

    @objc private func openAX() {
        _ = PermissionGate.isAccessibilityTrusted(prompt: true)
        PermissionGate.openAccessibilitySettings()
    }

    @objc private func addApp() {
        guard let controller else { return }
        let picker = RunningAppPickerViewController(controller: controller) { [weak self] in
            guard let self else { return }
            if let sheet = self.presentedViewControllers?.first {
                self.dismiss(sheet)
            }
        }
        presentAsSheet(picker)
    }

    @objc private func finish() {
        controller?.settingsStore.update { $0.hasCompletedOnboarding = true }
        if controller?.settingsStore.settings.launchAtLogin == true {
            try? LaunchAtLogin.setEnabled(true)
        }
        controller?.closeOnboarding()
    }
}
