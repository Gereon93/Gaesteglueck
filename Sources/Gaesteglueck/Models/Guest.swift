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
    var firstName: String
    var lastName: String
    var partnerAssignment: PartnerAssignment
    var ageCategory: AgeCategory
    var age: Int?
    var familyID: UUID?
    var familyRole: FamilyRole?
    var familyRolePartner: PartnerAssignment?
    var dietaryChoice: String
    var intolerances: [String]
    var funFact: String
    var notes: String
    var employer: String
    var profession: String
    var hobbies: [String]
    var languages: [String]
    var registrationGroup: UUID?
    var rsvpStatus: RSVPStatus
    var isPinned: Bool
    var table: GuestTable?

    init(
        firstName: String,
        lastName: String = "",
        partnerAssignment: PartnerAssignment = .both,
        ageCategory: AgeCategory = .adult,
        age: Int? = nil,
        familyID: UUID? = nil,
        familyRole: FamilyRole? = nil,
        familyRolePartner: PartnerAssignment? = nil,
        dietaryChoice: String = "Fleisch",
        intolerances: [String] = [],
        funFact: String = "",
        notes: String = "",
        rsvpStatus: RSVPStatus = .confirmed,
        registrationGroup: UUID? = nil
    ) {
        self.id = UUID()
        self.firstName = firstName
        self.lastName = lastName
        self.partnerAssignment = partnerAssignment
        self.ageCategory = ageCategory
        self.age = age
        self.familyID = familyID
        self.familyRole = familyRole
        self.familyRolePartner = familyRolePartner
        self.dietaryChoice = dietaryChoice
        self.intolerances = intolerances
        self.funFact = funFact
        self.notes = notes
        self.employer = ""
        self.profession = ""
        self.hobbies = []
        self.languages = []
        self.registrationGroup = registrationGroup
        self.rsvpStatus = rsvpStatus
        self.isPinned = false
    }

    var fullName: String {
        lastName.isEmpty ? firstName : "\(firstName) \(lastName)"
    }

    var hasIntolerances: Bool {
        !intolerances.isEmpty
    }

    var dietarySummary: String {
        var parts: [String] = []
        if dietaryChoice != "Fleisch" {
            parts.append(dietaryChoice)
        }
        if hasIntolerances {
            parts.append("⚠️ \(intolerances.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }

    var needsSeat: Bool {
        ageCategory.needsSeat
    }
}
