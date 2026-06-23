#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

/// S3 — Gästeliste (siehe design_handoff_gaesteglueck → S3). Drei Spalten:
/// links 200pt Filter-Rail (Seite + Tags + Status), Mitte tabellarische Liste,
/// rechts 300pt Inspector mit Detail des ausgewählten Gastes.
struct GuestListView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Guest.firstName) var guests: [Guest]
    @Query var tags: [Tag]
    @Query var tables: [GuestTable]
    @Query var events: [Event]

    @State var searchText = ""
    @State var selectedGuestIDs: Set<UUID> = []
    @State var anchorGuestID: UUID? = nil
    @State var showingAddSheet = false
    @State var editingGuest: Guest?
    @State var showingEnrichment = false
    @State var showingDeleteAlert = false

    var selectedGuests: [Guest] {
        guests.filter { selectedGuestIDs.contains($0.id) }
    }

    @State var sideFilter: PartnerAssignment? = nil
    @State var tagFilter: TagCategory? = nil
    @State var statusFilter: GuestListFiltering.StatusFilter? = nil
    @State var ageFilter: AgeCategory? = nil

    @State var isCheckingFunFacts: Bool = false
    @State var funFactCheckTask: Task<Void, Never>? = nil
    @State var funFactCheckProgress: (done: Int, total: Int) = (0, 0)
    @State var funFactCheckResult: String? = nil
    @State var isNormalizingFunFacts: Bool = false
    @State var funFactTask: Task<Void, Never>? = nil
    @State var funFactProgress: (done: Int, total: Int) = (0, 0)
    @State var funFactProposals: [FunFactNormalizer.Result] = []
    @State var funFactProposalSelection: Set<UUID> = []
    @State var showingFunFactReview: Bool = false

    @State var contactPickerGuest: Guest?
    @State var contactPickerMatches: [ContactMatch] = []
    @State var contactErrorMessage: String?

    // Spalten-Breiten — per Drag-Handle im Header verstellbar, persistent.
    @AppStorage("guestlist.col.name") var colNameWidth: Double = 220
    @AppStorage("guestlist.col.tags") var colTagsWidth: Double = 220
    @AppStorage("guestlist.col.seite") var colSeiteWidth: Double = 80
    @AppStorage("guestlist.col.tisch") var colTischWidth: Double = 80
    @AppStorage("guestlist.col.menu") var colMenuWidth: Double = 120

    // Spalten-Sichtbarkeit — per Toggle in den Settings konfigurierbar.
    @AppStorage("guestlist.col.funfact.visible") var showFunFactColumn: Bool = true
    @AppStorage("guestlist.col.tags.visible") var showTagsColumn: Bool = true
    @AppStorage("guestlist.col.seite.visible") var showSeiteColumn: Bool = true
    @AppStorage("guestlist.col.tisch.visible") var showTischColumn: Bool = true
    @AppStorage("guestlist.col.menu.visible") var showMenuColumn: Bool = true

    var filtering: GuestListFiltering {
        GuestListFiltering(
            guests: guests,
            tags: tags,
            searchText: searchText,
            sideFilter: sideFilter,
            tagFilter: tagFilter,
            statusFilter: statusFilter,
            ageFilter: ageFilter
        )
    }

    var body: some View {
        ZStack {
            Tokens.Colors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar
                HStack(alignment: .top, spacing: 0) {
                    GuestFilterRailView(
                        guests: guests,
                        tags: tags,
                        event: events.first,
                        filtering: filtering,
                        sideFilter: $sideFilter,
                        tagFilter: $tagFilter,
                        statusFilter: $statusFilter,
                        ageFilter: $ageFilter
                    )
                    .frame(width: 200, alignment: .top)
                    Divider().background(Tokens.Colors.line)
                    guestTable
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    Divider().background(Tokens.Colors.line)
                    GuestInspectorView(
                        guests: guests,
                        tags: tags,
                        event: events.first,
                        selectedGuestIDs: $selectedGuestIDs,
                        anchorGuestID: $anchorGuestID,
                        editingGuest: $editingGuest,
                        showingDeleteAlert: $showingDeleteAlert
                    )
                    .frame(width: 300, alignment: .top)
                }
            }
        }
        .sheet(isPresented: $showingFunFactReview) {
            FunFactReviewSheet(
                proposals: funFactProposals,
                selection: $funFactProposalSelection,
                onApply: applyFunFactProposals
            )
        }
        .sheet(isPresented: $isNormalizingFunFacts) {
            AIRunIndicator(
                title: "FunFacts werden vereinheitlicht…",
                progress: funFactProgress.total > 0 ? funFactProgress : nil,
                onCancel: { funFactTask?.cancel() }
            )
            .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $isCheckingFunFacts) {
            AIRunIndicator(
                title: "FunFacts werden geprüft…",
                progress: funFactCheckProgress.total > 0 ? funFactCheckProgress : nil,
                onCancel: { funFactCheckTask?.cancel() }
            )
            .interactiveDismissDisabled(true)
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
        .sheet(item: $contactPickerGuest) { guest in
            ContactPickerSheet(guest: guest, matches: contactPickerMatches) { phone in
                guest.phoneNumber = phone
                try? modelContext.save()
            }
        }
        .alert("Kontakte-Zugriff", isPresented: Binding(
            get: { contactErrorMessage != nil },
            set: { if !$0 { contactErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(contactErrorMessage ?? "")
        }
        .alert("\(selectedGuestIDs.count) Gäste löschen?", isPresented: $showingDeleteAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                deleteSelection()
            }
        } message: {
            Text("Diese Aktion lässt sich nicht rückgängig machen. Tische und Tags bleiben bestehen.")
        }
        .alert("FunFact-Check", isPresented: Binding(
            get: { funFactCheckResult != nil },
            set: { if !$0 { funFactCheckResult = nil } }
        ), presenting: funFactCheckResult) { _ in
            Button("OK") { funFactCheckResult = nil }
        } message: { msg in
            Text(msg)
        }
        .onKeyPress(.delete) {
            if !selectedGuestIDs.isEmpty {
                showingDeleteAlert = true
                return .handled
            }
            return .ignored
        }
    }

    func deleteSelection() {
        for guest in selectedGuests {
            modelContext.delete(guest)
        }
        selectedGuestIDs.removeAll()
        anchorGuestID = nil
    }

    /// Wählt alle aktuell sichtbaren (gefilterten) Gäste aus. Macht Filter +
    /// Bulk-Tag zum Two-Step-Massen-Workflow: Filter setzen → "Alle X
    /// auswählen" → Inspector → "Tag hinzufügen" → fertig.
    func selectAllVisible() {
        let visible = filtering.filteredGuests
        selectedGuestIDs = Set(visible.map(\.id))
        anchorGuestID = visible.first?.id
    }

    /// Erzeugt einen mustSitTogether-Constraint für alle aktuell selektierten
    /// Gäste. Wenn schon ein passender Constraint mit derselben Gäste-Menge
    /// existiert, passiert nichts. Der Constraint wird vom Auto-Sitzplaner
    /// und vom manuellen Drop (placeGuestWithCompanions) respektiert.
    func linkSelectedAsMustSitTogether() {
        let ids = Array(selectedGuestIDs)
        guard ids.count >= 2 else { return }
        let descriptor = FetchDescriptor<Constraint>()
        if let existing = try? modelContext.fetch(descriptor),
           MustSitTogetherLink.alreadyLinked(ids, in: existing) {
            return
        }
        let reason = MustSitTogetherLink.reason(for: ids, in: guests)
        let c = Constraint(type: .mustSitTogether, guestIDs: ids, reason: reason)
        modelContext.insert(c)
        try? modelContext.save()
    }
}
#endif
