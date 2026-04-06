#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct ImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let rows: [RegistrationRow]
    let onComplete: (Int) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Registrierungen")
                        Spacer()
                        Text("\(rows.count)")
                    }
                    HStack {
                        Text("Personen gesamt")
                        Spacer()
                        Text("\(rows.reduce(0) { $0 + $1.guestCount })")
                    }
                } header: {
                    Text("Übersicht")
                }

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    Section {
                        HStack {
                            Text(row.familyName)
                                .font(.headline)
                            Spacer()
                            Text("\(row.guestCount) Personen")
                                .foregroundStyle(.secondary)
                        }
                        if !row.guestDetails.isEmpty {
                            Text(row.guestDetails)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !row.notes.isEmpty {
                            Text(row.notes)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("Import-Vorschau")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importieren") { performImport() }
                }
            }
        }
    }

    private func performImport() {
        var count = 0
        for row in rows {
            let registrationGroup = UUID()
            // Create a placeholder guest for each registration row
            let guest = Guest(
                firstName: row.familyName,
                notes: [row.guestDetails, row.funFacts, row.notes].filter { !$0.isEmpty }.joined(separator: " | "),
                registrationGroup: registrationGroup
            )
            modelContext.insert(guest)
            count += 1

            // Create additional guests if count > 1
            for i in 1..<row.guestCount {
                let extra = Guest(
                    firstName: "\(row.familyName) +\(i)",
                    registrationGroup: registrationGroup
                )
                modelContext.insert(extra)
                count += 1
            }
        }
        onComplete(count)
        dismiss()
    }
}
#endif
