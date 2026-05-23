import Foundation

enum AgeCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case adult = "Erwachsener"
    case teenager = "Teenager"
    case child = "Kind"
    case toddler = "Kleinkind"
    case baby = "Baby"
    var id: String { rawValue }

    var needsSeat: Bool {
        switch self {
        case .adult, .teenager, .child, .toddler: true
        case .baby: false
        }
    }

    /// Wird im Sitzplan mit einem Alters-Icon markiert? Erwachsene nicht.
    var isMarkedAge: Bool { self != .adult }

    /// SF-Symbol-Name für das Alters-Badge am Sitz-Chip und in der Legende.
    var iconName: String {
        switch self {
        case .adult: "person"
        case .teenager: "figure.walk"
        case .child: "figure.child"
        case .toddler: "figure.and.child.holdinghands"
        case .baby: "stroller"
        }
    }
}
