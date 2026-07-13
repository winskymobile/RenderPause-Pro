import ApplicationServices
import AppKit
import Foundation

enum MinimizeActuator {
    enum Result {
        case success
        case notTrusted
        case failed
    }

    static func minimizeAllWindows(pid: pid_t) -> Result {
        guard PermissionGate.isAccessibilityTrusted(prompt: false) else { return .notTrusted }
        let appEl = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        let copy = AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &windowsRef)
        guard copy == .success, let windows = windowsRef as? [AXUIElement] else { return .failed }

        var any = false
        for window in windows {
            var minimizedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef) == .success,
               let num = minimizedRef as? NSNumber,
               num.boolValue {
                continue
            }
            // Prefer setting AXMinimized; fallback to pressing the minimize button.
            if AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue) == .success {
                any = true
                continue
            }
            var buttonRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXMinimizeButtonAttribute as CFString, &buttonRef) == .success,
               let button = buttonRef {
                let btn = unsafeBitCast(button, to: AXUIElement.self)
                if AXUIElementPerformAction(btn, kAXPressAction as CFString) == .success {
                    any = true
                }
            }
        }
        return any ? .success : .failed
    }

    static func deminiaturizeAllWindows(pid: pid_t) -> Result {
        guard PermissionGate.isAccessibilityTrusted(prompt: false) else { return .notTrusted }
        let appEl = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return .failed }

        var any = false
        for window in windows {
            let err = AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            if err == .success { any = true }
        }
        return any ? .success : .failed
    }
}
