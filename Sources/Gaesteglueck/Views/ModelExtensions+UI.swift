#if canImport(SwiftUI)
import SwiftUI

extension PartnerAssignment {
    var color: Color {
        switch self {
        case .unassigned: Color(hex: "#c4bcb5") // ink-4, dezent
        case .partner1: .pink
        case .partner2: .blue
        case .both: Color(hex: "#7a8b6c") // sage — bewusst gemeinsam
        }
    }

    /// Display-Label, das den echten Vornamen des Partners zeigt statt
    /// "Partner 1"/"Partner 2". Fällt auf den Generic-Begriff zurück wenn
    /// kein Event vorliegt.
    func displayName(for event: Event?) -> String {
        switch self {
        case .unassigned: return "Unzugeordnet"
        case .partner1: return event?.partnerDisplayName1 ?? "Partner 1"
        case .partner2: return event?.partnerDisplayName2 ?? "Partner 2"
        case .both: return "Beide"
        }
    }

    /// Kompakter Wert für schmale Spalten ("Seite"-Spalte in der Liste).
    /// Statt "Unzugeordnet" gibt's einen Strich, sonst der gleiche Vorname.
    func compactDisplayName(for event: Event?) -> String {
        switch self {
        case .unassigned: return "—"
        case .partner1: return event?.partnerDisplayName1 ?? "Partner 1"
        case .partner2: return event?.partnerDisplayName2 ?? "Partner 2"
        case .both: return "Beide"
        }
    }

    /// Liefert nil zurück wenn die Zuordnung `.unassigned` ist — praktisch für
    /// "wenn vorhanden, anzeigen, sonst nichts"-Logik im Inspector.
    var optionalSelf: PartnerAssignment? {
        self == .unassigned ? nil : self
    }
}

/// Leitet aus Tag-Mitgliedschaften die Partner-Seite eines Gastes ab.
/// Wenn Tobias in "JGA Bob" und "Realschulfreunde Bob" steckt, ist klar:
/// Tobias gehört zu Bob — auch wenn der User die Seite am Gast noch nicht
/// explizit gesetzt hat.
enum PartnerSideDeriver {
    /// Errechnet die plausible Partner-Seite aus den Tags des Gastes.
    /// Liefert nil wenn kein Tag eine Seite vorgibt.
    static func derive(for guestID: UUID, from tags: [Tag]) -> PartnerAssignment? {
        let sides = Set(tags
            .filter { $0.guestIDs.contains(guestID) }
            .compactMap { $0.partnerAssignment })
        if sides.isEmpty { return nil }
        if sides.contains(.both) { return .both }
        if sides == [.partner1] { return .partner1 }
        if sides == [.partner2] { return .partner2 }
        if sides.contains(.partner1) && sides.contains(.partner2) { return .both }
        return nil
    }

    /// Setzt die Seite am Gast WENN sie noch unzugeordnet ist. Eine bewusst
    /// vom User gesetzte Seite (Alice/Bob/Beide) wird nie überschrieben.
    /// Wenn `allGuests` mitgegeben wird, ziehen wir auch noch die anderen
    /// Mitglieder der gleichen `registrationGroup` mit auf die abgeleitete
    /// Seite (sofern die noch unzugeordnet sind) — sonst hätte z.B. nur
    /// Carina die Alice-Seite, nicht aber ihr Mann Tom und Sohn Hugo.
    static func applyIfUnassigned(_ guest: Guest, in tags: [Tag], allGuests: [Guest] = []) {
        guard guest.partnerAssignment == .unassigned else { return }
        guard let derived = derive(for: guest.id, from: tags) else { return }
        guest.partnerAssignment = derived
        propagateSide(derived, fromGuest: guest, in: allGuests)
    }

    /// Zieht die Seite des `source`-Gastes auf alle bisher unzugeordneten
    /// Mitglieder der gleichen `registrationGroup`. Genutzt vom
    /// `applyIfUnassigned` und direkt aus dem GuestFormView nach Save.
    static func propagateSide(_ side: PartnerAssignment, fromGuest source: Guest, in allGuests: [Guest]) {
        guard side != .unassigned else { return }
        guard let group = source.registrationGroup else { return }
        for peer in allGuests where peer.id != source.id
            && peer.registrationGroup == group
            && peer.partnerAssignment == .unassigned {
            peer.partnerAssignment = side
            if peer.familyRolePartner == nil {
                peer.familyRolePartner = side
            }
        }
    }
}

extension RSVPStatus {
    var color: Color {
        switch self {
        case .pending: .orange
        case .confirmed: .green
        case .declined: .red
        }
    }
}

extension ConstraintType {
    var color: Color {
        switch self {
        case .mustSitTogether: .green
        case .mustNotSitTogether: .red
        }
    }

    var icon: String {
        switch self {
        case .mustSitTogether: "link"
        case .mustNotSitTogether: "exclamationmark.triangle.fill"
        }
    }
}

extension AgeCategory {
    var icon: String {
        switch self {
        case .adult: "person.fill"
        case .teenager: "figure.stand"
        case .child: "figure.child"
        case .toddler: "figure.child.and.lock"
        case .baby: "figure.and.child.holdinghands"
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}
#endif
