#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

// MARK: - Setup Table Shape

struct SetupTableShape: View {
    let table: GuestTable

    var body: some View {
        VStack(spacing: 2) {
            shape
            Text(table.name)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
                .lineLimit(1)
            Text("\(table.capacity) Pl.")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var shape: some View {
        switch table.shape {
        case .round:
            ZStack {
                Circle().fill(Tokens.Colors.surface)
                Circle().strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1.5)
            }
            .frame(width: 86, height: 86)
            .cardShadow()
        case .rectangular:
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Tokens.Colors.surface)
                RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1.5)
            }
            .frame(width: 180, height: 56)
            .cardShadow()
        case .square:
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Tokens.Colors.surface)
                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Tokens.Colors.sageSoft, lineWidth: 1.5)
            }
            .frame(width: 70, height: 70)
            .cardShadow()
        }
    }
}
#endif
