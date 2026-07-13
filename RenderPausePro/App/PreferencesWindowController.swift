import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSWindowController {
    private let model: UIAppModel

    init(controller: AppController) {
        self.model = UIAppModel(controller: controller)
        let hosting = NSHostingController(rootView: PreferencesView(model: model))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "RenderPause Pro 偏好设置"
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 520, height: 640))
        window.minSize = NSSize(width: 480, height: 560)
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        model.refresh()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
