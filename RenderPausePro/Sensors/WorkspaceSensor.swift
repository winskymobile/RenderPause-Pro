import AppKit
import Foundation

final class WorkspaceSensor {
    var onChange: (() -> Void)?

    private var observers: [NSObjectProtocol] = []
    /// bundleID -> time when app last left *usable* foreground and became fully occluded
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
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification
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

        if let previousRegular, previousRegular != currentRegular {
            // Do not start the timer if the previous app is still a Split View partner
            // of the newly focused regular app.
            let stillSplit = SplitViewDetector.isSplitPartner(
                candidateBundleID: previousRegular,
                frontmostBundleID: currentRegular
            )
            if stillSplit {
                deactivatedAt.removeValue(forKey: previousRegular)
            }
            // Timer start for non-split apps is deferred to snapshots() once we know
            // the app is fully occluded (Scheme A).
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
        } else if note.name == NSWorkspace.activeSpaceDidChangeNotification {
            // Space / Split View space changes can reshuffle focus; re-evaluate partners.
            lastRegularFrontmost = currentRegular ?? previousRegular
            if let currentRegular {
                deactivatedAt.removeValue(forKey: currentRegular)
            }
        } else {
            lastRegularFrontmost = currentRegular ?? previousRegular
        }

        onChange?()
    }

    func frontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func regularFrontmostBundleID() -> String? {
        let front = NSWorkspace.shared.frontmostApplication
        if let front, front.activationPolicy == .regular, let id = front.bundleIdentifier {
            return id
        }
        if let last = lastRegularFrontmost,
           runningApp(bundleID: last) != nil {
            return last
        }
        return NSWorkspace.shared.runningApplications.first {
            $0.isActive && $0.activationPolicy == .regular && $0.bundleIdentifier != nil
        }?.bundleIdentifier
    }

    func snapshots(for bundleIDs: Set<String>, now: Date = Date()) -> [RunningAppSnapshot] {
        let effectiveFront = regularFrontmostBundleID()
        let windows = SplitViewDetector.listOnScreenWindows()
        let splitPartners = SplitViewDetector.splitPartnerBundleIDs(
            frontmostBundleID: effectiveFront,
            among: bundleIDs,
            windows: windows
        )

        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard let id = app.bundleIdentifier, bundleIDs.contains(id) else { return nil }

            let isSystemFront = (effectiveFront == id) || (app.isActive && app.activationPolicy == .regular)
            let isSplitPartner = splitPartners.contains(id)
            // Treat Split View partners as still "in use" / foreground-equivalent.
            let isFront = isSystemFront || isSplitPartner

            // Scheme A: residual visible area means "still in use" for optimize gating.
            let partiallyVisible = OcclusionDetector.isPartiallyVisible(bundleID: id, windows: windows)
            let fullyOccluded = !partiallyVisible

            if isFront {
                deactivatedAt.removeValue(forKey: id)
            } else if partiallyVisible {
                // Peeking behind another window: do not accumulate background timer.
                deactivatedAt.removeValue(forKey: id)
            } else if fullyOccluded {
                // Only start/continue timer when not effective-foreground AND fully occluded
                // (or no significant on-screen windows).
                if deactivatedAt[id] == nil {
                    deactivatedAt[id] = now
                }
            }

            let since: TimeInterval
            if isFront || partiallyVisible {
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
                secondsSinceDeactivated: since,
                isPartiallyVisible: partiallyVisible
            )
        }
    }

    func runningApp(bundleID: String) -> NSRunningApplication? {
        let matches = NSWorkspace.shared.runningApplications.filter {
            $0.bundleIdentifier == bundleID && !$0.isTerminated
        }
        return matches.first(where: { $0.activationPolicy == .regular }) ?? matches.first
    }

    /// True when the bundle must not be optimized right now.
    func isProtectedFromOptimize(bundleID: String) -> Bool {
        if regularFrontmostBundleID() == bundleID { return true }
        if let app = runningApp(bundleID: bundleID), app.isActive { return true }
        if SplitViewDetector.isSplitPartner(
            candidateBundleID: bundleID,
            frontmostBundleID: regularFrontmostBundleID()
        ) {
            return true
        }
        let windows = SplitViewDetector.listOnScreenWindows()
        if OcclusionDetector.isPartiallyVisible(bundleID: bundleID, windows: windows) {
            return true
        }
        return false
    }

    deinit { stop() }
}
