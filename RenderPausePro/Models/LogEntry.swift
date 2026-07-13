import Foundation

struct LogEntry: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var date: Date
    var bundleID: String
    var displayName: String
    var event: String
    var action: String?
    var reason: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        bundleID: String,
        displayName: String,
        event: String,
        action: String? = nil,
        reason: String
    ) {
        self.id = id
        self.date = date
        self.bundleID = bundleID
        self.displayName = displayName
        self.event = event
        self.action = action
        self.reason = reason
    }
}
