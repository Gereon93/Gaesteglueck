import Foundation

enum RelationshipType: String, Codable, CaseIterable, Identifiable, Sendable {
    case partner = "Partner"
    case family = "Familie"
    case friend = "Freunde"
    case acquaintance = "Bekannte"
    case toxic = "Konflikt"
    var id: String { rawValue }

    var weight: Double {
        switch self {
        case .partner: 1.0
        case .family: 0.7
        case .friend: 0.4
        case .acquaintance: 0.2
        case .toxic: -5.0
        }
    }

    var isHardConstraint: Bool {
        switch self {
        case .partner, .toxic: true
        default: false
        }
    }
}
