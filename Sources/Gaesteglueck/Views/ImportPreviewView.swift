#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct ImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let families: [ImportedFamily]
    let onComplete: (Int) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Familien/Paare")
                        Spacer()
                        Text("\(families.count)")
                    }
                    HStack {
                        Text("Personen gesamt")
                        Spacer()
                        Text("\(families.reduce(0) { $0 + $1.members.count })")
                    }
                } header: {
                    Text("Übersicht")
                }

                ForEach(Array(families.enumerated()), id: \.offset) { _, family in
                    Section {
                        ForEach(Array(family.members.enumerated()), id: \.offset) { _, member in
                            HStack {
                                Circle().fill(member.side.color).frame(width: 8, height: 8)
                                Text(member.name)
                                if member.isChild {
                                    Image(systemName: "figure.child")
                                        .font(.caption2)
                                }
                                Spacer()
                                Text(member.dietaryPreference.badge)
                                if !member.allergies.isEmpty {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
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
        for family in families {
            for member in family.members {
                let guest = Guest(
                    name: member.name,
                    side: member.side,
                    familyID: family.sharedFamilyID,
                    dietaryPreference: member.dietaryPreference,
                    allergies: member.allergies,
                    isChild: member.isChild
                )
                modelContext.insert(guest)
                count += 1
            }
        }
        onComplete(count)
        dismiss()
    }
}

// Color extension for ImportedGuest.side (uses the existing Side.color from ModelExtensions+UI)
extension ImportedGuest {
    // Side already has .color from ModelExtensions+UI.swift
}
#endif
