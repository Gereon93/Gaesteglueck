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

    private var scaledDiameter: CGFloat { max(table.diameter * canvasScale, 40) }
    private var scaledWidth: CGFloat { max(table.width * canvasScale, 40) }
    private var scaledDepth: CGFloat { max(table.depth * canvasScale, 28) }

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

    private var tableShape: some View {
        TableCanvasTableShapeView(table: table, isSelected: isSelected)
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
                .overlay(alignment: .topTrailing) {
                    TableCanvasBadgeOverlay(table: table)
                }
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
                    TableCanvasAllergyBadge(table: table)
                    TableCanvasLateCancellationBadge(table: table)
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
        TableCanvasSeatSideLogic.resolvedNameSide(
            override: table.seatNameSide,
            localX: localX,
            localY: localY,
            halfWidth: (table.shape == .round ? scaledDiameter : scaledWidth) / 2,
            halfDepth: (table.shape == .round ? scaledDiameter : scaledDepth) / 2
        )
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

    @discardableResult
    private func placeGuestWithCompanions(
        guest: Guest,
        on target: GuestTable,
        primarySeatIndex: Int?
    ) -> Bool {
        TableCanvasPlacement.placeGuestWithCompanions(
            guest: guest,
            on: target,
            primarySeatIndex: primarySeatIndex,
            allGuests: allGuests,
            allConstraints: allConstraints,
            rules: currentRules
        )
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
        TableCanvasMutations.rotateBy90(
            table: table,
            groupTables: groupTables,
            rules: event?.seatingRules ?? .default
        )
    }

    private func clearTable() {
        TableCanvasMutations.clearTable(table: table, groupTables: groupTables)
    }

    private func dissolveTafel() {
        TableCanvasMutations.dissolveTafel(table: table, allTables: allTables)
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

}
#endif
