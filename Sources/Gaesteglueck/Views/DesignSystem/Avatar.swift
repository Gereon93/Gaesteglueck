#if canImport(SwiftUI)
import SwiftUI

/// Initialen-Avatar mit Kategorie-getöntem Hintergrund. Optional zwei Badges:
/// `pinned` (Akzent-Punkt oben rechts mit Pin-Icon) und `diet` (Punkt unten rechts).
struct Avatar: View {
    enum DietBadge: Equatable {
        case veg, vegan, allergie

        var color: Color {
            switch self {
            case .veg: Tokens.Colors.sage
            case .vegan: Color(hex: "#5a8a4a")
            case .allergie: Tokens.Colors.warn
            }
        }
    }

    enum TagKind {
        case family, friends, role, activity, work, custom

        var background: Color {
            switch self {
            case .family: Color(hex: "#f3dfe5")
            case .friends: Color(hex: "#e3e8db")
            case .role: Color(hex: "#f1e2cd")
            case .activity: Color(hex: "#dde6f0")
            case .work: Color(hex: "#e6dfee")
            case .custom: Color(hex: "#ebe2db")
            }
        }
        var foreground: Color {
            switch self {
            case .family: Color(hex: "#a85770")
            case .friends: Color(hex: "#5a6e4d")
            case .role: Color(hex: "#8b6635")
            case .activity: Color(hex: "#4f6985")
            case .work: Color(hex: "#6c5985")
            case .custom: Color(hex: "#7a6356")
            }
        }
    }

    let name: String
    var size: CGFloat = 32
    var tag: TagKind = .family
    var diet: DietBadge? = nil
    var pinned: Bool = false

    private var initials: String {
        let parts = name.split(separator: " ").compactMap { $0.first.map(String.init) }
        return String(parts.prefix(2).joined()).uppercased()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tag.background)
            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                .foregroundStyle(tag.foreground)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if let diet {
                Circle()
                    .fill(diet.color)
                    .frame(width: size * 0.36, height: size * 0.36)
                    .overlay(Circle().strokeBorder(Tokens.Colors.surface, lineWidth: 1.5))
                    .offset(x: 2, y: 2)
            }
        }
        .overlay(alignment: .topTrailing) {
            if pinned {
                ZStack {
                    Circle().fill(Tokens.Colors.accent)
                    Image(systemName: "pin.fill")
                        .font(.system(size: size * 0.22))
                        .foregroundStyle(.white)
                }
                .frame(width: size * 0.4, height: size * 0.4)
                .overlay(Circle().strokeBorder(Tokens.Colors.surface, lineWidth: 1.5))
                .offset(x: 3, y: -3)
            }
        }
    }
}
#endif
