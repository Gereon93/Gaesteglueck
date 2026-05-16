#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

/// Nicht-interaktive Render-View des Sitzplans für den Bild-Export. Nutzt
/// EXAKT dieselben Bausteine wie der Canvas (SeatLayout-Positionen,
/// SeatChipView, dieselbe Namens-Logik) — kein zweiter Renderer mehr.
/// Wird via `ImageRenderer` zu PNG gerendert. Auf die Tisch-Bounding-Box
/// zugeschnitten, daher keine Riesen-Leerfläche wie beim alten Exporter.
struct SeatingPlanRenderView: View {
    let tables: [GuestTable]
    let displayNames: [UUID: String]
    let rules: SeatingRules
    let scale: CGFloat
    var labels: [CanvasLabel] = []
    #if canImport(AppKit)
    var background: NSImage? = nil
    #endif

    private let labelPad: CGFloat = 140

    private func half(_ table: GuestTable) -> CGSize {
        switch table.shape {
        case .round:
            let r = CGFloat(table.diameter) * scale / 2
            return CGSize(width: r, height: r)
        case .rectangular:
            return CGSize(width: CGFloat(table.width) * scale / 2,
                          height: CGFloat(table.depth) * scale / 2)
        case .square:
            let s = CGFloat(table.width) * scale / 2
            return CGSize(width: s, height: s)
        }
    }

    private var bounds: CGRect {
        guard !tables.isEmpty else { return CGRect(x: 0, y: 0, width: 100, height: 100) }
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for t in tables {
            let h = half(t)
            let reach = max(h.width, h.height) + labelPad
            minX = min(minX, CGFloat(t.positionX) - reach)
            maxX = max(maxX, CGFloat(t.positionX) + reach)
            minY = min(minY, CGFloat(t.positionY) - reach)
            maxY = max(maxY, CGFloat(t.positionY) + reach)
        }
        for l in labels {
            minX = min(minX, CGFloat(l.positionX) - 80)
            maxX = max(maxX, CGFloat(l.positionX) + 80)
            minY = min(minY, CGFloat(l.positionY) - 24)
            maxY = max(maxY, CGFloat(l.positionY) + 24)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    var body: some View {
        let b = bounds
        ZStack(alignment: .topLeading) {
            Tokens.Colors.bg
            #if canImport(AppKit)
            if let background {
                Image(nsImage: background)
                    .resizable()
                    .scaledToFill()
                    .frame(width: b.width, height: b.height)
                    .clipped()
                    .opacity(0.9)
            }
            #endif
            ForEach(labels) { label in
                Text(label.text)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .tracking(0.5)
                    .rotationEffect(.degrees(label.rotation))
                    .position(
                        x: CGFloat(label.positionX) - b.minX,
                        y: CGFloat(label.positionY) - b.minY
                    )
            }
            ForEach(tables) { table in
                tableView(table)
                    .position(
                        x: CGFloat(table.positionX) - b.minX,
                        y: CGFloat(table.positionY) - b.minY
                    )
            }
        }
        .frame(width: b.width, height: b.height)
        .environment(\.canvasScale, scale)
    }

    @ViewBuilder
    private func tableView(_ table: GuestTable) -> some View {
        let cap = table.capacity(rules: rules)
        let sw = max(CGFloat(table.width) * scale, 40)
        let sd = max(CGFloat(table.depth) * scale, 28)
        let sdia = max(CGFloat(table.diameter) * scale, 40)
        let positions = SeatLayout.positions(
            shape: table.shape,
            capacity: cap,
            scaledDiameter: sdia,
            scaledWidth: sw,
            scaledDepth: sd
        )

        ZStack {
            tableShape(table, sw: sw, sd: sd, sdia: sdia)

            VStack(spacing: 2) {
                Text(table.name)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                Text("\(table.guests.count)/\(cap)")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
            .rotationEffect(.degrees(-table.rotation))

            ForEach(0..<positions.count, id: \.self) { idx in
                let occ = table.guests.first { $0.seatIndex == idx }
                StaticSeatView(
                    occupant: occ,
                    isDisabled: table.disabledSeatIndices.contains(idx),
                    counterRotation: -table.rotation,
                    resolvedNameSide: resolvedSide(
                        table: table,
                        localX: positions[idx].x, localY: positions[idx].y,
                        sw: sw, sd: sd, sdia: sdia
                    ),
                    displayName: occ.flatMap { displayNames[$0.id] }
                )
                .offset(x: positions[idx].x, y: positions[idx].y)
            }
        }
        .rotationEffect(.degrees(table.rotation))
    }

    @ViewBuilder
    private func tableShape(_ table: GuestTable, sw: CGFloat, sd: CGFloat, sdia: CGFloat) -> some View {
        let fill = table.isBridalTable ? Tokens.Colors.accentTint : Tokens.Colors.surface
        switch table.shape {
        case .round:
            ZStack {
                Circle().fill(fill)
                Circle().strokeBorder(Tokens.Colors.line2, lineWidth: 1.5)
            }
            .frame(width: sdia, height: sdia)
        case .rectangular:
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(fill)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Tokens.Colors.line2, lineWidth: 1.5)
            }
            .frame(width: sw, height: sd)
        case .square:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(fill)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Tokens.Colors.line2, lineWidth: 1.5)
            }
            .frame(width: sw, height: sw)
        }
    }

    private func resolvedSide(
        table: GuestTable, localX: CGFloat, localY: CGFloat,
        sw: CGFloat, sd: CGFloat, sdia: CGFloat
    ) -> SeatNameSide {
        if table.seatNameSide != .auto { return table.seatNameSide }
        let halfW = (table.shape == .round ? sdia : sw) / 2
        let halfD = (table.shape == .round ? sdia : sd) / 2
        let nx = localX / max(halfW, 1)
        let ny = localY / max(halfD, 1)
        if abs(ny) >= abs(nx) {
            return ny < 0 ? .top : .bottom
        } else {
            return nx < 0 ? .left : .right
        }
    }
}

