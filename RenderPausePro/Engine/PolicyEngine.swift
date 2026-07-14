import Foundation

final class PolicyEngine {
    private let ruleStore: RuleStore
    private let sessionStore: SessionStore
    private let settingsStore: SettingsStore

    init(ruleStore: RuleStore, sessionStore: SessionStore, settingsStore: SettingsStore) {
        self.ruleStore = ruleStore
        self.sessionStore = sessionStore
        self.settingsStore = settingsStore
    }

    func evaluate(
        frontmostBundleID: String?,
        running: [RunningAppSnapshot],
        now: Date = Date()
    ) -> [PolicyCommand] {
        var commands: [PolicyCommand] = []
        var runningByID: [String: RunningAppSnapshot] = [:]
        for snap in running {
            if let existing = runningByID[snap.bundleID] {
                if snap.isActive && !existing.isActive {
                    runningByID[snap.bundleID] = snap
                }
            } else {
                runningByID[snap.bundleID] = snap
            }
        }

        let threshold = settingsStore.settings.backgroundSeconds
        let action: OptimizeAction = FeatureFlags.allowMinimizeMode
            ? settingsStore.settings.optimizeAction
            : .hide

        for rule in ruleStore.rules {
            if let app = runningByID[rule.bundleID], app.isFinished {
                sessionStore.clear(rule.bundleID)
                continue
            }
            guard let app = runningByID[rule.bundleID] else {
                sessionStore.clear(rule.bundleID)
                continue
            }

            if !rule.enabled {
                if sessionStore.state(for: rule.bundleID) == .optimized {
                    commands.append(.restore(bundleID: rule.bundleID, action: action, reason: "disabled"))
                }
                commands.append(.setState(bundleID: rule.bundleID, state: .paused))
                continue
            }

            // Snapshot.isActive is already "effective regular front" from WorkspaceSensor.
            let isFront = app.isActive || frontmostBundleID == rule.bundleID

            if isFront {
                if sessionStore.state(for: rule.bundleID) == .optimized {
                    commands.append(.restore(bundleID: rule.bundleID, action: action, reason: "activated"))
                }
                commands.append(.setState(bundleID: rule.bundleID, state: .watched))
                continue
            }

            if sessionStore.state(for: rule.bundleID) == .optimized {
                continue
            }

            guard settingsStore.settings.monitoringEnabled else {
                commands.append(.setState(bundleID: rule.bundleID, state: .watched))
                continue
            }

            if action == .hide && app.isHidden {
                commands.append(.setState(bundleID: rule.bundleID, state: .optimized))
                continue
            }

            if app.secondsSinceDeactivated >= threshold {
                commands.append(.optimize(
                    bundleID: rule.bundleID,
                    action: action,
                    reason: "background+\(Int(app.secondsSinceDeactivated))s"
                ))
                commands.append(.setState(bundleID: rule.bundleID, state: .optimized))
            } else {
                commands.append(.setState(bundleID: rule.bundleID, state: .watched))
            }
        }

        return commands
    }
}
