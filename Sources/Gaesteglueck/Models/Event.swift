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
    var partner1Name: String
    var partner2Name: String
    var partner1PreMarriageName: String
    var partner2PreMarriageName: String
    var menuOptions: [String]
    var roomWidthCM: Double?
    var roomLengthCM: Double?
    var roomPlanImageData: Data?
    var createdAt: Date

    init(
        name: String,
        date: Date? = nil,
        venue: String = "",
        partner1Name: String = "",
        partner2Name: String = "",
        partner1PreMarriageName: String = "",
        partner2PreMarriageName: String = "",
        menuOptions: [String] = ["Fleisch", "Vegetarisch", "Vegan"]
    ) {
        self.id = UUID()
        self.name = name
        self.date = date
        self.venue = venue
        self.partner1Name = partner1Name
        self.partner2Name = partner2Name
        self.partner1PreMarriageName = partner1PreMarriageName
        self.partner2PreMarriageName = partner2PreMarriageName
        self.menuOptions = menuOptions
        self.roomWidthCM = nil
        self.roomLengthCM = nil
        self.roomPlanImageData = nil
        self.createdAt = .now
    }

    var partnerDisplayName1: String {
        partner1Name.isEmpty ? "Partner 1" : partner1Name
    }

    var partnerDisplayName2: String {
        partner2Name.isEmpty ? "Partner 2" : partner2Name
    }
}
