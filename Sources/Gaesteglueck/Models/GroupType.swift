import Foundation

enum GroupType: String, Codable, CaseIterable, Identifiable, Sendable {
    case immediateFamily = "Engste Familie"
    case extendedFamily = "Erweiterte Familie"
    case schoolFriend = "Schulfreunde"
    case universityFriend = "Studienkollegen"
    case roommate = "Mitbewohner"
    case workColleague = "Arbeitskollegen"
    case clubMember = "Verein"
    case jga = "JGA"
    case neighbor = "Nachbarn"
    case other = "Sonstige"
    var id: String { rawValue }
    var cohesionWeight: Double {
        switch self {
        case .immediateFamily: 0.9
        case .extendedFamily: 0.6
        case .jga: 0.7
        case .schoolFriend, .universityFriend, .roommate: 0.5
        case .workColleague, .clubMember: 0.4
        case .neighbor, .other: 0.2
        }
    }
}
