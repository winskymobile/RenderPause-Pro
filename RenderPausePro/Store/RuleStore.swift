import Foundation

final class RuleStore {
    private let defaults: UserDefaults
    private let key = "rules.v1"
    private(set) var rules: [AppRule] = []

    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func rule(for bundleID: String) -> AppRule? {
        rules.first { $0.bundleID == bundleID }
    }

    func enabledRules() -> [AppRule] {
        rules.filter(\.enabled)
    }

    @discardableResult
    func upsert(_ rule: AppRule) -> Bool {
        if rule.bundleID == BundleIdentity.bundleID {
            return false
        }
        if let idx = rules.firstIndex(where: { $0.bundleID == rule.bundleID }) {
            rules[idx] = rule
        } else {
            rules.append(rule)
        }
        rules.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        persist()
        onChange?()
        return true
    }

    func remove(bundleID: String) {
        rules.removeAll { $0.bundleID == bundleID }
        persist()
        onChange?()
    }

    func setEnabled(bundleID: String, enabled: Bool) {
        guard var rule = rule(for: bundleID) else { return }
        rule.enabled = enabled
        _ = upsert(rule)
    }

    private func load() {
        guard let data = defaults.data(forKey: key) else {
            rules = []
            return
        }
        do {
            rules = try JSONDecoder().decode([AppRule].self, from: data)
        } catch {
            rules = []
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(rules) {
            defaults.set(data, forKey: key)
        }
    }
}
