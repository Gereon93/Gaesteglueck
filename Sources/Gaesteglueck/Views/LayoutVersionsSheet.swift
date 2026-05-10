#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct LayoutVersionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let event: Event
    @Query private var allTables: [GuestTable]
    @Query private var allGuests: [Guest]

    private var eventLabels: [CanvasLabel] {
        event.labels
    }
    @State private var newName: String = ""
    @State private var pendingRestore: LayoutVersion?

    private var versions: [LayoutVersion] {
        event.versions.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                List {
                    Section("Aktuell speichern") {
                        HStack {
                            TextField("z.B. Idee 1", text: $newName)
                            Button("Speichern") {
                                let name = newName.isEmpty ? "Idee \(versions.count + 1)" : newName
                                _ = LayoutVersionStore.snapshot(
                                    event: event,
                                    name: name,
                                    note: "",
                                    tables: allTables,
                                    labels: eventLabels,
                                    guests: allGuests,
                                    modelContext: modelContext
                                )
                                newName = ""
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                    }

                    Section("Gespeicherte Versionen") {
                        if versions.isEmpty {
                            Text("Noch keine Versionen.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(versions) { v in
                            HStack {
                                if event.activeVersionID == v.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(v.name).font(.body.weight(.medium))
                                    Text(v.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Laden") { pendingRestore = v }
                                Button(role: .destructive) {
                                    LayoutVersionStore.delete(version: v, event: event, modelContext: modelContext)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Versionen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .confirmationDialog(
                "Aktuellen Stand verwerfen?",
                isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                presenting: pendingRestore
            ) { v in
                Button("Erst speichern, dann laden") {
                    let name = "Auto-Sicherung vor \(v.name)"
                    _ = LayoutVersionStore.snapshot(
                        event: event, name: name, note: "",
                        tables: allTables, labels: eventLabels, guests: allGuests,
                        modelContext: modelContext
                    )
                    LayoutVersionStore.restore(
                        version: v, event: event,
                        currentTables: allTables, currentLabels: eventLabels, currentGuests: allGuests,
                        modelContext: modelContext
                    )
                    pendingRestore = nil
                    dismiss()
                }
                Button("Verwerfen und laden", role: .destructive) {
                    LayoutVersionStore.restore(
                        version: v, event: event,
                        currentTables: allTables, currentLabels: eventLabels, currentGuests: allGuests,
                        modelContext: modelContext
                    )
                    pendingRestore = nil
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) { pendingRestore = nil }
            }
        }
        .frame(minWidth: 480, minHeight: 400)
    }
}
#endif
