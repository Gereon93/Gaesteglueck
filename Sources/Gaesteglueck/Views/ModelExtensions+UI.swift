#if canImport(SwiftUI)
import SwiftUI

extension PartnerAssignment {
    var color: Color {
        switch self {
        case .partner1: .pink
        case .partner2: .blue
        case .both: .gray
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

extension ConstraintType {
    var color: Color {
        switch self {
        case .mustSitTogether: .green
        case .mustNotSitTogether: .red
        }
    }

    var icon: String {
        switch self {
        case .mustSitTogether: "link"
        case .mustNotSitTogether: "exclamationmark.triangle.fill"
        }
    }
}

extension AgeCategory {
    var icon: String {
        switch self {
        case .adult: "person.fill"
        case .child: "figure.child"
        case .toddler: "figure.child.and.lock"
        case .baby: "figure.and.child.holdinghands"
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}
#endif
