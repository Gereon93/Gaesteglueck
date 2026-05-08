#if canImport(SwiftUI)
import SwiftUI

/// Button-Stile entsprechend dem Design-Handoff:
/// `.primary` — gefüllt mit Akzent-Farbe (CTA)
/// `.secondary` — weißer Hintergrund mit dezentem Border
/// `.ghost` — nur Text, transparent
/// `.soft` — Akzent-Tint Hintergrund mit Akzent-Text
/// `.sage` — Sage-grün gefüllt (für Bestätigungen)
enum WarmButtonKind {
    case primary, secondary, ghost, soft, sage
}

enum WarmButtonSize {
    case sm, md, lg

    var verticalPadding: CGFloat {
        switch self {
        case .sm: 4
        case .md: 7
        case .lg: 10
        }
    }
    var horizontalPadding: CGFloat {
        switch self {
        case .sm: 10
        case .md: 13
        case .lg: 16
        }
    }
    var fontSize: CGFloat {
        switch self {
        case .sm: 12
        case .md: 13
        case .lg: 14
        }
    }
}

struct WarmButtonStyle: ButtonStyle {
    var kind: WarmButtonKind = .secondary
    var size: WarmButtonSize = .md

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size.fontSize, weight: .medium, design: .rounded))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.vertical, size.verticalPadding)
            .padding(.horizontal, size.horizontalPadding)
            .background(background(pressed: configuration.isPressed))
            .foregroundStyle(foreground)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(Tokens.Colors.line2, lineWidth: 1)
                }
            }
            .shadow(
                color: kind == .primary ? Tokens.Colors.accent.opacity(0.3) : .clear,
                radius: 1,
                x: 0,
                y: 1
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary, .sage: return .white
        case .secondary: return Tokens.Colors.ink
        case .ghost: return Tokens.Colors.ink2
        case .soft: return Tokens.Colors.accentHover
        }
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary: return pressed ? Tokens.Colors.accentHover : Tokens.Colors.accent
        case .secondary: return Tokens.Colors.surface
        case .ghost: return .clear
        case .soft: return Tokens.Colors.accentSoft
        case .sage: return Tokens.Colors.sage
        }
    }
}

extension View {
    func warmButton(_ kind: WarmButtonKind = .secondary, size: WarmButtonSize = .md) -> some View {
        buttonStyle(WarmButtonStyle(kind: kind, size: size))
    }
}
#endif
