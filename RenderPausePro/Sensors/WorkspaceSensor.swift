import AppKit

final class WorkspaceSensor {
    var onChange: (() -> Void)?

    private var observers: [NSObjectProtocol] = []

    func start() {
        stop()
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
            let token = nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.onChange?()
            }
            observers.append(token)
        }
    }

    func stop() {
        let nc = NSWorkspace.shared.notificationCenter
        observers.forEach { nc.removeObserver($0) }
        observers.removeAll()
    }

    func frontmostBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    func snapshots(for bundleIDs: Set<String>) -> [RunningAppSnapshot] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard let id = app.bundleIdentifier, bundleIDs.contains(id) else { return nil }
            return RunningAppSnapshot(
                bundleID: id,
                isActive: app.isActive,
                isHidden: app.isHidden,
                isFinished: app.isTerminated
            )
        }
    }

    func runningApp(bundleID: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleID && !$0.isTerminated }
    }

    deinit { stop() }
}
