import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class Constraint {
    var id: UUID
    var type: ConstraintType
    var guestIDs: [UUID]
    var reason: String

    init(type: ConstraintType, guestIDs: [UUID], reason: String = "") {
        self.id = UUID()
        self.type = type
        self.guestIDs = guestIDs
        self.reason = reason
    }

    func involves(_ guestID: UUID) -> Bool {
        guestIDs.contains(guestID)
    }

    func isMustSitLink(for ids: Set<UUID>) -> Bool {
        type == .mustSitTogether && Set(guestIDs) == ids
    }
}
