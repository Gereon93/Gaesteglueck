import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class Tag {
    var id: UUID
    var name: String
    var category: TagCategory
    var color: String
    var partnerAssignment: PartnerAssignment?
    var guestIDs: [UUID]

    init(
        name: String,
        category: TagCategory,
        color: String? = nil,
        partnerAssignment: PartnerAssignment? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.color = color ?? category.defaultColor
        self.partnerAssignment = partnerAssignment
        self.guestIDs = []
    }

    func involves(_ guestID: UUID) -> Bool {
        guestIDs.contains(guestID)
    }

    var guestCount: Int { guestIDs.count }
}
