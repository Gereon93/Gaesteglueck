#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct GuestListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.name) private var guests: [Guest]
    @State private var showingAddSheet = false
    @State private var editingGuest: Guest?
    @State private var searchText = ""

    private var filteredGuests: [Guest] {
        guard !searchText.isEmpty else { return guests }
        return guests.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var groupedGuests: [Side: [Guest]] {
        Dictionary(grouping: filteredGuests, by: \.side)
    }

    var body: some View {
        List {
            ForEach(Side.allCases) { side in
                if let sideGuests = groupedGuests[side], !sideGuests.isEmpty {
                    Section {
                        ForEach(sideGuests) { guest in
                            GuestRowView(guest: guest)
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
                            Circle().fill(side.color).frame(width: 8, height: 8)
                            Text("\(side.rawValue) (\(sideGuests.count))")
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
        }
        .sheet(isPresented: $showingAddSheet) {
            GuestFormView()
        }
        .sheet(item: $editingGuest) { guest in
            GuestFormView(guest: guest)
        }
    }
}
#endif
