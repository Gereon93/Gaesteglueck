import Foundation

/// Welche Zusatz-Infos am Sitz-Chip angezeigt werden (Diät, Unverträglichkeiten).
/// Wird per Toolbar-Picker im Sitzplan-Canvas umgeschaltet.
enum SeatInfoDisplay: String, CaseIterable, Identifiable, Sendable {
    case none = "none"
    case dietOnly = "diet"
    case intoleranceOnly = "intolerance"
    case all = "all"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "Keine Zusatzinfos"
        case .dietOnly: "Vegan/Vegetarisch"
        case .intoleranceOnly: "Unverträglichkeiten"
        case .all: "Alles anzeigen"
        }
    }

    var icon: String {
        switch self {
        case .none: "circle.dashed"
        case .dietOnly: "leaf"
        case .intoleranceOnly: "exclamationmark.triangle"
        case .all: "info.circle"
        }
    }

    var showsDiet: Bool { self == .dietOnly || self == .all }
    var showsIntolerance: Bool { self == .intoleranceOnly || self == .all }
}
