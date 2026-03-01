import Foundation

enum TableShape: String, Codable, CaseIterable, Identifiable, Sendable {
    case round = "Rund"
    case rectangular = "Eckig"
    case brideTable = "Brauttisch"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .round: "circle"
        case .rectangular: "rectangle"
        case .brideTable: "rectangle.split.3x1"
        }
    }
}
