import Foundation

enum Side: String, Codable, CaseIterable, Identifiable, Sendable {
    case bride = "Braut"
    case groom = "Bräutigam"
    case neutral = "Neutral"
    var id: String { rawValue }
}
