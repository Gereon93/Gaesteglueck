#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

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

    private var primarySelectedGuest: Guest? {
        selectedGuests.count == 1 ? selectedGuests.first : nil
    }

    @State private var sideFilter: PartnerAssignment? = nil
    @State private var tagFilter: TagCategory? = nil
    @State private var statusFilter: StatusFilter? = nil
    @State private var ageFilter: AgeCategory? = nil

    enum StatusFilter: String, CaseIterable, Hashable {
        case assigned = "Tisch zugewiesen"
        case unassigned = "Ohne Tisch"
        case pinned = "Gepinnt"
        case allergies = "Allergie"
    }

    private struct RegistrationSection: Identifiable {
        let id: String
        let label: String
        let isBridal: Bool
        let guests: [Guest]
        /// Gäste die zwar zur Anmeldung gehören aber AKTUELL durch den Filter
        /// fallen — werden gedimmt mitgerendert damit Familienkontext sichtbar
        /// bleibt. Leer wenn kein Filter aktiv ist.
        let dimmedGuests: [Guest]
    }

    private var hasActiveFilter: Bool {
        sideFilter != nil || tagFilter != nil || statusFilter != nil || ageFilter != nil || !searchText.isEmpty
    }

    private var registrationSections: [RegistrationSection] {
        let filtered = filteredGuests
        let filteredIDs = Set(filtered.map(\.id))

        // Brautpaar identifizieren — entweder via Tag "Brautpaar" oder als
        // Mitglieder einer Constraint mit reason "Brautpaar".
        let brautpaarTag = tags.first { $0.name == "Brautpaar" }
        let bridalIDs = Set(brautpaarTag?.guestIDs ?? [])

        var sections: [RegistrationSection] = []

        // Brautpaar zuerst — beim Brautpaar zeigen wir bei Filter beide oder
        // keinen, kein Gedimme nötig.
        let bridal = filtered.filter { bridalIDs.contains($0.id) }
            .sorted { $0.firstName < $1.firstName }
        if !bridal.isEmpty {
            sections.append(RegistrationSection(
                id: "brautpaar",
                label: "Brautpaar",
                isBridal: true,
                guests: bridal,
                dimmedGuests: []
            ))
        }

        // Anderen Gäste nach registrationGroup gruppieren — diesmal aus dem
        // VOLLSTÄNDIGEN Datensatz, damit Familienmitglieder die durchs Filter
        // fallen trotzdem als Kontext mitsichtbar bleiben (z.B. Heike Becker
        // taucht in einem Fasching-Tag-Filter neben Clara Stein auf).
        let allNonBridal = guests.filter { !bridalIDs.contains($0.id) }
        let allWithGroup = allNonBridal.filter { $0.registrationGroup != nil }
        let groupedDict = Dictionary(grouping: allWithGroup) { $0.registrationGroup! }
        let sortedGroups = groupedDict.sorted { lhs, rhs in
            sectionLabel(for: lhs.value) < sectionLabel(for: rhs.value)
        }
        for (groupID, members) in sortedGroups {
            let matching = members.filter { filteredIDs.contains($0.id) }
            // Gruppen ohne einen einzigen Treffer ausblenden — sonst sieht der
            // User bei aktivem Filter sein gesamtes Dataset als gedimmt.
            guard !matching.isEmpty else { continue }
            let dimmed = members.filter { !filteredIDs.contains($0.id) }
            sections.append(RegistrationSection(
                id: groupID.uuidString,
                label: sectionLabel(for: members),
                isBridal: false,
                guests: matching.sorted { $0.firstName < $1.firstName },
                dimmedGuests: dimmed.sorted { $0.firstName < $1.firstName }
            ))
        }

        // Einzeln hinzugefügte am Ende
        let nonBridalFiltered = filtered.filter { !bridalIDs.contains($0.id) }
        let withoutGroup = nonBridalFiltered.filter { $0.registrationGroup == nil }
        if !withoutGroup.isEmpty {
            sections.append(RegistrationSection(
                id: "standalone",
                label: "Einzeln hinzugefügt",
                isBridal: false,
                guests: withoutGroup.sorted { $0.firstName < $1.firstName },
                dimmedGuests: []
            ))
        }

        return sections
    }

    private func sectionLabel(for members: [Guest]) -> String {
        let lastNames = members.map { $0.lastName }.filter { !$0.isEmpty }
        let counts = Dictionary(grouping: lastNames, by: { $0 }).mapValues(\.count)
        if let maxCount = counts.values.max() {
            // Alle Nachnamen die gleichhäufig vorkommen — wenn nur einer
            // dominiert: "Familie Müller". Bei Mehrfach-Nachnamen-Anmeldungen
            // (Stein + Becker als Paar/Wohngemeinschaft): alphabetisch
            // sortiert beide. Ohne sort wäre die Anzeige nicht-deterministisch
            // weil Dictionary-Reihenfolge wechselt — der Header würde beim
            // Anklicken eines Gastes "toggeln".
            let topNames = counts.filter { $0.value == maxCount }.keys.sorted()
            if topNames.count == 1 {
                return "Familie \(topNames[0])"
            }
            // Bei zwei kombinierten Familien: "Stein & Becker"
            return topNames.joined(separator: " & ")
        }
        let firstNames = members.map(\.firstName).prefix(3).joined(separator: " & ")
        return firstNames.isEmpty ? "Anmeldung" : firstNames
    }

    private var filteredGuests: [Guest] {
        // Vorberechnung: welche registrationGroups haben mindestens ein
        // Mitglied das schon eine Seite (Maria/Gereon/Beide) hat? Solche
        // Anmeldungen blenden wir beim "Unzugeordnet"-Filter komplett aus —
        // weil ein zugeordnetes Familienmitglied via mustSitTogether-Constraint
        // den Rest der Familie zum gleichen Tisch zieht. Es gibt also
        // keinen echten "Unzugeordnet"-Action-Item mehr für diese Familie.
        let groupsWithAnyAssignment: Set<UUID> = Set(
            guests
                .filter { $0.partnerAssignment != .unassigned && $0.registrationGroup != nil }
                .compactMap(\.registrationGroup)
        )

        return guests.filter { guest in
            if let sideFilter {
                if sideFilter == .unassigned {
                    if guest.partnerAssignment != .unassigned { return false }
                    if let group = guest.registrationGroup,
                       groupsWithAnyAssignment.contains(group) {
                        // Familienkollege schon zugeordnet → Anmeldung zählt
                        // nicht mehr als offen.
                        return false
                    }
                } else if guest.partnerAssignment != sideFilter {
                    return false
                }
            }
            if let statusFilter {
                switch statusFilter {
                case .assigned where guest.table == nil: return false
                case .unassigned where guest.table != nil: return false
                case .pinned where !guest.isPinned: return false
                case .allergies where !guest.hasIntolerances: return false
                default: break
                }
            }
            if let tagFilter {
                let guestTags = tags.filter { $0.guestIDs.contains(guest.id) }
                let hasMatchingTag = guestTags.contains(where: { $0.category == tagFilter })
                // Spezialfall Familie: Familienrolle am Gast (Vater, Mutter,
                // Onkel, Cousine, …) zählt auch als "Familie" — sonst würde
                // der Filter blutsverwandte Personen verstecken nur weil sie
                // keinen expliziten Family-Tag haben (Family-Tags werden
                // bewusst NICHT erzeugt, weil familyRole die Wahrheit ist).
                let hasFamilyRoleMatch = tagFilter == .family && guest.familyRole != nil
                if !hasMatchingTag && !hasFamilyRoleMatch { return false }
            }
            if let ageFilter, guest.ageCategory != ageFilter { return false }
            if !searchText.isEmpty {
                return guest.fullName.localizedCaseInsensitiveContains(searchText)
            }
            return true
        }
    }

    var body: some View {
        ZStack {
            Tokens.Colors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar
                HStack(spacing: 0) {
                    filterRail
                        .frame(width: 200)
                    Divider().background(Tokens.Colors.line)
                    guestTable
                        .frame(maxWidth: .infinity)
                    Divider().background(Tokens.Colors.line)
                    inspectorPane
                        .frame(width: 300)
                }
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
        .alert("\(selectedGuestIDs.count) Gäste löschen?", isPresented: $showingDeleteAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                deleteSelection()
            }
        } message: {
            Text("Diese Aktion lässt sich nicht rückgängig machen. Tische und Tags bleiben bestehen.")
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
            } else if hasActiveFilter, !filteredGuests.isEmpty {
                // Wenn nichts ausgewählt aber ein Filter aktiv ist → Quick-
                // Action zum Massen-Selektieren des sichtbaren Bereichs.
                // Workflow: Filter side=Gereon + tag=Freundesgruppe → klick
                // "Alle X auswählen" → im Inspector "Tag hinzufügen" mit
                // "Geburtstag Gereon".
                Button {
                    selectAllVisible()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                        Text("Alle \(filteredGuests.count) auswählen")
                    }
                }
                .warmButton(.secondary)
            }
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

    /// Zählt Gäste pro Tag-Kategorie — für `.family` werden zusätzlich Gäste
    /// mit gepflegter Familienrolle gezählt (Vater, Mutter, Onkel, Cousine,
    /// …), weil das die eigentliche Quelle der Wahrheit für Familie ist.
    private func tagCategoryCount(_ cat: TagCategory) -> Int {
        let taggedIDs = Set(tags.filter { $0.category == cat }.flatMap { $0.guestIDs })
        if cat == .family {
            let familyRoleIDs = Set(guests.filter { $0.familyRole != nil }.map(\.id))
            return taggedIDs.union(familyRoleIDs).count
        }
        return taggedIDs.count
    }

    /// Zählt Gäste pro Seite — für "Unzugeordnet" wird die schlaue Filter-
    /// Logik angewendet: nur Gäste deren Anmeldungsgruppe komplett offen ist
    /// werden als echte Action-Items gezählt. Sonst wäre die Zahl `26` während
    /// die Liste leer ist (weil alle 26 via Familie automatisch mitgehen).
    private func countForSide(_ side: PartnerAssignment) -> Int {
        if side == .unassigned {
            let groupsWithAnyAssignment: Set<UUID> = Set(
                guests
                    .filter { $0.partnerAssignment != .unassigned && $0.registrationGroup != nil }
                    .compactMap(\.registrationGroup)
            )
            return guests.filter { g in
                guard g.partnerAssignment == .unassigned else { return false }
                if let group = g.registrationGroup,
                   groupsWithAnyAssignment.contains(group) { return false }
                return true
            }.count
        }
        return guests.filter { $0.partnerAssignment == side }.count
    }

    // MARK: - Filter Rail

    private var filterRail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                filterGroup("Seite") {
                    filterChip(
                        label: "Alle",
                        count: guests.count,
                        active: sideFilter == nil,
                        action: { sideFilter = nil }
                    )
                    ForEach(PartnerAssignment.allCases) { side in
                        filterChip(
                            label: side.displayName(for: events.first),
                            count: countForSide(side),
                            active: sideFilter == side,
                            dotColor: side.color,
                            action: { sideFilter = sideFilter == side ? nil : side }
                        )
                    }
                }

                if !tags.isEmpty || guests.contains(where: { $0.familyRole != nil }) {
                    filterGroup("Tag-Kategorien") {
                        ForEach(TagCategory.allCases) { cat in
                            let count = tagCategoryCount(cat)
                            if count > 0 {
                                filterChip(
                                    label: cat.rawValue,
                                    count: count,
                                    active: tagFilter == cat,
                                    dotColor: tagDotColor(for: cat),
                                    action: { tagFilter = tagFilter == cat ? nil : cat }
                                )
                            }
                        }
                    }
                }

                let ageCounts: [(AgeCategory, Int)] = AgeCategory.allCases.map { age in
                    (age, guests.filter { $0.ageCategory == age }.count)
                }
                if ageCounts.contains(where: { $0.1 > 0 }) {
                    filterGroup("Alter") {
                        ForEach(AgeCategory.allCases) { age in
                            let c = ageCounts.first(where: { $0.0 == age })?.1 ?? 0
                            if c > 0 {
                                filterChip(
                                    label: age.rawValue,
                                    count: c,
                                    active: ageFilter == age,
                                    action: { ageFilter = ageFilter == age ? nil : age }
                                )
                            }
                        }
                    }
                }

                filterGroup("Status") {
                    ForEach(StatusFilter.allCases, id: \.self) { status in
                        let count = countForStatus(status)
                        filterChip(
                            label: status.rawValue,
                            count: count,
                            active: statusFilter == status,
                            action: { statusFilter = statusFilter == status ? nil : status }
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
        .background(Tokens.Colors.bg2)
    }

    private func filterGroup<Content: View>(_ label: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.6)
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 2) {
                content()
            }
        }
    }

    private func filterChip(
        label: String,
        count: Int,
        active: Bool,
        dotColor: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 7, height: 7)
                }
                Text(label)
                    .font(.system(size: 12.5, weight: active ? .medium : .regular, design: .rounded))
                    .foregroundStyle(active ? Tokens.Colors.ink : Tokens.Colors.ink2)
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(active ? Tokens.Colors.accentSoft : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tagDotColor(for category: TagCategory) -> Color {
        switch category {
        case .family: Tokens.Colors.tagFamily
        case .friendGroup: Tokens.Colors.tagFriends
        case .role: Tokens.Colors.tagRole
        case .activity: Tokens.Colors.tagActivity
        case .work: Tokens.Colors.tagWork
        case .custom: Tokens.Colors.tagCustom
        }
    }

    private func countForStatus(_ status: StatusFilter) -> Int {
        switch status {
        case .assigned: guests.filter { $0.table != nil }.count
        case .unassigned: guests.filter { $0.table == nil }.count
        case .pinned: guests.filter { $0.isPinned }.count
        case .allergies: guests.filter { $0.hasIntolerances }.count
        }
    }

    // MARK: - Guest Table

    private var guestTable: some View {
        VStack(spacing: 0) {
            if filteredGuests.isEmpty {
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
                        ForEach(registrationSections) { section in
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
        .searchable(text: $searchText, prompt: "Gäste suchen")
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

    private func sectionHeader(_ section: RegistrationSection) -> some View {
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
            tableHeaderCell("Name", width: nil)
                .frame(maxWidth: .infinity, alignment: .leading)
            tableHeaderCell("Tags", width: 220)
            tableHeaderCell("Seite", width: 80)
            tableHeaderCell("Tisch", width: 80)
            tableHeaderCell("Menü", width: 120)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Tokens.Colors.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Colors.line).frame(height: 1)
        }
    }

    private func tableHeaderCell(_ label: String, width: CGFloat?) -> some View {
        Text(label.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Tokens.Colors.ink3)
            .tracking(0.5)
            .frame(width: width, alignment: .leading)
    }

    private func guestRow(guest: Guest) -> some View {
        let isSelected = selectedGuestIDs.contains(guest.id)
        let avatarTag = avatarKind(for: guest)

        return HStack(spacing: 0) {
            HStack(spacing: 10) {
                Avatar(name: guest.fullName, size: 28, tag: avatarTag,
                       diet: dietBadge(for: guest), pinned: guest.isPinned)
                VStack(alignment: .leading, spacing: 1) {
                    Text(guest.fullName)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ChipFlowLayout(spacing: 4) {
                let guestTags = tags.filter { $0.guestIDs.contains(guest.id) }
                ForEach(guestTags, id: \.id) { tag in
                    TagChip(label: tag.name, kind: chipKind(for: tag.category), size: .sm)
                }
            }
            .frame(width: 220, alignment: .leading)

            Text(guest.partnerAssignment.compactDisplayName(for: events.first))
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .lineLimit(1)
                .frame(width: 80, alignment: .leading)

            Text(guest.table?.name ?? "—")
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(guest.table == nil ? Tokens.Colors.ink3 : Tokens.Colors.ink)
                .frame(width: 80, alignment: .leading)

            Text(menuLabel(for: guest))
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 120, alignment: .leading)
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
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift), let anchor = anchorGuestID {
            // Range-Auswahl: alles zwischen anchor und guest in der aktuell sichtbaren
            // Liste markieren — folgt der Reihenfolge die der User sieht.
            let visible = filteredGuests
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
    }

    private func deleteSelection() {
        for guest in selectedGuests {
            modelContext.delete(guest)
        }
        selectedGuestIDs.removeAll()
        anchorGuestID = nil
    }

    private func avatarKind(for guest: Guest) -> Avatar.TagKind {
        let firstTag = tags.first { $0.guestIDs.contains(guest.id) }
        return firstTag.map { chipKindToAvatar(chipKind(for: $0.category)) } ?? .custom
    }

    private func chipKind(for category: TagCategory) -> TagChip.Kind {
        switch category {
        case .family: .family
        case .friendGroup: .friends
        case .role: .role
        case .activity: .activity
        case .work: .work
        case .custom: .custom
        }
    }

    private func chipKindToAvatar(_ kind: TagChip.Kind) -> Avatar.TagKind {
        switch kind {
        case .family: .family
        case .friends: .friends
        case .role: .role
        case .activity: .activity
        case .work: .work
        case .custom: .custom
        }
    }

    private func dietBadge(for guest: Guest) -> Avatar.DietBadge? {
        if guest.hasIntolerances { return .allergie }
        switch guest.dietaryChoice.lowercased() {
        case "vegetarisch": return .veg
        case "vegan": return .vegan
        default: return nil
        }
    }

    private func menuLabel(for guest: Guest) -> String {
        if guest.hasIntolerances {
            return "\(guest.dietaryChoice) · \(guest.intolerances.first ?? "Allergie")"
        }
        return guest.dietaryChoice
    }

    // MARK: - Inspector

    @ViewBuilder
    private var inspectorPane: some View {
        if selectedGuestIDs.count >= 2 {
            multiSelectInspector
        } else if let guest = primarySelectedGuest {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    inspectorHeader(guest)

                    InspectorSection("Tags") {
                        let guestTags = tags.filter { $0.guestIDs.contains(guest.id) }
                        if guestTags.isEmpty {
                            Text("Noch keine Tags")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink3)
                        } else {
                            ChipFlowLayout(spacing: 5) {
                                ForEach(guestTags) { tag in
                                    TagChip(label: tag.name, kind: chipKind(for: tag.category), size: .sm)
                                }
                            }
                        }
                    }

                    InspectorSection("Sitzplan") {
                        if let table = guest.table {
                            HStack(spacing: 8) {
                                Circle().fill(Tokens.Colors.accent).frame(width: 8, height: 8)
                                Text(table.name)
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(Tokens.Colors.ink)
                            }
                            if guest.isPinned {
                                Text("Gepinnt — bleibt auch bei KI-Vorschlägen an diesem Tisch.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Tokens.Colors.ink2)
                                    .lineSpacing(2)
                                    .padding(.top, 4)
                            }
                            Button(guest.isPinned ? "Pin lösen" : "Anpinnen") {
                                guest.isPinned.toggle()
                            }
                            .warmButton(.secondary, size: .sm)
                            .padding(.top, 8)
                        } else {
                            Text("Noch keinem Tisch zugewiesen.")
                                .font(.system(size: 12.5, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink3)
                        }
                    }

                    InspectorSection("Familienrolle") {
                        familyRoleSummary(for: guest)
                    }

                    if !guest.notes.isEmpty {
                        InspectorSection("Notizen") {
                            Text(guest.notes)
                                .font(.system(size: 12.5, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink2)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    InspectorSection("Menü & Allergien") {
                        VStack(alignment: .leading, spacing: 6) {
                            inspectorRow("Menüwahl", guest.dietaryChoice)
                            inspectorRow("Allergien", guest.hasIntolerances ? guest.intolerances.joined(separator: ", ") : "Keine")
                            if !guest.funFact.isEmpty {
                                inspectorRow("Fun Fact", guest.funFact)
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        Button("Bearbeiten") { editingGuest = guest }
                            .warmButton(.secondary, size: .sm)
                        Button("Löschen", role: .destructive) {
                            modelContext.delete(guest)
                            selectedGuestIDs.remove(guest.id)
                        }
                        .warmButton(.ghost, size: .sm)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
            }
            .background(Tokens.Colors.bg2)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 32))
                    .foregroundStyle(Tokens.Colors.ink4)
                Text("Wähle einen Gast")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                Text("Klick einen Gast in der Liste an, um Details zu sehen.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 200)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Colors.bg2)
        }
    }

    /// Tag-Mass-Operations für die aktuelle Mehrfach-Auswahl. Zwei Menüs:
    /// hinzufügen (alle Tags, gruppiert nach Kategorie) und entfernen
    /// (nur Tags die mindestens ein selektierter Gast aktuell hat).
    @ViewBuilder
    private var bulkTagControls: some View {
        let currentTags = tagsOnAnyOfSelection()
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                let grouped = Dictionary(grouping: tags, by: \.category)
                ForEach(TagCategory.allCases) { cat in
                    if let inCat = grouped[cat], !inCat.isEmpty {
                        Section(cat.rawValue) {
                            ForEach(inCat.sorted(by: { $0.name < $1.name })) { tag in
                                Button {
                                    addTagToSelection(tag)
                                } label: {
                                    HStack {
                                        Circle().fill(Color(hex: tag.color)).frame(width: 8, height: 8)
                                        Text(tag.name)
                                        if let pa = tag.partnerAssignment, pa != .unassigned {
                                            Text("· \(pa.compactDisplayName(for: events.first))")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                    Text("Tag hinzufügen…")
                }
                .frame(maxWidth: .infinity)
            }
            .menuStyle(.borderlessButton)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Tokens.Colors.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Tokens.Colors.line, lineWidth: 1))

            Menu {
                if currentTags.isEmpty {
                    Text("Keiner der Gäste hat aktuell Tags.")
                } else {
                    ForEach(currentTags.sorted(by: { $0.name < $1.name })) { tag in
                        Button {
                            removeTagFromSelection(tag)
                        } label: {
                            HStack {
                                Circle().fill(Color(hex: tag.color)).frame(width: 8, height: 8)
                                Text(tag.name)
                                Text("· \(membersInSelection(of: tag).count)/\(selectedGuestIDs.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "minus.circle")
                    Text("Tag entfernen…")
                }
                .frame(maxWidth: .infinity)
            }
            .menuStyle(.borderlessButton)
            .disabled(currentTags.isEmpty)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Tokens.Colors.surface)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Tokens.Colors.line, lineWidth: 1))

            if !currentTags.isEmpty {
                Text("\(currentTags.count) Tag\(currentTags.count == 1 ? "" : "s") aktuell auf min. einem Gast — Anteil zeigt 'X/Y' (X von Y haben den Tag).")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Wählt alle aktuell sichtbaren (gefilterten) Gäste aus. Macht Filter +
    /// Bulk-Tag zum Two-Step-Massen-Workflow: Filter setzen → "Alle X
    /// auswählen" → Inspector → "Tag hinzufügen" → fertig.
    private func selectAllVisible() {
        selectedGuestIDs = Set(filteredGuests.map(\.id))
        anchorGuestID = filteredGuests.first?.id
    }

    private func tagsOnAnyOfSelection() -> [Tag] {
        tags.filter { tag in
            tag.guestIDs.contains(where: { selectedGuestIDs.contains($0) })
        }
    }

    private func membersInSelection(of tag: Tag) -> [UUID] {
        tag.guestIDs.filter { selectedGuestIDs.contains($0) }
    }

    private func addTagToSelection(_ tag: Tag) {
        // Bewusst KEIN Side-Auto-Derive beim Massen-Tag-Zuweisen — der
        // User markiert evtl. die "Schwiegermutter Maria" als Mitglied
        // eines neutralen Tags ohne damit ihre Zuordnung zu Marias Seite
        // ändern zu wollen. Side bleibt wie sie ist; ggf. einzeln im Edit-
        // Sheet anpassen.
        for id in selectedGuestIDs where !tag.guestIDs.contains(id) {
            tag.guestIDs.append(id)
        }
    }

    private func removeTagFromSelection(_ tag: Tag) {
        tag.guestIDs.removeAll { selectedGuestIDs.contains($0) }
    }

    /// Familienrolle + Seite in einer Zeile für den Inspector. „Vater von
    /// Gereon", „Schwester von Maria", oder dezenter Hinweis wenn nichts
    /// gepflegt ist (mit Quick-Edit-Button).
    @ViewBuilder
    private func familyRoleSummary(for guest: Guest) -> some View {
        if let role = guest.familyRole {
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.Colors.ink3)
                Text(familyRoleLabel(role: role, guest: guest))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
            }
        } else {
            HStack(spacing: 6) {
                Text("Keine Familienrolle gesetzt")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                Spacer()
                Button("Setzen") { editingGuest = guest }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.accent)
            }
        }
    }

    private func familyRoleLabel(role: FamilyRole, guest: Guest) -> String {
        let event = events.first
        let side = guest.familyRolePartner ?? guest.partnerAssignment.optionalSelf
        if let side {
            return "\(role.rawValue) von \(side.compactDisplayName(for: event))"
        }
        return role.rawValue
    }

    private var multiSelectInspector: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MEHRFACH AUSGEWÄHLT")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .tracking(0.5)
                Text("\(selectedGuestIDs.count) Gäste")
                    .font(Tokens.Typography.displayS)
                    .foregroundStyle(Tokens.Colors.ink)
                Text("Mit Shift+Klick erweiterst du die Auswahl, mit Cmd+Klick wechselst du einzelne. Drück Delete oder klick unten zum Löschen.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .lineSpacing(2)
                    .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Tokens.Colors.line).frame(height: 1)
            }

            InspectorSection("Auswahl-Übersicht") {
                let breakdown = selectionBreakdown
                VStack(alignment: .leading, spacing: 6) {
                    inspectorPropRow("Gepinnt", "\(breakdown.pinned)")
                    inspectorPropRow("Mit Allergie", "\(breakdown.allergies)")
                    inspectorPropRow("Bereits am Tisch", "\(breakdown.assigned)")
                    inspectorPropRow("Kinder", "\(breakdown.kids)")
                }
            }

            InspectorSection("Tags für die Auswahl") {
                bulkTagControls
            }

            VStack(spacing: 8) {
                Button {
                    showingDeleteAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("\(selectedGuestIDs.count) Gäste löschen")
                    }
                    .frame(maxWidth: .infinity)
                }
                .warmButton(.secondary)
                .foregroundStyle(Tokens.Colors.error)

                Button("Auswahl aufheben") {
                    selectedGuestIDs.removeAll()
                    anchorGuestID = nil
                }
                .warmButton(.ghost)
            }
            .padding(20)
        }
        .background(Tokens.Colors.bg2)
    }

    private struct SelectionBreakdown {
        let pinned: Int
        let allergies: Int
        let assigned: Int
        let kids: Int
    }

    private var selectionBreakdown: SelectionBreakdown {
        let s = selectedGuests
        return SelectionBreakdown(
            pinned: s.filter(\.isPinned).count,
            allergies: s.filter(\.hasIntolerances).count,
            assigned: s.filter { $0.table != nil }.count,
            kids: s.filter { $0.ageCategory != .adult }.count
        )
    }

    private func inspectorPropRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
                .monospacedDigit()
        }
    }

    private func inspectorHeader(_ guest: Guest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Avatar(name: guest.fullName, size: 64,
                   tag: avatarKind(for: guest),
                   diet: dietBadge(for: guest),
                   pinned: guest.isPinned)
            VStack(alignment: .leading, spacing: 2) {
                Text(guest.fullName)
                    .font(Tokens.Typography.displayS)
                    .foregroundStyle(Tokens.Colors.ink)
                Text(guestSubline(guest))
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func guestSubline(_ guest: Guest) -> String {
        var parts: [String] = []
        parts.append(guest.partnerAssignment.displayName(for: events.first))
        if guest.ageCategory != .adult {
            parts.append(guest.ageCategory.rawValue)
        }
        if let age = guest.age {
            parts.append("\(age) Jahre")
        }
        return parts.joined(separator: " · ")
    }

    private func inspectorRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .frame(width: 80, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Simple flow layout for tag chips

private struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if rowWidth + s.width > width, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        totalHeight += rowHeight
        return CGSize(width: width.isFinite ? width : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}
#endif
