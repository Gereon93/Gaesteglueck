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
    /// Wenn false: Tag wird vom Sitzplan-Algorithmus, KI-Prompt und allen
    /// Services ignoriert. UI-mäßig bleibt der Tag sichtbar (für späteres
    /// Reaktivieren), aber wirkt nicht auf die Logik. Default true.
    var isActive: Bool = true

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
        self.isActive = true
    }

    func involves(_ guestID: UUID) -> Bool {
        guestIDs.contains(guestID)
    }

    var guestCount: Int { guestIDs.count }
}
