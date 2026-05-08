#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Tisch-Shape im Canvas (siehe design_handoff_gaesteglueck → S6 → Table).
/// Akzent-Tint Fill für gepinnte Tische, Sage-Tint für KI-vorgeschlagene
/// Cluster, weißer Surface für offene Tische. Border 2pt-Akzent wenn
/// selektiert, Warn-Border bei Constraint-Verletzungen. Kleine Pin-/Warn-
/// Badges oben rechts.
struct TableCanvasItemView: View {
    @Bindable var table: GuestTable
    let isSelected: Bool
    let onTap: () -> Void
    @Query private var allTables: [GuestTable]

    @State private var dragOffset: CGSize = .zero
    @State private var showingCombineSheet = false

    private var hasPinnedGuest: Bool {
        table.guests.contains(where: { $0.isPinned })
    }

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
                Text("\(table.guests.count)/\(table.capacity)")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(table.isFull ? Tokens.Colors.warn : Tokens.Colors.ink3)
                    .monospacedDigit()
                if table.combinationGroup != nil {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                        .foregroundStyle(Tokens.Colors.accent)
                }
            }
            .padding(.horizontal, 6)
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
            .frame(width: table.diameter / 3, height: table.diameter / 3)
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
            .frame(width: table.width / 3, height: table.depth / 3)
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
            .frame(width: table.width / 3, height: table.width / 3)
            .shadow(
                color: isSelected ? Tokens.Colors.accent.opacity(0.2) : Color.black.opacity(0.06),
                radius: isSelected ? 16 : 6,
                x: 0,
                y: isSelected ? 4 : 2
            )
        }
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
