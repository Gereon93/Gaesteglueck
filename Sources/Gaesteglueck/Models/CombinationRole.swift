import Foundation

enum CombinationRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case head = "Kopf"
    case middle = "Mitte"
    case end = "Ende"
    case corner = "Ecke"
    var id: String { rawValue }
}
