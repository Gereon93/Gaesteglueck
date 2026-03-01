#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TableCanvasItemView: View {
    @Bindable var table: GuestTable
    let isSelected: Bool
    let onTap: () -> Void

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 4) {
            tableShape
            Text(table.name)
                .font(.caption2)
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
        case .brideTable:
            Rectangle()
                .fill(Color.yellow.opacity(0.3))
                .stroke(Color.yellow.mix(with: .brown, by: 0.5), lineWidth: 2)
                .frame(width: table.width / 3, height: table.depth / 3)
        }
    }
}
#endif
