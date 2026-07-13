import AppKit

enum RestoreCoordinator {
    static func restore(app: NSRunningApplication, action: OptimizeAction) {
        switch action {
        case .hide:
            _ = HideActuator.unhide(app)
        case .minimize:
            _ = MinimizeActuator.deminiaturizeAllWindows(pid: app.processIdentifier)
        }
    }

    /// Returns nil on success, or an error reason code.
    static func optimize(app: NSRunningApplication, action: OptimizeAction) -> String? {
        switch action {
        case .hide:
            return HideActuator.hide(app) ? nil : "hide_failed"
        case .minimize:
            switch MinimizeActuator.minimizeAllWindows(pid: app.processIdentifier) {
            case .success: return nil
            case .notTrusted: return "ax_not_trusted"
            case .failed: return "minimize_failed"
            }
        }
    }
}
