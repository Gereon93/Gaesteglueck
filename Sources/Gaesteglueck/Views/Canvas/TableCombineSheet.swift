#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TableCombineSheet: View {
    @Environment(\.dismiss) private var dismiss
    let table: GuestTable
    @Query(sort: \GuestTable.name) private var allTables: [GuestTable]

    private var availableTables: [GuestTable] {
        allTables.filter { $0.id != table.id && $0.shape == .rectangular && $0.linkedTableID == nil }
    }

    var body: some View {
        NavigationStack {
            List {
                if table.linkedTableID != nil {
                    Section {
                        Button("Verbindung lösen", role: .destructive) {
                            if let linkedID = table.linkedTableID,
                               let linked = allTables.first(where: { $0.id == linkedID }) {
                                linked.linkedTableID = nil
                            }
                            table.linkedTableID = nil
                            dismiss()
                        }
                    }
                }

                Section("Verfügbare Tische") {
                    if availableTables.isEmpty {
                        Text("Keine freien rechteckigen Tische verfügbar.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(availableTables) { other in
                        Button {
                            table.linkedTableID = other.id
                            other.linkedTableID = table.id
                            // Position the linked table next to this one
                            other.positionX = table.positionX + table.width / 3 + 5
                            other.positionY = table.positionY
                            dismiss()
                        } label: {
                            HStack {
                                Text(other.name)
                                Spacer()
                                Text("\(other.width.formatted())×\(other.depth.formatted()) cm")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tisch verbinden")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}
#endif
