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
    /// Optionaler fester Sitzplatz am Tisch (0-basierter Index, abhängig von
    /// Tischform + Kapazität). nil = "irgendwo am Tisch", was der Default-Fall
    /// bleiben soll — wir wollen niemanden zur fixen Sitzwahl zwingen.
    var seatIndex: Int?
    /// Stabile Quellen-ID aus dem Import (Email, Telefon, Zeitstempel, Zeilennummer).
    /// Wird beim Re-Import als primärer Match-Schlüssel benutzt — Name allein ist
    /// zu unzuverlässig (zwei Horst Maiers sind nicht dieselbe Person).
    var sourceID: String = ""
    var sourceEmail: String = ""

    init(
        firstName: String,
        lastName: String = "",
        partnerAssignment: PartnerAssignment = .unassigned,
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
        registrationGroup: UUID? = nil,
        sourceID: String = "",
        sourceEmail: String = ""
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
        self.seatIndex = nil
        self.sourceID = sourceID
        self.sourceEmail = sourceEmail
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
