#if canImport(SwiftUI)
import SwiftUI

extension Side {
    var color: Color {
        switch self {
        case .bride: .pink
        case .groom: .blue
        case .neutral: .gray
        }
    }
}

extension RSVPStatus {
    var color: Color {
        switch self {
        case .pending: .orange
        case .confirmed: .green
        case .declined: .red
        }
    }
}

extension RelationshipType {
    var color: Color {
        switch self {
        case .partner: .pink
        case .family: .orange
        case .friend: .green
        case .acquaintance: .blue
        case .toxic: .red
        }
    }

    var icon: String {
        switch self {
        case .partner: "heart.fill"
        case .family: "figure.2.and.child"
        case .friend: "person.2"
        case .acquaintance: "person.wave.2"
        case .toxic: "exclamationmark.triangle.fill"
        }
    }
}
#endif
