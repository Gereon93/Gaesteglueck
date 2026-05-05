#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct GuestListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var tags: [Tag]
    @State private var showingAddSheet = false
    @State private var editingGuest: Guest?
    @State private var searchText = ""
    @State private var showingEnrichment = false

    private var filteredGuests: [Guest] {
        guard !searchText.isEmpty else { return guests }
        return guests.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }

    private var groupedGuests: [PartnerAssignment: [Guest]] {
        Dictionary(grouping: filteredGuests, by: \.partnerAssignment)
    }

    var body: some View {
        List {
            ForEach(PartnerAssignment.allCases) { assignment in
                if let assignmentGuests = groupedGuests[assignment], !assignmentGuests.isEmpty {
                    Section {
                        ForEach(assignmentGuests) { guest in
                            GuestRowView(guest: guest, tags: tags)
                                .contentShape(Rectangle())
                                .onTapGesture { editingGuest = guest }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        modelContext.delete(guest)
                                    } label: {
                                        Label("Löschen", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Circle().fill(assignment.color).frame(width: 8, height: 8)
                            Text("\(assignment.rawValue) (\(assignmentGuests.count))")
                        }
                    }
                }
            }
        }
        .overlay {
            if guests.isEmpty {
                ContentUnavailableView("Noch keine Gäste", systemImage: "person.badge.plus", description: Text("Tippe auf + um den ersten Gast hinzuzufügen."))
            }
        }
        .navigationTitle("Gäste (\(guests.count))")
        .searchable(text: $searchText, prompt: "Gäste suchen")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Gast hinzufügen", systemImage: "plus")
                }
            }
            #if canImport(UniformTypeIdentifiers)
            ToolbarItem(placement: .secondaryAction) {
                ImportButton()
            }
            #endif
            ToolbarItem(placement: .secondaryAction) {
                GoogleSheetsImportButton()
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingEnrichment = true
                } label: {
                    Label("Anreichern", systemImage: "wand.and.sparkles")
                }
                .disabled(guests.isEmpty)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            GuestFormView()
        }
        .sheet(item: $editingGuest) { guest in
            GuestFormView(guest: guest)
        }
        .sheet(isPresented: $showingEnrichment) {
            EnrichmentWizardView()
        }
    }
}
#endif
