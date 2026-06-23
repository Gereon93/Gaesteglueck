import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

enum RSVPStatus: String, Codable, CaseIterable, Sendable {
    case pending = "Ausstehend"
    case confirmed = "Zugesagt"
    case declined = "Abgesagt"
}

enum Gender: String, Codable, CaseIterable, Sendable, Identifiable {
    case unspecified = "—"
    case male = "m"
    case female = "w"
    case diverse = "d"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .unspecified: "Ohne Angabe"
        case .male: "Männlich (m)"
        case .female: "Weiblich (w)"
        case .diverse: "Divers (d)"
        }
    }
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
    /// KI-vereinheitlichte Fassung des FunFacts (1. Person). Leer = noch
    /// keine. `funFact` bleibt IMMER die unveränderte Rohdaten-Eingabe;
    /// Anzeige/Export nutzen `funFactDisplay` (vereinheitlicht, Fallback roh).
    var funFactNormalized: String = ""
    var notes: String
    var employer: String
    var profession: String
    var hobbies: [String]
    var languages: [String]
    var registrationGroup: UUID?
    var rsvpStatus: RSVPStatus
    var isPinned: Bool
    var table: GuestTable?
    var seatIndex: Int?
    /// Stabile Quellen-ID aus dem Import (Email, Telefon, Zeitstempel, Zeilennummer).
    /// Wird beim Re-Import als primärer Match-Schlüssel benutzt — Name allein ist
    /// zu unzuverlässig (zwei Horst Maiers sind nicht dieselbe Person).
    var sourceID: String = ""
    var sourceEmail: String = ""
    /// Vom User (oder per KI-Check) bestätigt dass der FunFact „gut" ist
    /// — d.h. konkret, persönlich, zum Vorlesen am Brauttisch geeignet.
    /// Default false: noch unbestätigt. Wird beim Filter „FunFact ok"
    /// und beim Export „Liste unbestätigter FunFacts" ausgewertet.
    var funFactApproved: Bool = false
    var phoneNumber: String = ""
    var title: String = ""
    var genderRaw: String = ""
    var gender: Gender {
        get { Gender(rawValue: genderRaw) ?? .unspecified }
        set { genderRaw = newValue == .unspecified ? "" : newValue.rawValue }
    }

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
        self.funFactApproved = false
    }

    var fullName: String {
        lastName.isEmpty ? firstName : "\(firstName) \(lastName)"
    }

    var hasIntolerances: Bool {
        !intolerances.isEmpty
    }

    /// Was angezeigt/exportiert wird: vereinheitlichte Fassung wenn vorhanden,
    /// sonst Fallback auf die Rohdaten. Rohdaten gehen nie verloren.
    var funFactDisplay: String {
        let n = funFactNormalized.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? funFact : funFactNormalized
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

    var countsForSeating: Bool { rsvpStatus == .confirmed }

    var isLateCancellation: Bool { rsvpStatus == .declined && table != nil }

    func applyRSVP(_ newStatus: RSVPStatus) {
        let wasConfirmed = rsvpStatus == .confirmed
        let wasLateCancellation = isLateCancellation
        switch newStatus {
        case .confirmed:
            if rsvpStatus == .declined {
                table = nil
                seatIndex = nil
            }
        case .pending:
            table = nil
            seatIndex = nil
        case .declined:
            seatIndex = nil
            if !wasConfirmed && !wasLateCancellation { table = nil }
        }
        rsvpStatus = newStatus
    }

    var awaitsSeating: Bool { countsForSeating && needsSeat && table == nil }

    var hasIncompleteFunFact: Bool {
        funFact.trimmingCharacters(in: .whitespaces).isEmpty || !funFactApproved
    }

    var funFactNeedsReview: Bool {
        !funFact.trimmingCharacters(in: .whitespaces).isEmpty && !funFactApproved
    }

    var needsFunFactFollowUp: Bool {
        countsForSeating && hasIncompleteFunFact
    }

    static func byName(_ lhs: Guest, _ rhs: Guest) -> Bool {
        if lhs.firstName == rhs.firstName { return lhs.lastName < rhs.lastName }
        return lhs.firstName < rhs.firstName
    }
}
