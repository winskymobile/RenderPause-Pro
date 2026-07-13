import Foundation

final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "settings.v1"
    private(set) var settings: AppSettings

    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
            settings.normalize()
        } else {
            settings = .default
        }
    }

    func update(_ mutate: (inout AppSettings) -> Void) {
        mutate(&settings)
        settings.normalize()
        persist()
        onChange?()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: key)
        }
    }
}
