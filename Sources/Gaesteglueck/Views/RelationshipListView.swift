#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct RelationshipListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var relationships: [Relationship]
    @Query(sort: \Guest.name) private var guests: [Guest]
    @State private var showingAddSheet = false

    var body: some View {
        List {
            ForEach(relationships) { rel in
                RelationshipRowView(relationship: rel, allGuests: guests)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            modelContext.delete(rel)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
            }
        }
        .overlay {
            if relationships.isEmpty {
                ContentUnavailableView("Keine Beziehungen", systemImage: "heart.text.clipboard", description: Text("Definiere wer zusammen oder getrennt sitzen soll."))
            }
        }
        .navigationTitle("Beziehungen (\(relationships.count))")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Beziehung hinzufügen", systemImage: "plus")
                }
                .disabled(guests.count < 2)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            RelationshipFormView()
        }
    }
}
#endif
