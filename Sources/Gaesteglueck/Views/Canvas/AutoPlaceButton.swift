#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct AutoPlaceButton: View {
    @Query private var tables: [GuestTable]
    @Query private var roomPlans: [RoomPlan]

    private var roomWidth: Double { roomPlans.first?.roomWidthCM ?? 1200 }
    private var roomDepth: Double { roomPlans.first?.roomDepthCM ?? 1000 }

    @State private var showingConfirmation = false

    var body: some View {
        Button {
            showingConfirmation = true
        } label: {
            Label("Tische anordnen", systemImage: "square.grid.3x3")
        }
        .disabled(tables.isEmpty)
        .confirmationDialog("Tische automatisch anordnen?", isPresented: $showingConfirmation) {
            Button("Anordnen") { placeAll() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Tische werden basierend auf den Raummaßen optimal platziert.")
        }
    }

    private func placeAll() {
        let movableTables = tables.filter { !$0.isLocked }
        let placements = TablePlacer.suggestLayout(
            tables: movableTables,
            roomWidthCM: roomWidth,
            roomDepthCM: roomDepth
        )
        let scale = 1.0 / 3.0
        for placement in placements {
            if let table = tables.first(where: { $0.id == placement.tableID }) {
                table.positionX = placement.x * scale
                table.positionY = placement.y * scale
            }
        }
    }
}
#endif
