#if canImport(SwiftUI)
import SwiftUI

/// Geteilte Darstellungs-Helfer für Gast-Zeile und -Inspector: Avatar-Tag,
/// Diät-Badge, Chip-Kind und Menü-Label. Aus `GuestListView` herausgezogen,
/// damit Tabelle und Inspector dieselbe Quelle nutzen statt je eine Kopie.
enum GuestDisplayFormatting {
    static func chipKind(for category: TagCategory) -> TagChip.Kind {
        switch category {
        case .family: .family
        case .friendGroup: .friends
        case .role: .role
        case .activity: .activity
        case .work: .work
        case .custom: .custom
        }
    }

    static func avatarKind(for guest: Guest, tags: [Tag]) -> Avatar.TagKind {
        let firstTag = tags.first { $0.guestIDs.contains(guest.id) }
        return firstTag.map { chipKindToAvatar(chipKind(for: $0.category)) } ?? .custom
    }

    static func dietBadge(for guest: Guest) -> Avatar.DietBadge? {
        if guest.hasIntolerances { return .allergie }
        switch guest.dietaryChoice.lowercased() {
        case "vegetarisch": return .veg
        case "vegan": return .vegan
        default: return nil
        }
    }

    static func menuLabel(for guest: Guest) -> String {
        if guest.hasIntolerances {
            return "\(guest.dietaryChoice) · \(guest.intolerances.first ?? "Allergie")"
        }
        return guest.dietaryChoice
    }

    private static func chipKindToAvatar(_ kind: TagChip.Kind) -> Avatar.TagKind {
        switch kind {
        case .family: .family
        case .friends: .friends
        case .role: .role
        case .activity: .activity
        case .work: .work
        case .custom: .custom
        }
    }
}
#endif
