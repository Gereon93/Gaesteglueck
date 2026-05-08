#if canImport(SwiftUI)
import SwiftUI

/// KPI-Karte für das Dashboard. Großer Wert in Display-Schrift, kleines
/// Icon-Quadrat oben links in einer der vier Tinten (rose/sage/sand/sky),
/// Label darunter, optional zweizeiliger Hinweis ganz unten.
struct GGStatCard: View {
    enum Tint {
        case rose, sage, sand, sky

        var background: Color {
            switch self {
            case .rose: Tokens.Colors.accentTint
            case .sage: Tokens.Colors.sageTint
            case .sand: Color(hex: "#f5ede0")
            case .sky:  Color(hex: "#e8eef5")
            }
        }
        var foreground: Color {
            switch self {
            case .rose: Tokens.Colors.accent
            case .sage: Tokens.Colors.sage
            case .sand: Color(hex: "#b88a5c")
            case .sky:  Color(hex: "#6e8aab")
            }
        }
    }

    let icon: String
    let label: String
    let value: String
    var hint: String? = nil
    var tint: Tint = .rose

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.background)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(tint.foreground)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(value)
                    .font(Tokens.Typography.display(size: 32, weight: .medium))
                    .tracking(-0.5)
                    .foregroundStyle(Tokens.Colors.ink)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
            if let hint, !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -8)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colors.surface)
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Colors.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .cardShadow()
    }
}
#endif
