import Foundation

/// Was im Sitz-Kreis (statt der Initialen) angezeigt wird. Sinnvoll vor allem
/// wenn Namen eingeblendet sind — dann sind die Initialen redundant und der
/// Kreis kann größer das Alters-Icon oder die Allergen-Nummer zeigen. Fällt
/// pro Gast auf Initialen zurück, wenn das gewählte Merkmal fehlt.
enum SeatChipContent: String, CaseIterable, Identifiable, Sendable {
    case initials = "initials"
    case intolerance = "intolerance"
    case age = "age"
    /// Zeigt pro Gast das Relevante: Allergen-Nummer hat Vorrang (Catering-
    /// Sicherheit), sonst Alters-Icon, sonst Initialen. Das jeweils andere
    /// Merkmal bleibt als Eck-Badge sichtbar.
    case ageAndIntolerance = "both"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .initials: "Initialen"
        case .intolerance: "Allergen-Nummer"
        case .age: "Alters-Icon"
        case .ageAndIntolerance: "Alter + Allergen"
        }
    }

    var icon: String {
        switch self {
        case .initials: "textformat.abc"
        case .intolerance: "exclamationmark.triangle"
        case .age: "figure.child"
        case .ageAndIntolerance: "person.crop.circle.badge.exclamationmark"
        }
    }

    /// Zeigt dieser Kreis-Inhalt Allergen-Nummern? (→ Legende muss die
    /// Unverträglichkeiten-Sektion einblenden, auch ohne Allergie-Anzeigemodus.)
    var showsIntolerance: Bool { self == .intolerance || self == .ageAndIntolerance }

    /// Zeigt dieser Kreis-Inhalt Alters-Icons? (→ Legende muss die Alters-
    /// Sektion einblenden, auch ohne Alters-Marker-Toggle.)
    var showsAge: Bool { self == .age || self == .ageAndIntolerance }
}
