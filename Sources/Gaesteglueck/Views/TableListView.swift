#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TableListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GuestTable.name) private var tables: [GuestTable]
    @State private var showingAddSheet = false
    @State private var editingTable: GuestTable?

    private var totalCapacity: Int {
        tables.reduce(0) { $0 + $1.capacity }
    }

    private var totalAssigned: Int {
        tables.reduce(0) { $0 + $1.guests.count }
    }

    var body: some View {
        List {
            if !tables.isEmpty {
                Section {
                    HStack {
                        Label("Tische", systemImage: "tablecells")
                        Spacer()
                        Text("\(tables.count)")
                    }
                    HStack {
                        Label("Kapazität", systemImage: "chair")
                        Spacer()
                        Text("\(totalAssigned)/\(totalCapacity) Plätze")
                    }
                } header: {
                    Text("Übersicht")
                }
            }

            Section {
                ForEach(tables) { table in
                    TableRowView(table: table)
                        .contentShape(Rectangle())
                        .onTapGesture { editingTable = table }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(table)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .overlay {
            if tables.isEmpty {
                ContentUnavailableView {
                    Label("Noch keine Tische", systemImage: "tablecells.badge.ellipsis")
                } description: {
                    Text("Wie viele Tische habt ihr im Saal? Form und Größe legst du hier fest — Platzierung passiert dann auf eurem Grundriss.")
                } actions: {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("Ersten Tisch erstellen", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .navigationTitle("Tische")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Tisch erstellen", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            TableFormView()
        }
        .sheet(item: $editingTable) { table in
            TableFormView(table: table)
        }
    }
}
#endif
