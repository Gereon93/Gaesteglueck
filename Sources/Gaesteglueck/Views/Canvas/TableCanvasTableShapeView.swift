#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Reine Tischform (Kreis/Rechteck/Quadrat) inklusive Füllung, Rahmen und
/// Schatten. Zustandslos — alle Eingaben kommen als Properties.
struct TableCanvasTableShapeView: View {
    @Bindable var table: GuestTable
    let isSelected: Bool
    @Environment(\.canvasScale) private var canvasScale

    private var hasPinnedGuest: Bool {
        table.guests.contains(where: { $0.isPinned })
    }

    private var scaledDiameter: CGFloat { max(table.diameter * canvasScale, 40) }
    private var scaledWidth: CGFloat { max(table.width * canvasScale, 40) }
    private var scaledDepth: CGFloat { max(table.depth * canvasScale, 28) }

    private var fillColor: Color {
        if table.isBridalTable { return Tokens.Colors.accentTint }
        if hasPinnedGuest { return Tokens.Colors.accentTint }
        return Tokens.Colors.surface
    }

    private var borderColor: Color {
        if isSelected { return Tokens.Colors.accent }
        return Tokens.Colors.line2
    }

    private var borderWidth: CGFloat { isSelected ? 2 : 1.5 }

    var body: some View {
        switch table.shape {
        case .round:
            ZStack {
                Circle().fill(fillColor)
                Circle().strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .frame(width: scaledDiameter, height: scaledDiameter)
            .shadow(
                color: isSelected ? Tokens.Colors.accent.opacity(0.2) : Color.black.opacity(0.06),
                radius: isSelected ? 16 : 6,
                x: 0,
                y: isSelected ? 4 : 2
            )
        case .rectangular:
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fillColor)
                RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .frame(width: scaledWidth, height: scaledDepth)
            .shadow(
                color: isSelected ? Tokens.Colors.accent.opacity(0.2) : Color.black.opacity(0.06),
                radius: isSelected ? 16 : 6,
                x: 0,
                y: isSelected ? 4 : 2
            )
        case .square:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(fillColor)
                RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(borderColor, lineWidth: borderWidth)
            }
            .frame(width: scaledWidth, height: scaledWidth)
            .shadow(
                color: isSelected ? Tokens.Colors.accent.opacity(0.2) : Color.black.opacity(0.06),
                radius: isSelected ? 16 : 6,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
    }
}
#endif
