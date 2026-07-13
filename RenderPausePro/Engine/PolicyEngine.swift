import Foundation

final class PolicyEngine {
    private let ruleStore: RuleStore
    private let sessionStore: SessionStore
    private let settingsStore: SettingsStore
    private var exemptions: [String: Date] = [:]

    init(ruleStore: RuleStore, sessionStore: SessionStore, settingsStore: SettingsStore) {
        self.ruleStore = ruleStore
        self.sessionStore = sessionStore
        self.settingsStore = settingsStore
    }

    func exempt(bundleID: String, until: Date) {
        exemptions[bundleID] = until
    }

    func clearExemption(bundleID: String) {
        exemptions.removeValue(forKey: bundleID)
    }

    func isExempt(_ bundleID: String, now: Date = Date()) -> Bool {
        guard let until = exemptions[bundleID] else { return false }
        if until <= now {
            exemptions.removeValue(forKey: bundleID)
            return false
        }
        return true
    }

    func evaluate(
        frontmostBundleID: String?,
        running: [RunningAppSnapshot],
        now: Date = Date()
    ) -> [PolicyCommand] {
        var commands: [PolicyCommand] = []
        var runningByID: [String: RunningAppSnapshot] = [:]
        for snap in running {
            // Prefer an active instance if duplicates exist.
            if let existing = runningByID[snap.bundleID] {
                if snap.isActive && !existing.isActive {
                    runningByID[snap.bundleID] = snap
                }
            } else {
                runningByID[snap.bundleID] = snap
            }
        }

        for rule in ruleStore.rules {
            if let app = runningByID[rule.bundleID], app.isFinished {
                sessionStore.clear(rule.bundleID)
                continue
            }
            guard let app = runningByID[rule.bundleID] else {
                sessionStore.clear(rule.bundleID)
                continue
            }

            if !rule.enabled || rule.locked || isExempt(rule.bundleID, now: now) {
                if sessionStore.state(for: rule.bundleID) == .optimized {
                    commands.append(.restore(bundleID: rule.bundleID, action: rule.action, reason: "paused"))
                }
                commands.append(.setState(bundleID: rule.bundleID, state: .paused))
                continue
            }

            let isFront = app.isActive || frontmostBundleID == rule.bundleID

            if isFront {
                if sessionStore.state(for: rule.bundleID) == .optimized {
                    commands.append(.restore(bundleID: rule.bundleID, action: rule.action, reason: "activated"))
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

            if rule.action == .hide && app.isHidden {
                commands.append(.setState(bundleID: rule.bundleID, state: .optimized))
                continue
            }

            // Key fix: use per-app background duration, not global system input idle.
            if app.secondsSinceDeactivated >= rule.idleSeconds {
                commands.append(.optimize(
                    bundleID: rule.bundleID,
                    action: rule.action,
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
