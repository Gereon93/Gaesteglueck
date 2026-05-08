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
}
