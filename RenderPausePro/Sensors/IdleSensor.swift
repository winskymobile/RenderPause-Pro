import CoreGraphics
import Foundation

enum IdleSensor {
    /// Seconds since last keyboard/mouse event in the login session.
    static func secondsSinceLastInput() -> TimeInterval {
        let types: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .leftMouseUp, .rightMouseUp, .otherMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .scrollWheel
        ]
        let ages = types.map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }
        return ages.min() ?? 0
    }
}
