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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var tags: [Tag]
    @Query private var tables: [GuestTable]
    @Query private var events: [Event]

    @State private var searchText = ""
    @State private var selectedGuestIDs: Set<UUID> = []
    @State private var anchorGuestID: UUID? = nil
    @State private var showingAddSheet = false
    @State private var editingGuest: Guest?
    @State private var showingEnrichment = false
    @State private var showingDeleteAlert = false

    private var selectedGuests: [Guest] {
        guests.filter { selectedGuestIDs.contains($0.id) }
    }

    @State private var sideFilter: PartnerAssignment? = nil
    @State private var tagFilter: TagCategory? = nil
    @State private var statusFilter: GuestListFiltering.StatusFilter? = nil
    @State private var ageFilter: AgeCategory? = nil

    @State private var isCheckingFunFacts: Bool = false
    @State private var funFactCheckTask: Task<Void, Never>? = nil
    @State private var funFactCheckProgress: (done: Int, total: Int) = (0, 0)
    @State private var funFactCheckResult: String? = nil
    @State private var isNormalizingFunFacts: Bool = false
    @State private var funFactTask: Task<Void, Never>? = nil
    @State private var funFactProgress: (done: Int, total: Int) = (0, 0)
    @State private var funFactProposals: [FunFactNormalizer.Result] = []
    @State private var funFactProposalSelection: Set<UUID> = []
    @State private var showingFunFactReview: Bool = false

    @State private var contactPickerGuest: Guest?
    @State private var contactPickerMatches: [ContactMatch] = []
    @State private var contactErrorMessage: String?

    // Spalten-Breiten — per Drag-Handle im Header verstellbar, persistent.
    @AppStorage("guestlist.col.name") private var colNameWidth: Double = 220
    @AppStorage("guestlist.col.tags") private var colTagsWidth: Double = 220
    @AppStorage("guestlist.col.seite") private var colSeiteWidth: Double = 80
    @AppStorage("guestlist.col.tisch") private var colTischWidth: Double = 80
    @AppStorage("guestlist.col.menu") private var colMenuWidth: Double = 120

    // Spalten-Sichtbarkeit — per Toggle in den Settings konfigurierbar.
    @AppStorage("guestlist.col.funfact.visible") private var showFunFactColumn: Bool = true
    @AppStorage("guestlist.col.tags.visible") private var showTagsColumn: Bool = true
    @AppStorage("guestlist.col.seite.visible") private var showSeiteColumn: Bool = true
    @AppStorage("guestlist.col.tisch.visible") private var showTischColumn: Bool = true
    @AppStorage("guestlist.col.menu.visible") private var showMenuColumn: Bool = true

    private var filtering: GuestListFiltering {
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

    // MARK: - Toolbar

    private var toolbar: some View {
        ScreenToolbar(title: "Gästeliste", subtitle: toolbarSubtitle) {
            if selectedGuestIDs.count >= 2 {
                Button {
                    linkSelectedAsMustSitTogether()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link.badge.plus")
                        Text("Müssen zusammen")
                    }
                }
                .warmButton(.secondary)
                Button {
                    showingDeleteAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("\(selectedGuestIDs.count) löschen")
                    }
                }
                .warmButton(.secondary)
                .foregroundStyle(Tokens.Colors.error)
                Button("Auswahl aufheben") {
                    selectedGuestIDs.removeAll()
                    anchorGuestID = nil
                }
                .warmButton(.ghost)
            } else if filtering.hasActiveFilter, !filtering.filteredGuests.isEmpty {
                // Wenn nichts ausgewählt aber ein Filter aktiv ist → Quick-
                // Action zum Massen-Selektieren des sichtbaren Bereichs.
                // Workflow: Filter side=Bob + tag=Freundesgruppe → klick
                // "Alle X auswählen" → im Inspector "Tag hinzufügen" mit
                // "Geburtstag Bob".
                Button {
                    selectAllVisible()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                        Text("Alle \(filtering.filteredGuests.count) auswählen")
                    }
                }
                .warmButton(.secondary)
            }
            Button {
                runFunFactCheck()
            } label: {
                HStack(spacing: 4) {
                    if isCheckingFunFacts { ProgressView().controlSize(.small) }
                    Image(systemName: "checkmark.seal")
                    Text("FunFacts prüfen")
                }
            }
            .warmButton(.secondary)
            .disabled(isCheckingFunFacts || guests.isEmpty)
            Button {
                runFunFactNormalize()
            } label: {
                HStack(spacing: 4) {
                    if isNormalizingFunFacts { ProgressView().controlSize(.small) }
                    Image(systemName: "text.append")
                    Text("Vereinheitlichen")
                }
            }
            .warmButton(.secondary)
            .disabled(isNormalizingFunFacts || guests.isEmpty)
            .help("FunFacts per KI in einheitliche Ich-Form bringen — du bestätigst vor dem Übernehmen")
            #if os(macOS)
            Menu {
                Button("Als PDF exportieren") {
                    exportFunFactWorklist(format: .pdf)
                }
                Button("Als CSV / Excel exportieren") {
                    exportFunFactWorklist(format: .csv)
                }
                Divider()
                Button("Erinnerungstexte (CSV) — versandfertig") {
                    exportFunFactWorklist(format: .reminderCSV)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                    Text("FunFact-Liste")
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .disabled(funFactWorklistCount == 0)
            #endif
            #if canImport(UniformTypeIdentifiers)
            ImportButton()
            #endif
            GoogleSheetsImportButton()
            Button {
                showingAddSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Gast hinzufügen")
                }
            }
            .warmButton(.primary)
        }
    }

    private var toolbarSubtitle: String {
        let total = guests.count
        let registrationCount = Set(guests.map { $0.registrationGroup }).count
        let allergic = guests.filter { $0.hasIntolerances }.count
        if total == 0 { return "Noch keine Gäste — leg los mit dem Import." }
        return "\(total) Gäste · \(registrationCount) Anmeldungen · \(allergic) mit Allergie"
    }

    // MARK: - Guest Table

    private var guestTable: some View {
        VStack(spacing: 0) {
            // Suche-Feld am oberen Rand der Tabelle, statt .searchable()
            // (das auf macOS ohne NavigationStack einen leeren Reservierungs-
            // Bereich erzeugt der den Spalten-Header runterdrueckt).
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Tokens.Colors.ink3)
                    .font(.system(size: 12))
                TextField("Gäste suchen", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .rounded))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Tokens.Colors.ink3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
            .frame(height: 26)
            .background(Tokens.Colors.surface)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Tokens.Colors.line).frame(height: 1)
            }

            if filtering.filteredGuests.isEmpty {
                EmptyStateCard(
                    icon: "person.3.sequence",
                    title: searchText.isEmpty ? "Keine Gäste gefunden" : "Keine Treffer",
                    message: searchText.isEmpty
                        ? "Lade die ersten Anmeldungen rein — aus Google Sheets, Excel oder einzeln per Hand."
                        : "Versuch eine andere Suche oder pass die Filter an."
                )
                .padding(40)
            } else {
                guestTableHeader
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        ForEach(filtering.registrationSections) { section in
                            sectionHeader(section)
                            ForEach(section.guests) { guest in
                                guestRow(guest: guest)
                                Rectangle()
                                    .fill(Tokens.Colors.line)
                                    .frame(height: 1)
                            }
                            ForEach(section.dimmedGuests) { guest in
                                outOfFilterRow(guest: guest)
                                Rectangle()
                                    .fill(Tokens.Colors.line)
                                    .frame(height: 1)
                            }
                        }
                    }
                }
            }
        }
        .background(Tokens.Colors.bg)
    }

    @ViewBuilder
    private func outOfFilterRow(guest: Guest) -> some View {
        guestRow(guest: guest)
            .opacity(0.32)
            .saturation(0.4)
            .overlay(alignment: .trailing) {
                Text("nicht im Filter")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Tokens.Colors.bg2)
                    .clipShape(Capsule())
                    .padding(.trailing, 14)
            }
    }

    private func sectionHeader(_ section: GuestListFiltering.RegistrationSection) -> some View {
        let total = section.guests.count + section.dimmedGuests.count
        let countText: String
        if section.dimmedGuests.isEmpty {
            countText = "\(total) \(total == 1 ? "Person" : "Personen")"
        } else {
            countText = "\(section.guests.count) von \(total) Personen (gefiltert)"
        }
        return HStack(spacing: 8) {
            if section.isBridal {
                Image(systemName: "heart.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.Colors.accent)
            }
            Text(section.label.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(section.isBridal ? Tokens.Colors.accent : Tokens.Colors.ink3)
                .tracking(0.6)
            Text("·")
                .foregroundStyle(Tokens.Colors.ink4)
            Text(countText)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .background(section.isBridal ? Tokens.Colors.accentTint.opacity(0.5) : Tokens.Colors.bg2)
    }

    private var guestTableHeader: some View {
        HStack(spacing: 0) {
            tableHeaderCell("Name", width: colNameWidth)
            ColumnResizeHandle(width: $colNameWidth, minWidth: 100, maxWidth: 400)

            if showFunFactColumn {
                tableHeaderCell("FunFact", width: nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if showTagsColumn || showSeiteColumn || showTischColumn || showMenuColumn {
                    columnSeparator
                }
            }

            if showTagsColumn {
                tableHeaderCell("Tags", width: colTagsWidth)
                ColumnResizeHandle(width: $colTagsWidth, minWidth: 80, maxWidth: 400)
            }

            if showSeiteColumn {
                tableHeaderCell("Seite", width: colSeiteWidth)
                ColumnResizeHandle(width: $colSeiteWidth, minWidth: 50, maxWidth: 200)
            }

            if showTischColumn {
                tableHeaderCell("Tisch", width: colTischWidth)
                ColumnResizeHandle(width: $colTischWidth, minWidth: 50, maxWidth: 200)
            }

            if showMenuColumn {
                tableHeaderCell("Menü", width: colMenuWidth)
                ColumnResizeHandle(width: $colMenuWidth, minWidth: 60, maxWidth: 240)
            }

            // Wenn FunFact ausgeblendet: Spacer der den verbleibenden Platz frisst,
            // damit der Header rechtsbuendig nicht zerlaeuft.
            if !showFunFactColumn {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(height: 26)
        .background(Tokens.Colors.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Colors.line).frame(height: 1)
        }
    }

    private var columnSeparator: some View {
        Rectangle()
            .fill(Tokens.Colors.line2)
            .frame(width: 1)
            .opacity(0.5)
            .padding(.horizontal, 2)
    }

    private func tableHeaderCell(_ label: String, width: CGFloat?) -> some View {
        Text(label.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Tokens.Colors.ink3)
            .tracking(0.5)
            .frame(width: width, alignment: .leading)
    }

    /// Zelle mit FunFact + Status-Indikator. Zeigt den Text gekürzt auf
    /// 2 Zeilen plus ein farbiger Punkt links: grün = OK, gelb = unklar,
    /// orange = fehlt komplett.
    @ViewBuilder
    private func funFactCell(for guest: Guest) -> some View {
        let trimmed = guest.funFactDisplay.trimmingCharacters(in: .whitespaces)
        let dotColor: Color = {
            if trimmed.isEmpty { return Color(hex: "#cc8a3a") } // fehlt
            if !guest.funFactApproved { return Color(hex: "#b0b0b0") } // unklar
            return Color(hex: "#5a8a4a") // ok
        }()
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            if trimmed.isEmpty {
                Text("—")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            } else {
                Text(trimmed)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .help(trimmed)
            }
        }
        .padding(.trailing, 8)
    }

    private func guestRow(guest: Guest) -> some View {
        let isSelected = selectedGuestIDs.contains(guest.id)
        let avatarTag = GuestDisplayFormatting.avatarKind(for: guest, tags: tags)

        return HStack(spacing: 0) {
            HStack(spacing: 10) {
                Avatar(name: guest.fullName, size: 28, tag: avatarTag,
                       diet: GuestDisplayFormatting.dietBadge(for: guest), pinned: guest.isPinned)
                VStack(alignment: .leading, spacing: 1) {
                    Text(guest.fullName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(width: colNameWidth, alignment: .leading)
            Spacer().frame(width: 6)  // matches resize-handle width

            if showFunFactColumn {
                funFactCell(for: guest)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showTagsColumn {
                ChipFlowLayout(spacing: 4) {
                    let guestTags = tags.filter { $0.guestIDs.contains(guest.id) }
                    ForEach(guestTags, id: \.id) { tag in
                        TagChip(label: tag.name, kind: GuestDisplayFormatting.chipKind(for: tag.category), size: .sm)
                    }
                }
                .frame(width: colTagsWidth, alignment: .leading)
                Spacer().frame(width: 6)
            }

            if showSeiteColumn {
                Text(guest.partnerAssignment.compactDisplayName(for: events.first))
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .lineLimit(1)
                    .frame(width: colSeiteWidth, alignment: .leading)
                Spacer().frame(width: 6)
            }

            if showTischColumn {
                Text(guest.table?.name ?? "—")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(guest.table == nil ? Tokens.Colors.ink3 : Tokens.Colors.ink)
                    .frame(width: colTischWidth, alignment: .leading)
                Spacer().frame(width: 6)
            }

            if showMenuColumn {
                Text(GuestDisplayFormatting.menuLabel(for: guest))
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: colMenuWidth, alignment: .leading)
                Spacer().frame(width: 6)
            }

            if !showFunFactColumn {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? Tokens.Colors.accentTint : .clear)
        .contentShape(Rectangle())
        .onTapGesture {
            handleRowTap(guest: guest)
        }
        .contextMenu {
            Button("Bearbeiten") { editingGuest = guest }
            Button(guest.isPinned ? "Pin lösen" : "Anpinnen") { guest.isPinned.toggle() }
            // FunFact-Status quick-toggle — nur sichtbar wenn ein FunFact da ist
            if !guest.funFact.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(guest.funFactApproved ? "FunFact als unklar markieren" : "FunFact ist ok") {
                    guest.funFactApproved.toggle()
                }
            }
            Button(guest.phoneNumber.isEmpty ? "Telefonnummer aus Kontakten…" : "Telefonnummer ersetzen aus Kontakten…") {
                Task { await importPhoneFromContacts(for: guest) }
            }
            Divider()
            Button("Löschen", role: .destructive) {
                if selectedGuestIDs.contains(guest.id) && selectedGuestIDs.count > 1 {
                    showingDeleteAlert = true
                } else {
                    modelContext.delete(guest)
                    selectedGuestIDs.remove(guest.id)
                }
            }
        }
    }

    private func handleRowTap(guest: Guest) {
        #if os(iOS)
        if selectedGuestIDs.contains(guest.id) {
            selectedGuestIDs.remove(guest.id)
        } else {
            selectedGuestIDs.insert(guest.id)
            anchorGuestID = guest.id
        }
        #else
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift), let anchor = anchorGuestID {
            // Range-Auswahl: alles zwischen anchor und guest in der aktuell sichtbaren
            // Liste markieren — folgt der Reihenfolge die der User sieht.
            let visible = filtering.filteredGuests
            if let aIdx = visible.firstIndex(where: { $0.id == anchor }),
               let bIdx = visible.firstIndex(where: { $0.id == guest.id }) {
                let lo = min(aIdx, bIdx)
                let hi = max(aIdx, bIdx)
                let range = visible[lo...hi].map(\.id)
                selectedGuestIDs.formUnion(range)
            } else {
                selectedGuestIDs.insert(guest.id)
            }
        } else if flags.contains(.command) {
            // Cmd+Klick: einzelnen Eintrag toggeln, Anker bleibt
            if selectedGuestIDs.contains(guest.id) {
                selectedGuestIDs.remove(guest.id)
            } else {
                selectedGuestIDs.insert(guest.id)
                anchorGuestID = guest.id
            }
        } else {
            // Normaler Klick: Single-Select
            selectedGuestIDs = [guest.id]
            anchorGuestID = guest.id
        }
        #endif
    }

    private func deleteSelection() {
        for guest in selectedGuests {
            modelContext.delete(guest)
        }
        selectedGuestIDs.removeAll()
        anchorGuestID = nil
    }

    @MainActor
    private func importPhoneFromContacts(for guest: Guest) async {
        do {
            let granted = try await ContactsService.requestAccess()
            guard granted else {
                contactErrorMessage = ContactsServiceError.accessDenied.errorDescription
                return
            }
            // Sheet immer oeffnen — auch bei 0 Treffern, damit der User
            // selbst weitersuchen kann (Spitzname, Mädchenname etc.).
            let matches = try ContactsService.search(firstName: guest.firstName, lastName: guest.lastName)
            contactPickerMatches = matches
            contactPickerGuest = guest
        } catch let error as ContactsServiceError {
            contactErrorMessage = error.errorDescription
        } catch {
            contactErrorMessage = error.localizedDescription
        }
    }

    /// Wählt alle aktuell sichtbaren (gefilterten) Gäste aus. Macht Filter +
    /// Bulk-Tag zum Two-Step-Massen-Workflow: Filter setzen → "Alle X
    /// auswählen" → Inspector → "Tag hinzufügen" → fertig.
    private func selectAllVisible() {
        let visible = filtering.filteredGuests
        selectedGuestIDs = Set(visible.map(\.id))
        anchorGuestID = visible.first?.id
    }

    /// Erzeugt einen mustSitTogether-Constraint für alle aktuell selektierten
    /// Gäste. Wenn schon ein passender Constraint mit derselben Gäste-Menge
    /// existiert, passiert nichts. Der Constraint wird vom Auto-Sitzplaner
    /// und vom manuellen Drop (placeGuestWithCompanions) respektiert.
    private func linkSelectedAsMustSitTogether() {
        let ids = Array(selectedGuestIDs)
        guard ids.count >= 2 else { return }
        let descriptor = FetchDescriptor<Constraint>()
        if let existing = try? modelContext.fetch(descriptor),
           existing.contains(where: { $0.type == .mustSitTogether && Set($0.guestIDs) == Set(ids) }) {
            return
        }
        let names = ids.compactMap { id in guests.first { $0.id == id }?.firstName }.sorted().joined(separator: " + ")
        let reason = names.isEmpty ? "Manuell verknüpft" : "Müssen zusammen sitzen: \(names)"
        let c = Constraint(type: .mustSitTogether, guestIDs: ids, reason: reason)
        modelContext.insert(c)
        try? modelContext.save()
    }

    // MARK: - FunFact Check

    /// Anzahl Gäste mit unklarem oder fehlendem FunFact — für den Export-
    /// Button-Disable-Status.
    private var funFactWorklistCount: Int {
        guests.filter { g in
            let trimmed = g.funFact.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty || !g.funFactApproved
        }.count
    }

    private enum FunFactExportFormat { case pdf, csv, reminderCSV }

    #if os(macOS)
    /// Exportiert die Liste aller Gäste mit fehlendem oder unbestätigtem
    /// FunFact — pro Gast Vor- und Nachname, derzeitiger FunFact, Status.
    /// Alphabetisch sortiert. PDF mit Erklärung + Beispielen oder CSV
    /// für Excel/Tabelle.
    @MainActor
    private func exportFunFactWorklist(format: FunFactExportFormat) {
        let pending = guests.filter(\.needsFunFactFollowUp).sorted { lhs, rhs in
            if lhs.firstName == rhs.firstName { return lhs.lastName < rhs.lastName }
            return lhs.firstName < rhs.firstName
        }
        guard !pending.isEmpty else { return }

        let title = "FunFact-Liste — \(events.first?.name ?? "Hochzeit")"
        let data: Data
        let suggestedName: String
        let contentType: UTType
        switch format {
        case .pdf:
            data = FunFactWorklistExporter.generatePDF(guests: pending, title: title)
            suggestedName = "FunFact-Liste.pdf"
            contentType = .pdf
        case .csv:
            data = FunFactWorklistCSVExporter.generateCSV(guests: pending)
            suggestedName = "FunFact-Liste.csv"
            contentType = .commaSeparatedText
        case .reminderCSV:
            data = FunFactReminderCSVExporter.generateCSV(guests: pending, event: events.first)
            suggestedName = "FunFact-Erinnerungen.csv"
            contentType = .commaSeparatedText
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
    #endif

    private func runFunFactCheck() {
        funFactCheckProgress = (0, 0)
        funFactCheckTask = Task { @MainActor in
            isCheckingFunFacts = true
            defer {
                isCheckingFunFacts = false
                funFactCheckTask = nil
            }
            let candidates = guests.filter {
                !$0.funFact.trimmingCharacters(in: .whitespaces).isEmpty && !$0.funFactApproved
            }
            guard !candidates.isEmpty else {
                funFactCheckResult = "Alle FunFacts sind bereits bestaetigt."
                return
            }
            let client = LLMClientFactory.makeClient(for: .funfact)
            do {
                let results = try await FunFactValidator.validateBatch(
                    guests: candidates,
                    client: client,
                    onProgress: { done, total in funFactCheckProgress = (done, total) }
                )
                var goodCount = 0
                var genericCount = 0
                for r in results {
                    guard let guest = guests.first(where: { $0.id == r.guestID }) else { continue }
                    switch r.verdict {
                    case .good:
                        guest.funFactApproved = true
                        goodCount += 1
                    case .generic:
                        guest.funFactApproved = false
                        genericCount += 1
                    case .empty:
                        break
                    }
                }
                try? modelContext.save()
                funFactCheckResult = "\(goodCount) FunFacts bestaetigt, \(genericCount) als generisch markiert."
            } catch is CancellationError {
                funFactCheckResult = "Abgebrochen — nichts geändert."
            } catch {
                if Task.isCancelled {
                    funFactCheckResult = "Abgebrochen — nichts geändert."
                } else {
                    funFactCheckResult = "Fehler: \(error.localizedDescription)"
                }
            }
        }
    }

    private func runFunFactNormalize() {
        funFactProgress = (0, 0)
        funFactTask = Task { @MainActor in
            isNormalizingFunFacts = true
            defer {
                isNormalizingFunFacts = false
                funFactTask = nil
            }
            let client = LLMClientFactory.makeClient(for: .funfact)
            do {
                let proposals = try await FunFactNormalizer.proposeBatch(
                    guests: Array(guests),
                    client: client,
                    onProgress: { done, total in funFactProgress = (done, total) }
                )
                guard !proposals.isEmpty else {
                    funFactCheckResult = "Die KI hat keine Vorschläge geliefert (Antwort leer)."
                    return
                }
                let changed = proposals.filter {
                    $0.original.trimmingCharacters(in: .whitespacesAndNewlines)
                        != $0.normalized.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard !changed.isEmpty else {
                    funFactCheckResult = "KI lieferte \(proposals.count) Antworten, aber 0 Änderungen "
                        + "— das Modell hat die Texte unverändert zurückgegeben (zu schwach für die Aufgabe)."
                    return
                }
                funFactProposals = changed
                funFactProposalSelection = Set(changed.map(\.guestID))
                showingFunFactReview = true
            } catch is CancellationError {
                funFactCheckResult = "Abgebrochen — nichts geändert."
            } catch {
                if Task.isCancelled {
                    funFactCheckResult = "Abgebrochen — nichts geändert."
                } else {
                    funFactCheckResult = "Fehler: \(error.localizedDescription)"
                }
            }
        }
    }

    private func applyFunFactProposals() {
        for proposal in funFactProposals where funFactProposalSelection.contains(proposal.guestID) {
            guard let guest = guests.first(where: { $0.id == proposal.guestID }) else { continue }
            // Rohdaten (funFact) bleiben unangetastet — nur die
            // vereinheitlichte Fassung wird gesetzt. Approval-Status bleibt:
            // Normalisierung ändert die Aussage nicht, nur die Formulierung.
            guest.funFactNormalized = proposal.normalized
        }
        try? modelContext.save()
        showingFunFactReview = false
        funFactProposals = []
    }
}
#endif
