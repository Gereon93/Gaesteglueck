#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TableInventoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [TableInventoryItem]

    var body: some View {
        List {
            ForEach(items) { item in
                HStack {
                    Image(systemName: item.shape.icon)
                        .frame(width: 24)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading) {
                        Text(item.label)
                            .font(.body)
                        Text(dimensionText(item))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Stepper(value: Binding(
                        get: { item.availableCount },
                        set: { item.availableCount = max(0, $0) }
                    ), in: 0...100) {
                        Text("\(item.availableCount)")
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    modelContext.delete(items[index])
                }
            }

            Section("Tisch-Typ hinzufügen") {
                Button { addPreset(.round, diameter: 180) } label: {
                    Label("Rund 180cm", systemImage: "circle")
                }
                Button { addPreset(.rectangular, width: 200, depth: 100) } label: {
                    Label("Rechteckig 200x100", systemImage: "rectangle")
                }
                Button { addPreset(.square, width: 120) } label: {
                    Label("Quadratisch 120cm", systemImage: "square")
                }
            }
        }
        .navigationTitle("Tisch-Inventar")
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("Kein Inventar", systemImage: "tablecells", description: Text("Füge Tischtypen für die automatische Platzierung hinzu."))
            }
        }
    }

    private func dimensionText(_ item: TableInventoryItem) -> String {
        switch item.shape {
        case .round: "Ø \(Int(item.diameter)) cm"
        case .rectangular: "\(Int(item.width)) × \(Int(item.depth)) cm"
        case .square: "\(Int(item.width)) × \(Int(item.width)) cm"
        }
    }

    private func addPreset(_ shape: TableShape, diameter: Double = 180, width: Double = 200, depth: Double = 100) {
        let item = TableInventoryItem(shape: shape, width: width, depth: depth, diameter: diameter, availableCount: 1)
        modelContext.insert(item)
    }
}
#endif
