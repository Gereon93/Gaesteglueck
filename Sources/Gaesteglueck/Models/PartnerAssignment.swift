import Foundation

enum PartnerAssignment: String, Codable, CaseIterable, Identifiable, Sendable {
    case partner1 = "Partner 1"
    case partner2 = "Partner 2"
    case both = "Beide"
    var id: String { rawValue }
}
