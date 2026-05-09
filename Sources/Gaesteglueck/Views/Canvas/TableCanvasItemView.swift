#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TableCanvasItemView: View {
    @Bindable var table: GuestTable
    let isSelected: Bool
    let onTap: () -> Void
    @Query private var allTables: [GuestTable]
    @Query private var allGuests: [Guest]
    @Environment(\.canvasScale) private var canvasScale

    @State private var dragOffset: CGSize = .zero
    @State private var showingCombineSheet = false

    private var seatPositions: [CGPoint] {
        SeatLayout.positions(
            shape: table.shape,
            capacity: table.capacity,
            scaledDiameter: scaledDiameter,
            scaledWidth: scaledWidth,
            scaledDepth: scaledDepth
        )
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
        table.guests.filter(\.hasIntolerances).count
    }

    var body: some View {
        ZStack {
            tableShape
                .overlay(alignment: .topTrailing) {
                    badgeOverlay
                }
            VStack(spacing: 3) {
                Text(table.name)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(table.guests.count)/\(table.capacity)")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(table.isFull ? Tokens.Colors.warn : Tokens.Colors.ink3)
                        .monospacedDigit()
                    allergyBadge
                }
                if table.combinationGroup != nil {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                        .foregroundStyle(Tokens.Colors.accent)
                }
            }
            .padding(.horizontal, 6)

            seatChips
        }
        .position(x: table.positionX + dragOffset.width, y: table.positionY + dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    table.positionX += value.translation.width
                    table.positionY += value.translation.height
                    dragOffset = .zero
                }
        )
        .onTapGesture(perform: onTap)
        .contextMenu {
            if table.shape == .rectangular {
                Button {
                    showingCombineSheet = true
                } label: {
                    Label("Tisch verbinden", systemImage: "link")
                }
            }
            if let groupID = table.combinationGroup {
                Button(role: .destructive) {
                    for t in allTables where t.combinationGroup == groupID {
                        t.combinationGroup = nil
                        t.combinationRole = nil
                    }
                } label: {
                    Label("Verbindung lösen", systemImage: "link.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingCombineSheet) {
            TableCombineSheet(table: table)
        }
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
    private var seatChips: some View {
        let positions = seatPositions
        ForEach(0..<positions.count, id: \.self) { idx in
            SeatChipView(
                seatIndex: idx,
                occupant: occupant(at: idx),
                onDrop: { guestID in
                    assignGuestToSeat(guestID: guestID, seatIndex: idx)
                },
                onClear: {
                    if let occ = occupant(at: idx) {
                        occ.seatIndex = nil
                    }
                }
            )
            .offset(x: positions[idx].x, y: positions[idx].y)
        }
    }

    /// Drop auf konkreten Sitz: Gast bekommt diesen Tisch + diesen Sitz-Index.
    /// Falls dort schon jemand sitzt → Swap (der bisherige Sitzende verliert
    /// seinen `seatIndex`, bleibt aber am Tisch).
    private func assignGuestToSeat(guestID: UUID, seatIndex: Int) -> Bool {
        guard let guest = allGuests.first(where: { $0.id == guestID }) else { return false }
        if guest.isPinned { return false }

        if guest.table?.id != table.id {
            let availableSeats = table.capacity - table.guests.count
            if availableSeats <= 0 { return false }
        }

        let prior = occupant(at: seatIndex)
        let guestPriorSeat = guest.table?.id == table.id ? guest.seatIndex : nil

        if let prior, prior.id != guest.id {
            prior.seatIndex = guestPriorSeat
        }

        guest.table = table
        guest.seatIndex = seatIndex
        return true
    }

    @ViewBuilder
    private var allergyBadge: some View {
        if allergyCount > 0 {
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
        let names = table.guests.filter(\.hasIntolerances).map(\.fullName).sorted().joined(separator: ", ")
        return "\(allergyCount) Gast\(allergyCount == 1 ? "" : "ä")ste mit Unverträglichkeiten: \(names)"
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
