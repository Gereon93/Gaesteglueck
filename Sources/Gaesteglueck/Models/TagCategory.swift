import Foundation

enum TagCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case family = "Familie"
    case friendGroup = "Freundesgruppe"
    case role = "Hochzeitsrolle"
    case activity = "Aktivität"
    case work = "Arbeitskontext"
    case custom = "Eigene"
    var id: String { rawValue }

    var defaultColor: String {
        switch self {
        case .family: "#E74C3C"
        case .friendGroup: "#2ECC71"
        case .role: "#F1C40F"
        case .activity: "#9B59B6"
        case .work: "#3498DB"
        case .custom: "#95A5A6"
        }
    }
}
