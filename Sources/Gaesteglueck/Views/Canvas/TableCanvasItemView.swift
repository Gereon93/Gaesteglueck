#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TableCanvasItemView: View {
    @Bindable var table: GuestTable
    let isSelected: Bool
    let onTap: () -> Void
    @Query private var allTables: [GuestTable]
    @Query private var allGuests: [Guest]
    @Query private var allConstraints: [Constraint]
    @Query private var events: [Event]
    @Environment(\.canvasScale) private var canvasScale
    @Environment(\.seatDisplayNames) private var seatDisplayNames
    @Environment(\.seatingLegend) private var seatingLegend

    @State private var dragOffset: CGSize = .zero
    @State private var showingCombineSheet = false
    @State private var showingEditSheet = false
    @AppStorage("canvasShowSeatNames") private var showSeatNames = false
    @AppStorage("canvasSeatInfoMode") private var seatInfoModeRaw: String =
        SeatInfoDisplay.none.rawValue
    @AppStorage("canvasShowAgeMarkers") private var showAgeMarkers = false
    @AppStorage("canvasShowTableWarnings") private var showTableWarnings = true
    @AppStorage("canvasSeatChipContent") private var seatChipContentRaw = SeatChipContent.initials.rawValue
    @AppStorage("canvasSeatNameSize") private var seatNameSize: Double = 9
    @AppStorage("canvasShowCoupleMarker") private var showCoupleMarker = false

    private var seatChipContent: SeatChipContent {
        SeatChipContent(rawValue: seatChipContentRaw) ?? .initials
    }

    /// Brautpaar = Gast, dessen Name dem Event-Partner-Namen entspricht.
    private func isCouple(_ g: Guest?) -> Bool {
        guard let g, let e = event else { return false }
        return Self.matchesPartner(g, e.partner1Name) || Self.matchesPartner(g, e.partner2Name)
    }

    static func matchesPartner(_ g: Guest, _ name: String) -> Bool {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return false }
        return g.fullName.localizedCaseInsensitiveCompare(n) == .orderedSame
            || g.firstName.localizedCaseInsensitiveCompare(n) == .orderedSame
    }

    private var seatInfoMode: SeatInfoDisplay {
        SeatInfoDisplay(rawValue: seatInfoModeRaw) ?? .none
    }

    /// Aktuelle Sitzregeln aus dem Event ziehen — nicht aus dem statischen
    /// `GuestTable.activeRules`. Das Static wird erst in onAppear synced,
    /// daher braucht der initiale Render eine direkte Quelle.
    private var currentRules: SeatingRules { events.first?.seatingRules ?? .default }

    private var currentCapacity: Int { table.capacity(rules: currentRules) }

    private var seatPositions: [CGPoint] {
        SeatLayout.positions(
            shape: table.shape,
            capacity: currentCapacity,
            scaledDiameter: scaledDiameter,
            scaledWidth: scaledWidth,
            scaledDepth: scaledDepth
        )
    }

    private var event: Event? { events.first }

    private var groupTables: [GuestTable] {
        guard let groupID = table.combinationGroup else { return [] }
        return allTables.filter { $0.combinationGroup == groupID }
    }

    private var isTafelOwner: Bool {
        table.combinationGroup != nil && (table.combinationOrder ?? 0) == 0
    }

    private var isTafelFollower: Bool {
        table.combinationGroup != nil && (table.combinationOrder ?? 0) > 0
    }

    private var tafelGeometry: TafelLayout.TafelGeometry? {
        guard isTafelOwner else { return nil }
        return TafelLayout.geometry(of: groupTables, rules: currentRules)
    }

    private func occupant(at seatIndex: Int) -> Guest? {
        table.guests.first { $0.seatIndex == seatIndex }
    }

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

    private var allergyCount: Int {
        table.attendingGuests.filter(\.hasIntolerances).count
    }

    var body: some View {
        Group {
            if isTafelFollower {
                tafelFollowerView
            } else {
                soloOrOwnerView
            }
        }
        .position(x: table.positionX + dragOffset.width, y: table.positionY + dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    applyDrag(value.translation)
                }
        )
        .onTapGesture(perform: onTap)
        .contextMenu {
            tafelContextMenu
        }
        .sheet(isPresented: $showingCombineSheet) {
            TableCombineSheet(table: table)
        }
        .sheet(isPresented: $showingEditSheet) {
            TableFormView(table: table)
        }
    }

    @ViewBuilder
    private var tafelFollowerView: some View {
        tableShape
            .dropDestination(for: String.self) { items, _ in
                handleTableDrop(items: items)
            }
            .rotationEffect(.degrees(table.rotation))
    }

    @ViewBuilder
    private var soloOrOwnerView: some View {
        ZStack {
            tableShape
                .dropDestination(for: String.self) { items, _ in
                    handleTableDrop(items: items)
                }
                .overlay(alignment: .topTrailing) { badgeOverlay }
            VStack(spacing: 3) {
                Text(table.name)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(capacityLabel)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(table.isFull ? Tokens.Colors.warn : Tokens.Colors.ink3)
                        .monospacedDigit()
                    allergyBadge
                    lateCancellationBadge
                }
                if table.combinationGroup != nil {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                        .foregroundStyle(Tokens.Colors.accent)
                }
            }
            .padding(.horizontal, 6)
            .rotationEffect(.degrees(-table.rotation))
            seatChipsLayer
        }
        .rotationEffect(.degrees(table.rotation))
    }

    private var capacityLabel: String {
        if let geo = tafelGeometry {
            let occupied = groupTables.reduce(0) { $0 + $1.attendingGuests.filter { $0.seatIndex != nil }.count }
            let validDisabled = groupTables.reduce(0) { sum, t in
                sum + t.disabledSeatIndices.filter { $0 < t.capacity(rules: currentRules) }.count
            }
            return "\(occupied)/\(max(0, geo.capacity - validDisabled))"
        }
        return "\(table.attendingGuests.count)/\(table.effectiveCapacity(rules: currentRules))"
    }

    @ViewBuilder
    private var seatChipsLayer: some View {
        if let geo = tafelGeometry {
            ForEach(Array(geo.seats.enumerated()), id: \.offset) { idx, seat in
                let occ = occupantInGroup(tableID: seat.tableID, seatIndex: seat.localSeatIndex)
                let targetTable = groupTables.first(where: { $0.id == seat.tableID }) ?? table
                let isSeatDisabled = targetTable.disabledSeatIndices.contains(seat.localSeatIndex)
                SeatChipView(
                    seatIndex: idx,
                    occupant: occ,
                    onDrop: { guestID in
                        assignGuestToTafelSeat(guestID: guestID, seat: seat)
                    },
                    onClear: {
                        occ?.seatIndex = nil
                    },
                    isDisabled: isSeatDisabled,
                    onToggleDisabled: {
                        var s = targetTable.disabledSeatIndices
                        if s.contains(seat.localSeatIndex) {
                            s.remove(seat.localSeatIndex)
                        } else {
                            s.insert(seat.localSeatIndex)
                            if let occ { occ.seatIndex = nil }
                        }
                        targetTable.disabledSeatIndices = s
                    },
                    counterRotation: -table.rotation,
                    showName: showSeatNames,
                    resolvedNameSide: resolvedNameSide(
                        localX: seat.position.x - table.positionX,
                        localY: seat.position.y - table.positionY
                    ),
                    displayName: occ.flatMap { seatDisplayNames[$0.id] },
                    infoDisplay: seatInfoMode,
                    intoleranceNumbers: occ.map { seatingLegend.numbers(for: $0) } ?? [],
                    showAgeMarker: showAgeMarkers,
                    chipContent: seatChipContent,
                    nameFontSize: CGFloat(seatNameSize),
                    isCouple: isCouple(occ),
                    showCoupleMarker: showCoupleMarker
                )
                .offset(
                    x: seat.position.x - table.positionX,
                    y: seat.position.y - table.positionY
                )
            }
        } else {
            let positions = seatPositions
            ForEach(0..<positions.count, id: \.self) { idx in
                SeatChipView(
                    seatIndex: idx,
                    occupant: occupant(at: idx),
                    onDrop: { guestID in
                        assignGuestToSeat(guestID: guestID, seatIndex: idx)
                    },
                    onClear: {
                        occupant(at: idx)?.seatIndex = nil
                    },
                    isDisabled: table.disabledSeatIndices.contains(idx),
                    onToggleDisabled: {
                        var s = table.disabledSeatIndices
                        if s.contains(idx) {
                            s.remove(idx)
                        } else {
                            s.insert(idx)
                            if let occ = occupant(at: idx) { occ.seatIndex = nil }
                        }
                        table.disabledSeatIndices = s
                    },
                    counterRotation: -table.rotation,
                    showName: showSeatNames,
                    resolvedNameSide: resolvedNameSide(
                        localX: positions[idx].x, localY: positions[idx].y
                    ),
                    displayName: occupant(at: idx).flatMap { seatDisplayNames[$0.id] },
                    infoDisplay: seatInfoMode,
                    intoleranceNumbers: occupant(at: idx).map { seatingLegend.numbers(for: $0) } ?? [],
                    showAgeMarker: showAgeMarkers,
                    chipContent: seatChipContent,
                    nameFontSize: CGFloat(seatNameSize),
                    isCouple: isCouple(occupant(at: idx)),
                    showCoupleMarker: showCoupleMarker
                )
                .offset(x: positions[idx].x, y: positions[idx].y)
            }
        }
    }

    /// Löst die Namens-Seite für einen Sitz auf. Override am Tisch gewinnt;
    /// `.auto` leitet aus der nächstgelegenen Tischkante ab (normiert auf die
    /// Tisch-Halbmaße, damit Eck-Sitze breiter Tische als Oben/Unten zählen,
    /// nicht fälschlich als Links/Rechts).
    private func resolvedNameSide(localX: CGFloat, localY: CGFloat) -> SeatNameSide {
        if table.seatNameSide != .auto { return table.seatNameSide }
        let halfW = (table.shape == .round ? scaledDiameter : scaledWidth) / 2
        let halfD = (table.shape == .round ? scaledDiameter : scaledDepth) / 2
        let nx = localX / max(halfW, 1)
        let ny = localY / max(halfD, 1)
        if abs(ny) >= abs(nx) {
            return ny < 0 ? .top : .bottom
        } else {
            return nx < 0 ? .left : .right
        }
    }

    private func occupantInGroup(tableID: UUID, seatIndex: Int) -> Guest? {
        guard let target = groupTables.first(where: { $0.id == tableID }) else { return nil }
        return target.guests.first { $0.seatIndex == seatIndex }
    }

    @discardableResult
    private func assignGuestToTafelSeat(guestID: UUID, seat: TafelLayout.Seat) -> Bool {
        guard let guest = allGuests.first(where: { $0.id == guestID }) else { return false }
        if guest.isPinned { return false }
        guard let target = allTables.first(where: { $0.id == seat.tableID }) else { return false }
        return placeGuestWithCompanions(guest: guest, on: target, primarySeatIndex: seat.localSeatIndex)
    }

    /// Drop irgendwo auf das Tisch-Rechteck/Form (nicht auf einen konkreten
    /// Sitzchip): Gast bekommt diesen Tisch und den nächsten freien Sitz.
    /// Begleiter (Anmeldegruppe + mustSitTogether-Constraint-Partner)
    /// werden mitgenommen, sofern noch Plätze frei sind.
    private func handleTableDrop(items: [String]) -> Bool {
        guard let raw = items.first, let guestID = UUID(uuidString: raw),
              let guest = allGuests.first(where: { $0.id == guestID }),
              !guest.isPinned else { return false }
        return placeGuestWithCompanions(guest: guest, on: table, primarySeatIndex: nil)
    }

    /// Findet alle Begleiter eines Gastes: identische Anmeldegruppe oder
    /// gemeinsamer mustSitTogether-Constraint. Filtert isPinned.
    private func companions(of guest: Guest) -> [Guest] {
        var companionIDs = Set<UUID>()

        if let group = guest.registrationGroup {
            for g in allGuests where g.id != guest.id && g.registrationGroup == group {
                companionIDs.insert(g.id)
            }
        }

        for c in allConstraints where c.type == .mustSitTogether && c.guestIDs.contains(guest.id) {
            for id in c.guestIDs where id != guest.id {
                companionIDs.insert(id)
            }
        }

        return allGuests.filter { companionIDs.contains($0.id) && !$0.isPinned }
    }

    /// Platziert einen Gast (plus Begleiter) auf dem Tisch. Wenn `primarySeatIndex`
    /// gesetzt: der Gast nimmt diesen konkreten Sitz; Begleiter werden räumlich
    /// nächst-möglich daneben platziert. Sonst bekommt der primäre Gast den
    /// ersten freien Sitz, Begleiter folgen räumlich daneben.
    @discardableResult
    private func placeGuestWithCompanions(
        guest: Guest,
        on target: GuestTable,
        primarySeatIndex: Int?
    ) -> Bool {
        let peerList = companions(of: guest)
        let toPlace = [guest] + peerList.filter { $0.table?.id != target.id }
        let cap = target.capacity(rules: currentRules)
        let disabled = target.disabledSeatIndices.filter { $0 < cap }

        var used: Set<Int> = Set(target.guests.compactMap { g in
            toPlace.contains(where: { $0.id == g.id }) ? nil : g.seatIndex
        })

        let positions = SeatLayout.positions(
            shape: target.shape,
            capacity: cap,
            scaledDiameter: CGFloat(target.diameter),
            scaledWidth: CGFloat(target.width),
            scaledDepth: CGFloat(target.depth)
        )

        func position(of idx: Int) -> CGPoint? {
            guard idx >= 0 && idx < positions.count else { return nil }
            return positions[idx]
        }

        func nearestFree(to anchor: CGPoint?) -> Int? {
            let candidates = (0..<cap).filter { !used.contains($0) && !disabled.contains($0) }
            guard !candidates.isEmpty else { return nil }
            guard let anchor = anchor else { return candidates.first }
            return candidates.min { a, b in
                let pa = position(of: a) ?? .zero
                let pb = position(of: b) ?? .zero
                let dxA = pa.x - anchor.x, dyA = pa.y - anchor.y
                let dxB = pb.x - anchor.x, dyB = pb.y - anchor.y
                return (dxA*dxA + dyA*dyA) < (dxB*dxB + dyB*dyB)
            }
        }

        var anchor: CGPoint?

        if let primary = primarySeatIndex, !disabled.contains(primary) {
            if let prior = target.guests.first(where: { $0.seatIndex == primary && $0.id != guest.id }) {
                prior.seatIndex = guest.table?.id == target.id ? guest.seatIndex : nil
            }
            guest.table = target
            guest.seatIndex = primary
            used.insert(primary)
            anchor = position(of: primary)
        } else if primarySeatIndex != nil {
            // Drop landete auf einem gesperrten Sitz — Fallback auf nächsten freien.
            guard let first = nearestFree(to: nil) else { return false }
            guest.table = target
            guest.seatIndex = first
            used.insert(first)
            anchor = position(of: first)
        } else {
            guard let first = nearestFree(to: nil) else { return false }
            guest.table = target
            guest.seatIndex = first
            used.insert(first)
            anchor = position(of: first)
        }

        for peer in toPlace where peer.id != guest.id {
            guard let chosen = nearestFree(to: anchor) else {
                return true
            }
            peer.table = target
            peer.seatIndex = chosen
            used.insert(chosen)
            // Anker bleibt am Primärgast — alle Begleiter clustern sich um ihn
        }
        return true
    }

    /// Drop auf konkreten Sitz: Gast bekommt diesen Tisch + diesen Sitz-Index.
    /// Begleiter (Anmeldegruppe + mustSitTogether) werden auf andere freie
    /// Sitze des Tisches mitgenommen. Falls Sitz besetzt: Vorbesetzer wird
    /// auf den vorherigen Slot des Gastes verschoben (Swap).
    @discardableResult
    private func assignGuestToSeat(guestID: UUID, seatIndex: Int) -> Bool {
        guard let guest = allGuests.first(where: { $0.id == guestID }) else { return false }
        if guest.isPinned { return false }
        return placeGuestWithCompanions(guest: guest, on: table, primarySeatIndex: seatIndex)
    }

    @ViewBuilder
    private var tafelContextMenu: some View {
        Button {
            showingEditSheet = true
        } label: {
            Label("Bearbeiten…", systemImage: "pencil")
        }
        Button {
            rotateBy90()
        } label: {
            Label("Drehen 90°", systemImage: "rotate.right")
        }
        Menu {
            ForEach(SeatNameSide.allCases) { side in
                Button {
                    table.seatNameSide = side
                } label: {
                    Label(side.rawValue, systemImage:
                        table.seatNameSide == side ? "checkmark" : side.icon)
                }
            }
        } label: {
            Label("Namen-Position", systemImage: "textformat")
        }
        if !table.guests.filter({ !$0.isPinned }).isEmpty {
            Button(role: .destructive) {
                clearTable()
            } label: {
                Label("Tisch leeren", systemImage: "person.fill.xmark")
            }
        }
        if table.shape == .rectangular && !isTafelFollower {
            Button {
                showingCombineSheet = true
            } label: {
                Label("Tisch verbinden", systemImage: "link")
            }
        }
        if table.combinationGroup != nil {
            Button(role: .destructive) {
                dissolveTafel()
            } label: {
                Label("Verbindung lösen", systemImage: "link.badge.plus")
            }
        }
    }

    private func rotateBy90() {
        let newRot = (table.rotation + 90).truncatingRemainder(dividingBy: 360)
        if table.combinationGroup != nil {
            let geo = TafelLayout.geometry(of: groupTables, rules: event?.seatingRules ?? .default)
            let cx = Double(geo.center.x)
            let cy = Double(geo.center.y)
            let cosD = cos(Double.pi / 2)
            let sinD = sin(Double.pi / 2)
            for t in groupTables {
                let dx = t.positionX - cx
                let dy = t.positionY - cy
                t.positionX = cx + dx * cosD - dy * sinD
                t.positionY = cy + dx * sinD + dy * cosD
                t.rotation = newRot
            }
        } else {
            table.rotation = newRot
        }
    }

    /// Entfernt alle nicht-gepinnten Gäste vom Tisch (table = nil, seatIndex = nil).
    /// Bei Tafel: leert alle Gruppen-Tische gemeinsam.
    private func clearTable() {
        let targets: [GuestTable] = table.combinationGroup != nil ? groupTables : [table]
        for t in targets {
            for g in t.guests where !g.isPinned {
                g.seatIndex = nil
                g.table = nil
            }
        }
    }

    private func dissolveTafel() {
        guard let groupID = table.combinationGroup else { return }
        for t in allTables where t.combinationGroup == groupID {
            t.combinationGroup = nil
            t.combinationOrder = nil
            t.combinationRole = nil
        }
    }

    private func applyDrag(_ translation: CGSize) {
        if table.combinationGroup != nil {
            for t in groupTables {
                t.positionX += translation.width
                t.positionY += translation.height
            }
        } else {
            table.positionX += translation.width
            table.positionY += translation.height
        }
        dragOffset = .zero
    }

    @ViewBuilder
    private var tableShape: some View {
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

    @ViewBuilder
    private var allergyBadge: some View {
        if showTableWarnings, allergyCount > 0 {
            HStack(spacing: 2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8, weight: .bold))
                Text("\(allergyCount)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Color(hex: "#c44a4a"))
            .clipShape(Capsule())
            .help(allergyTooltip)
        }
    }

    private var allergyTooltip: String {
        let names = table.attendingGuests.filter(\.hasIntolerances).map(\.fullName).sorted().joined(separator: ", ")
        return "\(allergyCount) Gast\(allergyCount == 1 ? "" : "ä")ste mit Unverträglichkeiten: \(names)"
    }

    @ViewBuilder
    private var lateCancellationBadge: some View {
        let ghosts = table.ghostGuests
        if showTableWarnings, !ghosts.isEmpty {
            HStack(spacing: 2) {
                Image(systemName: "person.fill.xmark")
                    .font(.system(size: 8, weight: .bold))
                Text("\(ghosts.count)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Tokens.Colors.ink3)
            .clipShape(Capsule())
            .help(lateCancellationTooltip)
        }
    }

    private var lateCancellationTooltip: String {
        let ghosts = table.ghostGuests
        let names = ghosts.map(\.fullName).sorted().joined(separator: ", ")
        return "\(ghosts.count) späte Absage\(ghosts.count == 1 ? "" : "n") – Platz frei, Catering ist bestellt: \(names)"
    }

    @ViewBuilder
    private var badgeOverlay: some View {
        if table.isBridalTable {
            ZStack {
                Circle().fill(Tokens.Colors.accent)
                Image(systemName: "heart.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white)
            }
            .frame(width: 18, height: 18)
            .offset(x: 6, y: -6)
            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
        } else if hasPinnedGuest {
            ZStack {
                Circle().fill(Tokens.Colors.accent)
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.white)
            }
            .frame(width: 18, height: 18)
            .offset(x: 6, y: -6)
            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
        }
    }
}
#endif
