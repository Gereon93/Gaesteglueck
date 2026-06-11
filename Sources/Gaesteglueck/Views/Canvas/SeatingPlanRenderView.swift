#if os(macOS)
#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

/// Nicht-interaktive Render-View des Sitzplans für den Bild-Export. Spiegelt
/// die Optik des Live-Canvas (Diät-Farbe am Chip, Alters-Badge, Allergen-
/// Nummern, Kreis-Inhalt, Namen-Positionierung) — nur ohne Drag/Drop, weil
/// `ImageRenderer` AppKit-Interop nicht flatten kann. Übernimmt die Anzeige-
/// Toggles, damit das PNG zeigt was im Canvas eingestellt ist.
struct SeatingPlanRenderView: View {
    let tables: [GuestTable]
    let displayNames: [UUID: String]
    let rules: SeatingRules
    let scale: CGFloat
    var labels: [CanvasLabel] = []
    #if canImport(AppKit)
    var background: NSImage? = nil
    #endif

    // Anzeige-Optionen (aus den Live-Toggles übernommen).
    var showSeatNames: Bool = true
    var infoDisplay: SeatInfoDisplay = .none
    var showAgeMarkers: Bool = false
    var chipContent: SeatChipContent = .initials
    var showTableWarnings: Bool = true
    var showRoomLabels: Bool = true
    var showLegend: Bool = true
    var legend: SeatingLegend = SeatingLegend(guests: [])
    var nameFontSize: CGFloat = 9
    var showCoupleMarker: Bool = false
    /// Event-Partner-Namen für die Brautpaar-Erkennung im Export.
    var coupleNames: [String] = []

    private let labelPad: CGFloat = 140

    private var hasBridalTable: Bool { tables.contains(where: \.isBridalTable) }

    private func isCouple(_ g: Guest?) -> Bool {
        guard let g else { return false }
        return coupleNames.contains { TableCanvasItemView.matchesPartner(g, $0) }
    }

