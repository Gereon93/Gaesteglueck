#if canImport(SwiftUI)
import SwiftUI

/// Zentrale Design-Tokens für Gästeglück. Mappt 1:1 auf das
/// `tokens.css` aus dem Design-Handoff. Statt `var(--accent)` schreiben
/// wir `Tokens.Colors.accent`. Display-Schrift ist New York (Apple Serif),
/// UI-Schrift ist SF Pro Rounded — beide System-Fallbacks für DM Serif
/// Display + Inter Tight aus dem Design-Brief.
enum Tokens {

    // MARK: - Farben

    enum Colors {
        // Surfaces
        static let bg = Color(hex: "#fbf8f5")
        static let bg2 = Color(hex: "#f5f0ea")
        static let bg3 = Color(hex: "#efe9e1")
        static let surface = Color.white

        // Text
        static let ink = Color(hex: "#2a2522")
        static let ink2 = Color(hex: "#5b524c")
        static let ink3 = Color(hex: "#8a807a")
        static let ink4 = Color(hex: "#c4bcb5")

        // Akzent (Rose)
        static let accent = Color(hex: "#c8788c")
        static let accentHover = Color(hex: "#b96a7e")
        static let accentSoft = Color(hex: "#f3dfe5")
        static let accentTint = Color(hex: "#fbf2f4")

        // Sage (Sekundär)
        static let sage = Color(hex: "#7a8b6c")
        static let sageSoft = Color(hex: "#e3e8db")
        static let sageTint = Color(hex: "#f3f5ef")

        // States
        static let warn = Color(hex: "#d68a3a")
        static let warnSoft = Color(hex: "#fbe9d3")
        static let error = Color(hex: "#c44a4a")
        static let errorSoft = Color(hex: "#f8dada")
        static let ok = Color(hex: "#7a8b6c")

        // Hairlines
        static let line = Color.black.opacity(0.08)
        static let line2 = Color.black.opacity(0.14)

        // Tag-Kategorien
        static let tagFamily = Color(hex: "#c8788c")
        static let tagFriends = Color(hex: "#7a8b6c")
        static let tagRole = Color(hex: "#b88a5c")
        static let tagActivity = Color(hex: "#6e8aab")
        static let tagWork = Color(hex: "#8e7aae")
        static let tagCustom = Color(hex: "#a08778")
    }

    // MARK: - Schrift

    enum Typography {
        // Display = Apple's "New York" (serif). Weight muss über den Font-Namen
        // gesetzt werden (NewYork ist ein Static Font, kein Variable Font) —
        // sonst loggt SwiftUI Warnings und die Schrift fällt auf Fallback.
        enum DisplayWeight {
            case regular, medium, semibold

            var fontName: String {
                switch self {
                case .regular: "NewYork"
                case .medium: "NewYork-Medium"
                case .semibold: "NewYork-Semibold"
                }
            }

            var italicFontName: String {
                switch self {
                case .regular: "NewYork-Italic"
                case .medium: "NewYork-MediumItalic"
                case .semibold: "NewYork-SemiboldItalic"
                }
            }
        }

        static func display(size: CGFloat, italic: Bool = false, weight: DisplayWeight = .regular) -> Font {
            let name = italic ? weight.italicFontName : weight.fontName
            return Font.custom(name, size: size)
        }

        static let displayXL = display(size: 72)
        static let displayL = display(size: 44)        // Welcome-Headline
        static let displayM = display(size: 32)        // Hero-Couple
        static let displayS = display(size: 22)        // Section-Headlines
        static let displayXS = display(size: 18)       // Tisch-Namen

        // UI — SF Pro Rounded (warmer als SF Pro)
        static let bodyL = Font.system(size: 14, weight: .medium, design: .rounded)
        static let bodyM = Font.system(size: 13, weight: .regular, design: .rounded)
        static let bodyS = Font.system(size: 12.5, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 11, weight: .semibold, design: .rounded)
        static let micro = Font.system(size: 10, weight: .medium, design: .rounded)
        static let mono = Font.system(size: 12, design: .monospaced)
    }

    // MARK: - Spacing (8pt-Skala)

    enum Spacing {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s5: CGFloat = 20
        static let s6: CGFloat = 24
        static let s8: CGFloat = 32
        static let s10: CGFloat = 40
        static let s12: CGFloat = 48
    }

    // MARK: - Corner Radius

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 22
    }

    // MARK: - Schatten

    enum Shadow {
        static let card = (color: Color.black.opacity(0.05), radius: 8.0, x: 0.0, y: 2.0)
        static let floating = (color: Color.black.opacity(0.08), radius: 12.0, x: 0.0, y: 4.0)
        static let modal = (color: Color.black.opacity(0.12), radius: 64.0, x: 0.0, y: 24.0)
    }
}

// MARK: - View-Modifier-Convenience

extension View {
    func cardShadow() -> some View {
        shadow(
            color: Tokens.Shadow.card.color,
            radius: Tokens.Shadow.card.radius,
            x: Tokens.Shadow.card.x,
            y: Tokens.Shadow.card.y
        )
    }

    func floatingShadow() -> some View {
        shadow(
            color: Tokens.Shadow.floating.color,
            radius: Tokens.Shadow.floating.radius,
            x: Tokens.Shadow.floating.x,
            y: Tokens.Shadow.floating.y
        )
    }

    func modalShadow() -> some View {
        shadow(
            color: Tokens.Shadow.modal.color,
            radius: Tokens.Shadow.modal.radius,
            x: Tokens.Shadow.modal.x,
            y: Tokens.Shadow.modal.y
        )
    }
}
#endif
