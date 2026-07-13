import AppKit

enum HideActuator {
    @discardableResult
    static func hide(_ app: NSRunningApplication) -> Bool {
        app.hide()
    }

    @discardableResult
    static func unhide(_ app: NSRunningApplication) -> Bool {
        app.unhide()
    }
}
