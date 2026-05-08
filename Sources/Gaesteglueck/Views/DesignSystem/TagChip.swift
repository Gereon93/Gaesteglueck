#if canImport(SwiftUI)
import SwiftUI

/// Beziehungs-Tag — kleine Pille mit farbigem Punkt + Label. Farbe richtet sich
/// nach der Tag-Kategorie aus dem Design-Brief.
struct TagChip: View {
    enum Kind {
        case family, friends, role, activity, work, custom

        var dotColor: Color {
            switch self {
            case .family: Tokens.Colors.tagFamily
            case .friends: Tokens.Colors.tagFriends
            case .role: Tokens.Colors.tagRole
            case .activity: Tokens.Colors.tagActivity
            case .work: Tokens.Colors.tagWork
            case .custom: Tokens.Colors.tagCustom
            }
        }
    }

    let label: String
    var kind: Kind = .family
    var size: Size = .md

    enum Size {
        case sm, md
        var fontSize: CGFloat { self == .sm ? 11 : 12 }
        var horizontalPadding: CGFloat { self == .sm ? 6 : 7 }
        var verticalPadding: CGFloat { self == .sm ? 2 : 3 }
        var dotSize: CGFloat { 6 }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(kind.dotColor)
                .frame(width: size.dotSize, height: size.dotSize)
            Text(label)
                .font(.system(size: size.fontSize, weight: .medium, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
        }
        .padding(.vertical, size.verticalPadding)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.leading, size.horizontalPadding - 1)
        .background(Tokens.Colors.bg2)
        .overlay {
            Capsule().strokeBorder(Tokens.Colors.line, lineWidth: 1)
        }
        .clipShape(Capsule())
    }
}
#endif
