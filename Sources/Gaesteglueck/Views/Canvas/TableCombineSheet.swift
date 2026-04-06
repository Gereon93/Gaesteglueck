#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TableCombineSheet: View {
    @Environment(\.dismiss) private var dismiss
    let table: GuestTable
    @Query(sort: \GuestTable.name) private var allTables: [GuestTable]

    private var availableTables: [GuestTable] {
        allTables.filter { $0.id != table.id && $0.shape == .rectangular && $0.combinationGroup == nil }
    }

    var body: some View {
        NavigationStack {
            List {
                if table.combinationGroup != nil {
                    Section {
                        Button("Verbindung lösen", role: .destructive) {
                            let groupID = table.combinationGroup
                            for t in allTables where t.combinationGroup == groupID {
                                t.combinationGroup = nil
                                t.combinationRole = nil
                            }
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
                            let groupID = table.combinationGroup ?? UUID()
                            table.combinationGroup = groupID
                            table.combinationRole = .head
                            other.combinationGroup = groupID
                            other.combinationRole = .end
                            other.positionX = table.positionX + table.width / 3 + 5
                            other.positionY = table.positionY
                            dismiss()
                        } label: {
                            HStack {
                                Text(other.name)
                                Spacer()
                                Text("\(other.width.formatted())x\(other.depth.formatted()) cm")
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
