import Foundation

enum TableShape: String, Codable, CaseIterable, Identifiable, Sendable {
    case round = "Rund"
    case rectangular = "Eckig"
    case brideTable = "Brauttisch"
    var id: String { rawValue }
}
