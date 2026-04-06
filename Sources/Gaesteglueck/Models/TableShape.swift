import Foundation

enum TableShape: String, Codable, CaseIterable, Identifiable, Sendable {
    case round = "Rund"
    case rectangular = "Rechteckig"
    case square = "Quadratisch"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .round: "circle"
        case .rectangular: "rectangle"
        case .square: "square"
        }
    }
}
