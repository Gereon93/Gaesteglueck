import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class Event {
    var id: UUID
    var name: String
    var date: Date?
    var venue: String
    var createdAt: Date

    init(name: String, date: Date? = nil, venue: String = "") {
        self.id = UUID()
        self.name = name
        self.date = date
        self.venue = venue
        self.createdAt = .now
    }
}
