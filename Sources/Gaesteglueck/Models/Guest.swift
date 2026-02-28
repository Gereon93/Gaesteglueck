import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

enum RSVPStatus: String, Codable, CaseIterable, Sendable {
    case pending = "Ausstehend"
    case confirmed = "Zugesagt"
    case declined = "Abgesagt"
}

#if canImport(SwiftData)
@Model
#endif
final class Guest {
    var id: UUID
    var name: String
    var side: Side
    var groupType: GroupType?
    var customGroupName: String?
    var familyID: UUID?
    var familyRole: FamilyRole?
    var mainContactPersonID: UUID?
    var dietaryPreference: DietaryPreference
    var allergies: String
    var rsvpStatus: RSVPStatus
    var isChild: Bool
    var notes: String
    var isPinned: Bool
    var table: GuestTable?

    init(
        name: String,
        side: Side,
        groupType: GroupType? = nil,
        customGroupName: String? = nil,
        familyID: UUID? = nil,
        familyRole: FamilyRole? = nil,
        dietaryPreference: DietaryPreference = .meat,
        allergies: String = "",
        rsvpStatus: RSVPStatus = .pending,
        isChild: Bool = false,
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.side = side
        self.groupType = groupType
        self.customGroupName = customGroupName
        self.familyID = familyID
        self.familyRole = familyRole
        self.mainContactPersonID = nil
        self.dietaryPreference = dietaryPreference
        self.allergies = allergies
        self.rsvpStatus = rsvpStatus
        self.isChild = isChild
        self.notes = notes
        self.isPinned = false
    }

    var groupLabel: String? {
        guard let groupType else { return nil }
        if let custom = customGroupName, !custom.isEmpty {
            return "\(groupType.rawValue): \(custom)"
        }
        return groupType.rawValue
    }

    var dietarySummary: String {
        var parts: [String] = []
        if dietaryPreference != .meat {
            parts.append(dietaryPreference.rawValue)
        }
        if !allergies.isEmpty {
            parts.append("⚠️ \(allergies)")
        }
        return parts.joined(separator: " · ")
    }
}
