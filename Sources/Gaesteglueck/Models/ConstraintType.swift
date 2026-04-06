import Foundation

enum ConstraintType: String, Codable, CaseIterable, Identifiable, Sendable {
    case mustSitTogether = "Muss zusammen sitzen"
    case mustNotSitTogether = "Darf nicht zusammen sitzen"
    var id: String { rawValue }
}
