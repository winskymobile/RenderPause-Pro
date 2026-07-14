import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()
        AppController.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppController.shared.stopAndRestoreAll()
    }

    /// Keep running as a menu-bar agent when the last prefs/onboarding window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// When a utility window (偏好设置 / 欢迎) is key, ⌘Q closes that window instead of quitting.
    /// Menu bar「退出」still terminates when no such window is key.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if AppController.shared.closeKeyUtilityWindowIfNeeded() {
            return .terminateCancel
        }
        return .terminateNow
    }

    // MARK: - Main menu (enables standard ⌘W Close)

    private func installMainMenu() {
        let main = NSMenu()

        // App menu (holds Quit — ⌘Q handled via applicationShouldTerminate)
        let appMenuItem = NSMenuItem()
        main.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(
            withTitle: "退出 RenderPause Pro",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        // File menu — Close (⌘W)
        let fileMenuItem = NSMenuItem()
        main.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "文件")
        fileMenuItem.submenu = fileMenu
        let closeItem = fileMenu.addItem(
            withTitle: "关闭",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        closeItem.target = nil // first responder chain → key window

        // Edit menu (minimal, for text fields in prefs)
        let editMenuItem = NSMenuItem()
        main.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = main
    }
}
