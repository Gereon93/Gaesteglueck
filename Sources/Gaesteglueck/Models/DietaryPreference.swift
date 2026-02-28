import Foundation

enum DietaryPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case meat = "Fleisch"
    case vegetarian = "Vegetarisch"
    case vegan = "Vegan"
    var id: String { rawValue }
    var badge: String {
        switch self {
        case .meat: "🥩"
        case .vegetarian: "🥬"
        case .vegan: "🌱"
        }
    }
}
