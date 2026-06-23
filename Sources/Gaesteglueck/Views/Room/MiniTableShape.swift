#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Kleines Form-Icon für Bibliothek und Inventar.
struct MiniTableShape: View {
    let shape: TableShape

    var body: some View {
        switch shape {
        case .round:
            Circle()
                .fill(Tokens.Colors.accentTint)
                .overlay(Circle().strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1.5))
                .frame(width: 26, height: 26)
        case .square:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Tokens.Colors.sageTint)
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Tokens.Colors.sageSoft, lineWidth: 1.5))
                .frame(width: 26, height: 26)
        case .rectangular:
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(hex: "#f5ede0"))
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Color(hex: "#ecdfc7"), lineWidth: 1.5))
                .frame(width: 32, height: 18)
        }
    }
}
#endif