    /// Dynamische Reserve-Höhe für den Legenden-Block, damit er bei vielen
    /// Allergenen/Altersgruppen nicht in die Tische ragt. Konservativ mit
    /// 2 Spalten gerechnet (Legende ist max. 300pt breit).
    private var legendReserve: CGFloat {
        var h: CGFloat = 32 + 18 // Padding + Titel
        let showsIntol = (infoDisplay.showsIntolerance || chipContent.showsIntolerance) && !legend.isEmpty
        let showsAge = (showAgeMarkers || chipContent.showsAge) && legend.hasAgeMarkers
        if infoDisplay.showsDiet { h += 24 }
        if showsIntol {
            h += 16 + CGFloat((legend.entries.count + 1) / 2) * 18
        }
        if showsAge {
            h += 16 + CGFloat((legend.ageCategories.count + 1) / 2) * 18
        }
        if hasBridalTable || (showTableWarnings && !legend.isEmpty) {
            h += 16 + (hasBridalTable ? 18 : 0) + ((showTableWarnings && !legend.isEmpty) ? 22 : 0)
        }
        return h + 24 // Sicherheits-Puffer + Außenabstand
    }

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
        if showRoomLabels {
            for l in labels {
                minX = min(minX, CGFloat(l.positionX) - 80)
                maxX = max(maxX, CGFloat(l.positionX) + 80)
                minY = min(minY, CGFloat(l.positionY) - 24)
                maxY = max(maxY, CGFloat(l.positionY) + 24)
            }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private var legendVisible: Bool {
        showLegend && (infoDisplay != .none
            || ((showAgeMarkers || chipContent.showsAge) && legend.hasAgeMarkers)
            || (chipContent.showsIntolerance && !legend.isEmpty)
            || hasBridalTable
            || showCoupleMarker
            || (showTableWarnings && !legend.isEmpty))
    }

    var body: some View {
        let b = bounds
        let extra = legendVisible ? legendReserve : 0
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
            if showRoomLabels {
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
            }
            ForEach(tables) { table in
                tableView(table)
                    .position(
                        x: CGFloat(table.positionX) - b.minX,
                        y: CGFloat(table.positionY) - b.minY
                    )
            }
        }
        .frame(width: b.width, height: b.height + extra, alignment: .topLeading)
        .overlay(alignment: .bottomLeading) {
            if legendVisible {
                SeatingLegendView(
                    legend: legend,
                    infoDisplay: infoDisplay,
                    showAge: showAgeMarkers,
                    hasBridalTable: hasBridalTable,
                    showTableWarnings: showTableWarnings,
                    showCoupleMarker: showCoupleMarker,
                    chipContent: chipContent
                )
                .padding(16)
            }
        }
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
                HStack(spacing: 4) {
                    Text("\(table.attendingGuests.count)/\(cap)")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                    if showTableWarnings {
                        let allergic = table.attendingGuests.filter(\.hasIntolerances).count
                        if allergic > 0 {
                            HStack(spacing: 1) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 7, weight: .bold))
                                Text("\(allergic)")
                                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Tokens.Colors.error))
                        }
                    }
                }
            }
            .rotationEffect(.degrees(-table.rotation))

            ForEach(0..<positions.count, id: \.self) { idx in
                let occ = table.attendingGuests.first { $0.seatIndex == idx }
                StaticSeatView(
                    occupant: occ,
                    isDisabled: table.disabledSeatIndices.contains(idx),
                    counterRotation: -table.rotation,
                    showName: showSeatNames,
                    resolvedNameSide: resolvedSide(
                        table: table,
                        localX: positions[idx].x, localY: positions[idx].y,
                        sw: sw, sd: sd, sdia: sdia
                    ),
                    displayName: occ.flatMap { displayNames[$0.id] },
                    infoDisplay: infoDisplay,
                    intoleranceNumbers: occ.map { legend.numbers(for: $0) } ?? [],
                    showAgeMarker: showAgeMarkers,
                    chipContent: chipContent,
                    nameFontSize: nameFontSize,
                    isCouple: isCouple(occ),
                    showCoupleMarker: showCoupleMarker
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

/// Rein visuelle Sitz-Darstellung — KEINE Drag/Drop/Hover/Kontextmenü (würde
/// `ImageRenderer` zerstören). Spiegelt sonst `SeatChipView`: Diät-Farbe am
/// Chip, Kreis-Inhalt (Initialen/Allergen-Nr/Alters-Icon), Eck-Badges,
/// deterministische Namen-Positionierung via `SeatChipView.nameOffset`.
private struct StaticSeatView: View {
    let occupant: Guest?
    let isDisabled: Bool
    var counterRotation: Double = 0
    var showName: Bool = false
    var resolvedNameSide: SeatNameSide = .top
    var displayName: String? = nil
    var infoDisplay: SeatInfoDisplay = .none
    var intoleranceNumbers: [Int] = []
    var showAgeMarker: Bool = false
    var chipContent: SeatChipContent = .initials
    var nameFontSize: CGFloat = 9
    var isCouple: Bool = false
    var showCoupleMarker: Bool = false

    private var initials: String {
        guard let g = occupant else { return "" }
        return (g.firstName.prefix(1) + g.lastName.prefix(1)).uppercased()
    }

    private var dietBadgeColor: Color? {
        guard let g = occupant else { return nil }
        switch g.dietaryChoice.lowercased() {
        case "vegan": return Tokens.Colors.dietVegan
        case "vegetarisch": return Tokens.Colors.dietVegetarian
        default: return nil
        }
    }

    private var hasIntolerance: Bool { occupant?.hasIntolerances ?? false }

    private var fillColor: Color {
        if isDisabled { return Tokens.Colors.surface.opacity(0.4) }
        if occupant == nil { return Tokens.Colors.surface }
        if infoDisplay.showsDiet, let d = dietBadgeColor { return d.opacity(0.20) }
        return Tokens.Colors.accentTint
    }

    private var strokeColor: Color {
        if occupant == nil { return Tokens.Colors.line2 }
        if infoDisplay.showsDiet, let d = dietBadgeColor { return d }
        return Tokens.Colors.accent.opacity(0.7)
    }

    private var intoleranceText: String {
        intoleranceNumbers.isEmpty ? "⚠" : intoleranceNumbers.map(String.init).joined(separator: ",")
    }

    /// Aufgelöster Kreis-Inhalt — nur drei konkrete Fälle, vermeidet toten
    /// Code im Render-Switch. Identisch zu SeatChipView.ResolvedCenter.
    private enum ResolvedCenter { case initials, intolerance, age }

    private var effectiveCenter: ResolvedCenter {
        guard occupant != nil else { return .initials }
        let isYoung = occupant?.ageCategory.isMarkedAge ?? false
        switch chipContent {
        case .intolerance: return intoleranceNumbers.isEmpty ? .initials : .intolerance
        case .age: return isYoung ? .age : .initials
        case .initials: return .initials
        case .ageAndIntolerance:
            if !intoleranceNumbers.isEmpty { return .intolerance }
            return isYoung ? .age : .initials
        }
    }

    /// Namens-Größe deterministisch via NSString messen (ImageRenderer-sicher;
    /// GeometryReader/Preference würde im Single-Pass evtl. nicht einrasten).
    private var nameSize: CGSize {
        #if canImport(AppKit)
        let name = displayName ?? occupant?.fullName ?? ""
        let font = NSFont.systemFont(ofSize: nameFontSize, weight: .semibold)
        return (name as NSString).size(withAttributes: [.font: font])
        #else
        return .zero
        #endif
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
            centerContentView
            if infoDisplay.showsIntolerance, hasIntolerance, effectiveCenter != .intolerance {
                Text(intoleranceText)
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, intoleranceText.count > 1 ? 3 : 0)
                    .frame(minWidth: 10, minHeight: 10)
                    .background(Capsule().fill(Tokens.Colors.error))
                    .overlay(Capsule().strokeBorder(.white, lineWidth: 0.75))
                    .fixedSize()
                    .rotationEffect(.degrees(counterRotation))
                    .offset(x: 7, y: -7)
            }
            if showAgeMarker, let age = occupant?.ageCategory, age.isMarkedAge,
               effectiveCenter != .age {
                ZStack {
                    Circle().fill(Tokens.Colors.tagActivity)
                    Image(systemName: age.iconName)
                        .font(.system(size: 5.5, weight: .bold))
                        .foregroundStyle(.white)
                }
                .overlay(Circle().strokeBorder(.white, lineWidth: 0.75))
                .frame(width: 10, height: 10)
                .rotationEffect(.degrees(counterRotation))
                .offset(x: -7, y: 7)
            }
        }
        .frame(width: SeatChipView.chipSize, height: SeatChipView.chipSize)
        .overlay {
            if showName, let g = occupant {
                Text(displayName ?? g.fullName)
                    .font(.system(size: nameFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(1)
                    .fixedSize()
                    .rotationEffect(.degrees(counterRotation))
                    .offset(SeatChipView.nameOffset(
                        side: resolvedNameSide,
                        tableRotationDegrees: -counterRotation,
                        nameSize: nameSize,
                        chipSize: SeatChipView.chipSize,
                        gap: SeatChipView.nameGap
                    ))
            }
        }
    }

    /// Brautpaar-Glyph nach Geschlecht: 👰 Braut, 🤵 Bräutigam, sonst 👑.
    private var coupleGlyph: String {
        switch occupant?.gender {
        case .female: return "👰"
        case .male: return "🤵"
        default: return "👑"
        }
    }

    @ViewBuilder
    private var centerContentView: some View {
        if showCoupleMarker, isCouple {
            Text(coupleGlyph)
                .font(.system(size: 12))
                .rotationEffect(.degrees(counterRotation))
        } else {
            switch effectiveCenter {
            case .initials:
                if !initials.isEmpty {
                    Text(initials)
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                        .monospacedDigit()
                        .rotationEffect(.degrees(counterRotation))
                }
            case .intolerance:
                Text(intoleranceText)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Colors.error)
                    .rotationEffect(.degrees(counterRotation))
            case .age:
                if let age = occupant?.ageCategory {
                    Image(systemName: age.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Tokens.Colors.tagActivity)
                        .rotationEffect(.degrees(counterRotation))
                }
            }
        }
    }
}
#endif
#endif
