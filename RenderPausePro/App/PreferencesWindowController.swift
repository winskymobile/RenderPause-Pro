import AppKit

final class PreferencesWindowController: NSWindowController {
    private weak var controller: AppController?

    init(controller: AppController) {
        self.controller = controller
        let vc = PreferencesViewController(controller: controller)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "RenderPause Pro 偏好设置"
        window.contentViewController = vc
        window.center()
        window.minSize = NSSize(width: 640, height: 420)
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        (contentViewController as? PreferencesViewController)?.reload()
    }
}
