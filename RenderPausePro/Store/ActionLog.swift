import Foundation

final class ActionLog {
    private let defaults: UserDefaults
    private let key = "actionLog.v1"
    private let maxEntries = 200
    private(set) var entries: [LogEntry] = []

    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func append(_ entry: LogEntry) {
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        persist()
        onChange?()
    }

    func todayOptimizeCount(now: Date = Date(), calendar: Calendar = .current) -> Int {
        entries.filter { $0.event == "optimized" && calendar.isDate($0.date, inSameDayAs: now) }.count
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: key)
        }
    }
}