/// Rein visuelle Sitz-Darstellung — KEINE Drag/Drop/Hover/Kontextmenü.
/// Wichtig: `ImageRenderer` kann AppKit-Interop (`.dropDestination` etc.,
/// = `DraggingDestinationView`) NICHT flatten → würde das PNG zerstören.
/// Darum hier ein eigenständiger statischer View statt `SeatChipView`.
private struct StaticSeatView: View {
    let occupant: Guest?
    let isDisabled: Bool
    let counterRotation: Double
    let resolvedNameSide: SeatNameSide
    let displayName: String?

    private var initials: String {
        guard let g = occupant else { return "" }
        return (g.firstName.prefix(1) + g.lastName.prefix(1)).uppercased()
    }

    private var fillColor: Color {
        if isDisabled { return Tokens.Colors.surface.opacity(0.4) }
        return occupant == nil ? Tokens.Colors.surface : Tokens.Colors.accentTint
    }

    private var strokeColor: Color {
        occupant == nil ? Tokens.Colors.line2 : Tokens.Colors.accent.opacity(0.7)
    }

    private var dietColor: Color? {
        guard let g = occupant else { return nil }
        if g.hasIntolerances { return Tokens.Colors.error }
        switch g.dietaryChoice.lowercased() {
        case "vegan": return Color(hex: "#5a8a4a")
        case "vegetarisch": return Tokens.Colors.sage
        default: return nil
        }
    }

    private var nameDistance: CGFloat {
        switch resolvedNameSide {
        case .left, .right: 30
        default: 24
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(fillColor)
            Circle().strokeBorder(strokeColor, lineWidth: occupant == nil ? 1 : 1.5)
            if isDisabled {
                Path { p in
                    p.move(to: CGPoint(x: 4, y: 18))
                    p.addLine(to: CGPoint(x: 18, y: 4))
                }
                .stroke(Tokens.Colors.ink3, lineWidth: 1.5)
            }
            if !initials.isEmpty {
                Text(initials)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .monospacedDigit()
                    .rotationEffect(.degrees(counterRotation))
            }
            if let color = dietColor {
                Circle().fill(color).frame(width: 6, height: 6).offset(x: 7, y: -7)
            }
        }
        .frame(width: 22, height: 22)
        .overlay {
            if let g = occupant {
                let v = resolvedNameSide.localUnitVector
                Text(displayName ?? g.fullName)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(counterRotation))
                    .offset(x: v.dx * nameDistance, y: v.dy * nameDistance)
            }
        }
    }
}
#endif
