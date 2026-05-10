import Foundation

struct SeatingRules: Codable, Equatable, Sendable {
    var seatWidthCm: Double
    var tableMinDistanceCm: Double
    var aisleWidthCm: Double

    static let `default` = SeatingRules(
        seatWidthCm: 60,
        tableMinDistanceCm: 80,
        aisleWidthCm: 120
    )

    var isValid: Bool {
        seatWidthCm >= 40 && aisleWidthCm >= tableMinDistanceCm
    }
}
