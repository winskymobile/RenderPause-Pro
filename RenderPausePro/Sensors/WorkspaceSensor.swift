import AppKit
import Foundation

final class WorkspaceSensor {
    var onChange: (() -> Void)?

    private var observers: [NSObjectProtocol] = []
    /// bundleID -> time when app last left frontmost/active
    private var deactivatedAt: [String: Date] = [:]
    private var lastFrontmost: String?

    func start() {
        stop()
        lastFrontmost = frontmostBundleID()
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
        let current = frontmostBundleID()
        if let previous = lastFrontmost, previous != current {
            // previous left foreground
            if deactivatedAt[previous] == nil {
                deactivatedAt[previous] = Date()
            }
        }
        if let current {
            // currently frontmost: clear background timer
            deactivatedAt.removeValue(forKey: current)
        }
        // If notification carries an app that deactivated, stamp it.
        if note.name == NSWorkspace.didDeactivateApplicationNotification,
           let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let id = app.bundleIdentifier,
           id != current {
            if deactivatedAt[id] == nil {
                deactivatedAt[id] = Date()
            }
        }
        if note.name == NSWorkspace.didActivateApplicationNotification,
           let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let id = app.bundleIdentifier {
            deactivatedAt.removeValue(forKey: id)
        }
        if note.name == NSWorkspace.didTerminateApplicationNotification,
           let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           let id = app.bundleIdentifier {
            deactivatedAt.removeValue(forKey: id)
        }
        lastFrontmost = current
        onChange?()
    }

    func frontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func snapshots(for bundleIDs: Set<String>, now: Date = Date()) -> [RunningAppSnapshot] {
        let front = frontmostBundleID()
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard let id = app.bundleIdentifier, bundleIDs.contains(id) else { return nil }
            let isFront = app.isActive || front == id
            if isFront {
                deactivatedAt.removeValue(forKey: id)
            } else if deactivatedAt[id] == nil {
                // First time we observe it in background (e.g. already background at launch)
                deactivatedAt[id] = now
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
                isActive: app.isActive,
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
        // Prefer regular GUI process over helpers that may share identifiers.
        return matches.first(where: { $0.activationPolicy == .regular }) ?? matches.first
    }

    deinit { stop() }
}
