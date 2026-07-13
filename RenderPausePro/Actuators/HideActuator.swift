import AppKit

enum HideActuator {
    /// Hides the app. `NSRunningApplication.hide()` can return false even when
    /// the app ends up hidden (common with Electron). Always verify `isHidden`.
    @discardableResult
    static func hide(_ app: NSRunningApplication) -> Bool {
        if app.isHidden { return true }
        let reported = app.hide()
        // Give AppKit a beat to update state for multi-process apps.
        if app.isHidden { return true }
        // Some apps flip visibility via System Events even when the Bool is false.
        // One short runloop spin helps observe the result.
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        return reported || app.isHidden
    }

    @discardableResult
    static func unhide(_ app: NSRunningApplication) -> Bool {
        if !app.isHidden { return true }
        let reported = app.unhide()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        return reported || !app.isHidden
    }
}
