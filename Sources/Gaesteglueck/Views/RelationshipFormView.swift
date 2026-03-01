#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct RelationshipFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.name) private var guests: [Guest]

    @State private var personA: Guest?
    @State private var personB: Guest?
    @State private var type: RelationshipType = .friend
    @State private var notes = ""

    private var isValid: Bool {
        personA != nil && personB != nil && personA?.id != personB?.id
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Personen") {
                    Picker("Person A", selection: $personA) {
                        Text("Wählen…").tag(nil as Guest?)
                        ForEach(guests) { guest in
                            Text(guest.name).tag(guest as Guest?)
                        }
                    }
                    Picker("Person B", selection: $personB) {
                        Text("Wählen…").tag(nil as Guest?)
                        ForEach(guests.filter { $0.id != personA?.id }) { guest in
                            Text(guest.name).tag(guest as Guest?)
                        }
                    }
                }
                Section("Art der Beziehung") {
                    Picker("Typ", selection: $type) {
                        ForEach(RelationshipType.allCases) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section("Notizen") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Beziehung hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        guard let personA, let personB else { return }
        let rel = Relationship(
            personAID: personA.id,
            personBID: personB.id,
            type: type,
            notes: notes
        )
        modelContext.insert(rel)
        dismiss()
    }
}
#endif
