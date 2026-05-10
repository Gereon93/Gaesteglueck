#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TableCombineSheet: View {
    @Environment(\.dismiss) private var dismiss
    let table: GuestTable
    @Query(sort: \GuestTable.name) private var allTables: [GuestTable]
    @State private var selected: Set<UUID> = []

    private var availableTables: [GuestTable] {
        allTables.filter {
            $0.id != table.id
                && $0.shape == .rectangular
                && $0.combinationGroup == nil
                && $0.depth == table.depth
        }
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
                                t.combinationOrder = nil
                                t.combinationRole = nil
                            }
                            dismiss()
                        }
                    }
                }

                Section("Verfügbare Tische (gleiche Tiefe)") {
                    if availableTables.isEmpty {
                        Text("Keine kompatiblen Tische verfügbar.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(availableTables) { other in
                        Button {
                            if selected.contains(other.id) {
                                selected.remove(other.id)
                            } else {
                                selected.insert(other.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selected.contains(other.id) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(selected.contains(other.id) ? Color.accentColor : Color.secondary)
                                Text(other.name)
                                Spacer()
                                Text("\(other.width.formatted())×\(other.depth.formatted()) cm")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Tafel bauen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selected.isEmpty ? "Zur Tafel verbinden" : "\(selected.count + 1) verbinden") {
                        applyCombine()
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }

    private func applyCombine() {
        let chosen = availableTables.filter { selected.contains($0.id) }
        let all = [table] + chosen
        let groupID = table.combinationGroup ?? UUID()

        for (i, t) in all.enumerated() {
            t.combinationGroup = groupID
            t.combinationOrder = i
            t.combinationRole = nil
        }

        let totalWidth = all.reduce(0.0) { $0 + $1.width }
        var cursor = table.positionX - totalWidth / 2
        for t in all {
            t.positionX = cursor + t.width / 2
            t.positionY = table.positionY
            t.rotation = table.rotation
            cursor += t.width
        }

        for t in all {
            for g in t.guests {
                g.seatIndex = nil
            }
        }
    }
}
#endif
