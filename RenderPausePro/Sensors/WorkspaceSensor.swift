import AppKit
import Foundation

final class WorkspaceSensor {
    var onChange: (() -> Void)?

    private var observers: [NSObjectProtocol] = []
    /// bundleID -> time when app last left *regular* foreground
    private var deactivatedAt: [String: Date] = [:]
    /// Last frontmost app with regular activation policy (ignores IME / agents / menu bar).
    private var lastRegularFrontmost: String?

    func start() {
        stop()
        lastRegularFrontmost = regularFrontmostBundleID()
        if let id = lastRegularFrontmost {
            deactivatedAt.removeValue(forKey: id)
        }
        let nc = NSWorkspace.shared.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didDeactivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ]
        for name in names {
            let token = nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                self?.handle(note)
            }
            observers.append(token)
        }
    }

    func stop() {
        let nc = NSWorkspace.shared.notificationCenter
        observers.forEach { nc.removeObserver($0) }
        observers.removeAll()
    }

    private func handle(_ note: Notification) {
        let previousRegular = lastRegularFrontmost
        let currentRegular = regularFrontmostBundleID()

        // Only treat switches between *regular* apps as leaving the foreground.
        // Input methods (WeType), menu bar tools, and other agents must NOT
        // start the background timer for the app the user is still working in.
        if let previousRegular, previousRegular != currentRegular {
            if deactivatedAt[previousRegular] == nil {
                deactivatedAt[previousRegular] = Date()
            }
        }
        if let currentRegular {
            deactivatedAt.removeValue(forKey: currentRegular)
        }

        if note.name == NSWorkspace.didActivateApplicationNotification,
           let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let id = app.bundleIdentifier,
           app.activationPolicy == .regular {
            deactivatedAt.removeValue(forKey: id)
            lastRegularFrontmost = id
        } else if note.name == NSWorkspace.didTerminateApplicationNotification,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier {
            deactivatedAt.removeValue(forKey: id)
            if lastRegularFrontmost == id {
                lastRegularFrontmost = currentRegular
            }
        } else {
            lastRegularFrontmost = currentRegular ?? previousRegular
        }

        onChange?()
    }

    /// Raw system frontmost (may be IME / agent).
    func frontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    /// Frontmost among regular GUI apps only.
    func regularFrontmostBundleID() -> String? {
        let front = NSWorkspace.shared.frontmostApplication
        if let front, front.activationPolicy == .regular, let id = front.bundleIdentifier {
            return id
        }
        // If an agent/IME is frontmost, keep the last regular frontmost if still running.
        if let last = lastRegularFrontmost,
           runningApp(bundleID: last) != nil {
            return last
        }
        // Fallback: first active regular app.
        return NSWorkspace.shared.runningApplications.first {
            $0.isActive && $0.activationPolicy == .regular && $0.bundleIdentifier != nil
        }?.bundleIdentifier
    }

    func snapshots(for bundleIDs: Set<String>, now: Date = Date()) -> [RunningAppSnapshot] {
        let effectiveFront = regularFrontmostBundleID()
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard let id = app.bundleIdentifier, bundleIDs.contains(id) else { return nil }
            // Prefer regular process flags; helpers sharing the same bundle are rare.
            let isFront = (effectiveFront == id) || (app.isActive && app.activationPolicy == .regular)
            if isFront {
                deactivatedAt.removeValue(forKey: id)
            } else if deactivatedAt[id] == nil {
                // Only start the clock after we have an established regular frontmost
                // that is *someone else*. Avoid starting timers when frontmost is unknown
                // (nil) during IME-only focus transitions.
                if let effectiveFront, effectiveFront != id {
                    deactivatedAt[id] = now
                }
            }
            let since: TimeInterval
            if isFront {
                since = 0
            } else if let t = deactivatedAt[id] {
                since = max(0, now.timeIntervalSince(t))
            } else {
                since = 0
            }
            return RunningAppSnapshot(
                bundleID: id,
                isActive: isFront,
                isHidden: app.isHidden,
                isFinished: app.isTerminated,
                secondsSinceDeactivated: since
            )
        }
    }

    func runningApp(bundleID: String) -> NSRunningApplication? {
        let matches = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleID && !$0.isTerminated
        }
        return matches.first(where: { $0.activationPolicy == .regular }) ?? matches.first
    }

    deinit { stop() }
}
