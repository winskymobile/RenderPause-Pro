import AppKit
import SwiftUI

/// Hosts PreferencesView. Chrome matches HTML `.tb` (48pt full-width bar under transparent system titlebar).
@MainActor
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private let model: UIAppModel
    private var didUpdateObserver: NSObjectProtocol?
    private var lastAlignTime: CFAbsoluteTime = 0

    /// Must match `PrefsChrome.titleBarHeight` / HTML `.tb`.
    private let titleBarHeight: CGFloat = 48
    /// HTML `.tb` horizontal padding + `.dots` gap (12pt dots, ~8 gap).
    private let trafficLightLeading: CGFloat = 14
    private let trafficLightGap: CGFloat = 8

    init(controller: AppController) {
        self.model = UIAppModel(controller: controller)
        let hosting = NSHostingController(rootView: PreferencesView(model: model))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "RenderPause Pro"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.contentViewController = hosting
        window.setContentSize(NSSize(width: 820, height: 560))
        window.minSize = NSSize(width: 740, height: 500)
        window.center()
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(name: nil) { appearance in
            // HTML --bg-window
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 28 / 255, green: 28 / 255, blue: 30 / 255, alpha: 1) // #1c1c1e
                : NSColor(srgbRed: 232 / 255, green: 232 / 255, blue: 237 / 255, alpha: 1) // #e8e8ed
        }
        super.init(window: window)
        window.delegate = self

        // AppKit repositions standard buttons every display pass; re-assert HTML layout.
        didUpdateObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.alignTrafficLightsThrottled()
        }
    }

    deinit {
        if let didUpdateObserver {
            NotificationCenter.default.removeObserver(didUpdateObserver)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        model.refresh()
        // Clear any titlebar accessories so SwiftUI owns the full 48pt bar (HTML `.tb`).
        if let window {
            while !window.titlebarAccessoryViewControllers.isEmpty {
                window.removeTitlebarAccessoryViewController(at: 0)
            }
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        scheduleTrafficLightAlignments()
    }

    /// Hide preferences (⌘W / red traffic light). Agent keeps running.
    func hideWindow() {
        window?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Prefer orderOut so the controller can re-show without rebuild.
        hideWindow()
        return false
    }

    func windowDidResize(_ notification: Notification) {
        alignTrafficLights()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        alignTrafficLights()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        alignTrafficLights()
    }

    // MARK: - Traffic lights

    private func scheduleTrafficLightAlignments() {
        alignTrafficLights()
        DispatchQueue.main.async { [weak self] in self?.alignTrafficLights() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.alignTrafficLights()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.alignTrafficLights()
        }
    }

    private func alignTrafficLightsThrottled() {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastAlignTime >= 0.032 else { return }
        lastAlignTime = now
        alignTrafficLights()
    }

    /// Vertically center traffic lights in the **visual** 48pt HTML title bar.
    ///
    /// System titlebar container is often only ~28–30pt. SwiftUI draws a full 48pt `.tb`.
    /// Buttons may sit slightly below the container (negative Y) so they align with the
    /// taller painted bar — same optical center as the HTML mock.
    private func alignTrafficLights() {
        guard let window,
              let closeButton = window.standardWindowButton(.closeButton),
              let miniaturizeButton = window.standardWindowButton(.miniaturizeButton),
              let zoomButton = window.standardWindowButton(.zoomButton),
              let container = closeButton.superview
        else { return }

        let buttons = [closeButton, miniaturizeButton, zoomButton]
        for button in buttons {
            button.translatesAutoresizingMaskIntoConstraints = true
            button.autoresizingMask = []
        }

        let buttonHeight = closeButton.bounds.height
        guard buttonHeight > 0 else { return }

        // Distance from **window top** to button top (HTML: (48 − 12)/2 ≈ 18 for 12pt dots;
        // real buttons are ~14–16pt → (48 − h) / 2).
        let fromWindowTop = ((titleBarHeight - buttonHeight) / 2).rounded(.toNearestOrAwayFromZero)

        // Container is pinned to the top of the window; origin is bottom-left of container.
        // y = containerHeight − fromWindowTop − buttonHeight  (may be slightly negative).
        let containerHeight = container.bounds.height
        let y = (containerHeight - fromWindowTop - buttonHeight).rounded(.toNearestOrAwayFromZero)

        var x = trafficLightLeading
        for button in buttons {
            let origin = NSPoint(x: x.rounded(.toNearestOrAwayFromZero), y: y)
            if abs(button.frame.origin.x - origin.x) > 0.25
                || abs(button.frame.origin.y - origin.y) > 0.25 {
                button.setFrameOrigin(origin)
            }
            x += button.bounds.width + trafficLightGap
        }
    }
}
