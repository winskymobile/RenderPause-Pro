import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppController.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppController.shared.stopAndRestoreAll()
    }
}
