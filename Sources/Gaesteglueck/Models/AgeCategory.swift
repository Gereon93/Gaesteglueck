import Foundation

enum AgeCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case adult = "Erwachsener"
    case child = "Kind"
    case toddler = "Kleinkind"
    case baby = "Baby"
    var id: String { rawValue }

    var needsSeat: Bool {
        switch self {
        case .adult, .child, .toddler: true
        case .baby: false
        }
    }
}
