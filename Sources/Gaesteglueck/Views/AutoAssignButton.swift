#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct AutoAssignButton: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.name) private var guests: [Guest]
    @Query private var tables: [GuestTable]
    @Query private var relationships: [Relationship]

    @State private var isProcessing = false
    @State private var showingConfirmation = false
    @State private var resultScore: Double?

    private var unassignedGuests: [Guest] {
        guests.filter { $0.table == nil }
    }

    var body: some View {
        Button {
            showingConfirmation = true
        } label: {
            Label(isProcessing ? "Berechne..." : "Auto-Zuweisen", systemImage: "wand.and.stars")
        }
        .disabled(unassignedGuests.isEmpty || tables.isEmpty || isProcessing)
        .confirmationDialog("Automatische Sitzordnung", isPresented: $showingConfirmation) {
            Button("Nur nicht zugewiesene Gäste") { runSolver(reassignAll: false) }
            Button("Alle neu zuweisen (Pins bleiben)") { runSolver(reassignAll: true) }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der Algorithmus berechnet die beste Sitzordnung basierend auf Beziehungen, Gruppen und Konflikten.")
        }
        .alert("Sitzordnung berechnet", isPresented: Binding(
            get: { resultScore != nil },
            set: { if !$0 { resultScore = nil } }
        )) {
            Button("OK") { resultScore = nil }
        } message: {
            Text("Happiness Score: \(Int(resultScore ?? 0))")
        }
    }

    private func runSolver(reassignAll: Bool) {
        isProcessing = true

        // Unassign non-pinned guests if reassigning all
        if reassignAll {
            for guest in guests where !guest.isPinned {
                guest.table = nil
            }
        }

        let guestsToAssign = reassignAll ? guests.filter { !$0.isPinned } : Array(unassignedGuests)
        let assignment = SeatingOptimizer.solve(
            guests: guestsToAssign,
            tables: tables,
            relationships: relationships
        )

        // Apply assignment
        let tableMap = Dictionary(uniqueKeysWithValues: tables.map { ($0.id, $0) })
        for (guestID, tableID) in assignment {
            if let guest = guests.first(where: { $0.id == guestID }),
               let table = tableMap[tableID] {
                guest.table = table
            }
        }

        let score = HappinessScorer.scoreAllTables(tables, relationships: relationships)
        resultScore = score
        isProcessing = false
    }
}
#endif
