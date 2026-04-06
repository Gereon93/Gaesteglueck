#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TableCanvasItemView: View {
    @Bindable var table: GuestTable
    let isSelected: Bool
    let onTap: () -> Void
    @Query private var allTables: [GuestTable]

    @State private var dragOffset: CGSize = .zero
    @State private var showingCombineSheet = false

    var body: some View {
        VStack(spacing: 4) {
            tableShape
            HStack(spacing: 2) {
                Text(table.name)
                    .font(.caption2)
                if table.combinationGroup != nil {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 4)
            .background(.ultraThinMaterial, in: Capsule())
            Text("\(table.guests.count)/\(table.capacity)")
                .font(.caption2)
                .foregroundStyle(table.isFull ? .red : .secondary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : .clear)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
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
            Circle()
                .fill(Color.brown.opacity(0.3))
                .stroke(Color.brown, lineWidth: 1)
                .frame(width: table.diameter / 3, height: table.diameter / 3)
        case .rectangular:
            Rectangle()
                .fill(Color.brown.opacity(0.3))
                .stroke(Color.brown, lineWidth: 1)
                .frame(width: table.width / 3, height: table.depth / 3)
        case .square:
            Rectangle()
                .fill(Color.brown.opacity(0.3))
                .stroke(Color.brown, lineWidth: 1)
                .frame(width: table.width / 3, height: table.width / 3)
        }
    }
}
#endif
