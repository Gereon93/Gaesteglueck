import Foundation

/// Reine Filter-, Gruppierungs- und Zähl-Logik der Gästeliste (S3).
///
/// Extrahiert aus `GuestListView`, damit die nicht-triviale Logik (smarte
/// „Unzugeordnet"-Filterung über Anmeldegruppen, Familien-Kontext beim
/// Filtern, Anmelde-Sektionen, FunFact-/Telefon-Zähler) ohne SwiftUI
/// testbar ist. Der Typ hält keinen UI-State, nur die Eingaben — Gäste,
/// Tags und die aktiven Filter — und berechnet daraus die sichtbare Liste,
/// die Sektionen und alle Filter-Zähler. Verhalten ist 1:1 wie zuvor in
/// der View.
struct GuestListFiltering {
    let guests: [Guest]
    let tags: [Tag]
    let searchText: String
    let sideFilter: PartnerAssignment?
    let tagFilter: TagCategory?
    let statusFilter: StatusFilter?
    let ageFilter: AgeCategory?

    init(
        guests: [Guest],
        tags: [Tag],
        searchText: String = "",
        sideFilter: PartnerAssignment? = nil,
        tagFilter: TagCategory? = nil,
        statusFilter: StatusFilter? = nil,
        ageFilter: AgeCategory? = nil
    ) {
        self.guests = guests
        self.tags = tags
        self.searchText = searchText
        self.sideFilter = sideFilter
        self.tagFilter = tagFilter
        self.statusFilter = statusFilter
        self.ageFilter = ageFilter
    }

    enum StatusFilter: String, CaseIterable, Hashable {
        case assigned = "Tisch zugewiesen"
        case unassigned = "Ohne Tisch"
        case pinned = "Gepinnt"
        case allergies = "Allergie"
        case funfactGood = "FunFact ok"
        case funfactPending = "FunFact unklar"
        case funfactEmpty = "FunFact fehlt"
        case phoneSet = "Telefon ok"
        case phoneMissing = "Telefon fehlt"
    }

    struct RegistrationSection: Identifiable {
        let id: String
        let label: String
        let isBridal: Bool
        let guests: [Guest]
        /// Gäste die zwar zur Anmeldung gehören aber AKTUELL durch den Filter
        /// fallen — werden gedimmt mitgerendert damit Familienkontext sichtbar
        /// bleibt. Leer wenn kein Filter aktiv ist.
        let dimmedGuests: [Guest]
    }

    var hasActiveFilter: Bool {
        sideFilter != nil || tagFilter != nil || statusFilter != nil || ageFilter != nil || !searchText.isEmpty
    }

    /// Wenn ein FunFact-Filter aktiv ist, NICHT nach Anmeldegruppen
    /// gruppieren — der User soll jeden einzelnen Gast durchgehen koennen.
    var isFunFactFilterActive: Bool {
        switch statusFilter {
        case .funfactGood, .funfactPending, .funfactEmpty: return true
        default: return false
        }
    }

    var filteredGuests: [Guest] {
        // Vorberechnung: welche registrationGroups haben mindestens ein
        // Mitglied das schon eine Seite (Alice/Bob/Beide) hat? Solche
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
                case .funfactGood:
                    if !guest.funFactApproved || guest.funFact.trimmingCharacters(in: .whitespaces).isEmpty { return false }
                case .funfactPending:
                    if guest.funFactApproved || guest.funFact.trimmingCharacters(in: .whitespaces).isEmpty { return false }
                case .funfactEmpty:
                    if !guest.funFact.trimmingCharacters(in: .whitespaces).isEmpty { return false }
                case .phoneSet:
                    if guest.phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty { return false }
                case .phoneMissing:
                    if !guest.phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty { return false }
                    if registrationGroupHasPhone(for: guest) { return false }
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

    var registrationSections: [RegistrationSection] {
        let filtered = filteredGuests
        let filteredIDs = Set(filtered.map(\.id))

        // Bei FunFact-Filter: flache alphabetische Liste, keine Gruppen
        if isFunFactFilterActive {
            let flat = filtered.sorted { lhs, rhs in
                if lhs.firstName == rhs.firstName { return lhs.lastName < rhs.lastName }
                return lhs.firstName < rhs.firstName
            }
            return flat.isEmpty ? [] : [RegistrationSection(
                id: "funfact-flat",
                label: "Alle (\(flat.count))",
                isBridal: false,
                guests: flat,
                dimmedGuests: []
            )]
        }

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

    func sectionLabel(for members: [Guest]) -> String {
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

    /// Zählt Gäste pro Tag-Kategorie — für `.family` werden zusätzlich Gäste
    /// mit gepflegter Familienrolle gezählt (Vater, Mutter, Onkel, Cousine,
    /// …), weil das die eigentliche Quelle der Wahrheit für Familie ist.
    func tagCategoryCount(_ cat: TagCategory) -> Int {
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
    func countForSide(_ side: PartnerAssignment) -> Int {
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

    func countForStatus(_ status: StatusFilter) -> Int {
        switch status {
        case .assigned: guests.filter { $0.table != nil }.count
        case .unassigned: guests.filter { $0.table == nil }.count
        case .pinned: guests.filter { $0.isPinned }.count
        case .allergies: guests.filter { $0.hasIntolerances }.count
        case .funfactGood: guests.filter { $0.funFactApproved && !$0.funFact.trimmingCharacters(in: .whitespaces).isEmpty }.count
        case .funfactPending: guests.filter { !$0.funFactApproved && !$0.funFact.trimmingCharacters(in: .whitespaces).isEmpty }.count
        case .funfactEmpty: guests.filter { $0.funFact.trimmingCharacters(in: .whitespaces).isEmpty }.count
        case .phoneSet: guests.filter { !$0.phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty }.count
        case .phoneMissing: guests.filter { g in
            g.phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
                && !registrationGroupHasPhone(for: g)
        }.count
        }
    }

    /// True wenn jemand aus der gleichen Anmeldungs-Gruppe bereits eine
    /// Telefonnummer hinterlegt hat — pro Anmeldung reicht eine Nummer.
    func registrationGroupHasPhone(for guest: Guest) -> Bool {
        guard let group = guest.registrationGroup else { return false }
        return guests.contains { peer in
            peer.id != guest.id
                && peer.registrationGroup == group
                && !peer.phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
}
