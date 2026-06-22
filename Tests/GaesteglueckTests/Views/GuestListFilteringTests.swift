import Testing
import Foundation
@testable import Gaesteglueck

/// Sicherheitsnetz für die aus `GuestListView` extrahierte Filter-/
/// Gruppierungs-/Zähl-Logik. Pinnt das Verhalten fest, damit das
/// Aufteilen der View nichts still kaputtmacht.
@Suite("GuestListFiltering")
struct GuestListFilteringTests {

    // MARK: - Helpers

    private func guest(
        _ first: String,
        _ last: String = "",
        side: PartnerAssignment = .unassigned,
        group: UUID? = nil,
        age: AgeCategory = .adult,
        familyRole: FamilyRole? = nil,
        funFact: String = "",
        approved: Bool = false,
        phone: String = "",
        intolerances: [String] = [],
        pinned: Bool = false,
        seated: Bool = false
    ) -> Guest {
        let g = Guest(
            firstName: first,
            lastName: last,
            partnerAssignment: side,
            ageCategory: age,
            familyRole: familyRole,
            intolerances: intolerances,
            funFact: funFact,
            registrationGroup: group
        )
        g.funFactApproved = approved
        g.phoneNumber = phone
        g.isPinned = pinned
        if seated {
            g.table = GuestTable(name: "T", shape: .round, diameter: 180)
        }
        return g
    }

    private func tag(_ name: String, _ category: TagCategory, guests: [Guest]) -> Gaesteglueck.Tag {
        let t = Gaesteglueck.Tag(name: name, category: category)
        t.guestIDs = guests.map(\.id)
        return t
    }

    // MARK: - filteredGuests

    @Test("Ohne Filter sind alle Gäste sichtbar")
    func noFilterShowsAll() {
        let g = [guest("Anna"), guest("Bob"), guest("Cara")]
        let f = GuestListFiltering(guests: g, tags: [])
        #expect(f.filteredGuests.count == 3)
        #expect(!f.hasActiveFilter)
    }

    @Test("Suche matcht case-insensitiv über den vollen Namen")
    func searchMatchesFullName() {
        let g = [guest("Anna", "Müller"), guest("Bob", "Schmidt")]
        let f = GuestListFiltering(guests: g, tags: [], searchText: "müll")
        #expect(f.filteredGuests.map(\.firstName) == ["Anna"])
        #expect(f.hasActiveFilter)
    }

    @Test("Seiten-Filter zeigt nur die gewählte Seite")
    func sideFilter() {
        let g = [guest("Anna", side: .partner1), guest("Bob", side: .partner2)]
        let f = GuestListFiltering(guests: g, tags: [], sideFilter: .partner1)
        #expect(f.filteredGuests.map(\.firstName) == ["Anna"])
    }

    @Test("Unzugeordnet-Filter blendet Anmeldungen mit bereits zugeordnetem Mitglied aus")
    func unassignedSmartFilterHidesAssignedGroups() {
        let groupA = UUID()
        // Gruppe A: ein Mitglied schon zugeordnet → die ganze Anmeldung gilt
        // nicht mehr als offen.
        let a1 = guest("Anna", side: .partner1, group: groupA)
        let a2 = guest("Andi", side: .unassigned, group: groupA)
        // Gruppe B: komplett offen → echtes Action-Item.
        let groupB = UUID()
        let b1 = guest("Bea", side: .unassigned, group: groupB)
        // Einzelner offener Gast ohne Gruppe.
        let solo = guest("Cara", side: .unassigned)

        let f = GuestListFiltering(guests: [a1, a2, b1, solo], tags: [], sideFilter: .unassigned)
        let names = Set(f.filteredGuests.map(\.firstName))
        #expect(names == ["Bea", "Cara"])
    }

    @Test("Status-Filter: nur gepinnte / mit Allergie / am Tisch")
    func statusFilters() {
        let pinned = guest("Pin", pinned: true)
        let allergic = guest("All", intolerances: ["Nüsse"])
        let seated = guest("Sit", seated: true)
        let plain = guest("Plain")
        let all = [pinned, allergic, seated, plain]

        #expect(GuestListFiltering(guests: all, tags: [], statusFilter: .pinned).filteredGuests.map(\.firstName) == ["Pin"])
        #expect(GuestListFiltering(guests: all, tags: [], statusFilter: .allergies).filteredGuests.map(\.firstName) == ["All"])
        #expect(GuestListFiltering(guests: all, tags: [], statusFilter: .assigned).filteredGuests.map(\.firstName) == ["Sit"])
        #expect(Set(GuestListFiltering(guests: all, tags: [], statusFilter: .unassigned).filteredGuests.map(\.firstName)) == ["Pin", "All", "Plain"])
    }

    @Test("FunFact-Status-Filter: ok / unklar / fehlt")
    func funFactStatusFilters() {
        let good = guest("Good", funFact: "klettert", approved: true)
        let pending = guest("Pend", funFact: "nett", approved: false)
        let empty = guest("Empt", funFact: "  ", approved: false)
        let all = [good, pending, empty]

        #expect(GuestListFiltering(guests: all, tags: [], statusFilter: .funfactGood).filteredGuests.map(\.firstName) == ["Good"])
        #expect(GuestListFiltering(guests: all, tags: [], statusFilter: .funfactPending).filteredGuests.map(\.firstName) == ["Pend"])
        #expect(GuestListFiltering(guests: all, tags: [], statusFilter: .funfactEmpty).filteredGuests.map(\.firstName) == ["Empt"])
    }

    @Test("Telefon-fehlt-Filter respektiert die Anmeldegruppe (eine Nummer pro Anmeldung reicht)")
    func phoneMissingPerRegistration() {
        let group = UUID()
        let withPhone = guest("Hat", group: group, phone: "0170")
        let peer = guest("Peer", group: group)          // hat keine, aber Gruppe hat eine
        let lonely = guest("Solo")                       // echtes Action-Item

        let f = GuestListFiltering(guests: [withPhone, peer, lonely], tags: [], statusFilter: .phoneMissing)
        #expect(f.filteredGuests.map(\.firstName) == ["Solo"])
    }

    @Test("Tag-Filter matcht Kategorie; Familie matcht zusätzlich über familyRole")
    func tagFilterAndFamilyRole() {
        let tagged = guest("Tagged")
        let viaRole = guest("Vater", familyRole: .father)
        let unrelated = guest("Other")
        let familyTag = tag("Kern", .family, guests: [tagged])

        let f = GuestListFiltering(guests: [tagged, viaRole, unrelated], tags: [familyTag], tagFilter: .family)
        #expect(Set(f.filteredGuests.map(\.firstName)) == ["Tagged", "Vater"])
    }

    @Test("Alters-Filter")
    func ageFilter() {
        let kid = guest("Kid", age: .child)
        let adult = guest("Adult", age: .adult)
        let f = GuestListFiltering(guests: [kid, adult], tags: [], ageFilter: .child)
        #expect(f.filteredGuests.map(\.firstName) == ["Kid"])
    }

    // MARK: - registrationSections

    @Test("Sektionen: Brautpaar zuerst, dann Familien alphabetisch, Einzelne zuletzt")
    func sectionOrdering() {
        let braut = guest("Braut")
        let groom = guest("Bräutigam")
        let groupMueller = UUID()
        let m1 = guest("Max", "Müller", group: groupMueller)
        let m2 = guest("Mia", "Müller", group: groupMueller)
        let groupAbel = UUID()
        let a1 = guest("Ada", "Abel", group: groupAbel)
        let solo = guest("Solo")

        let brautTag = tag("Brautpaar", .role, guests: [braut, groom])
        let f = GuestListFiltering(guests: [braut, groom, m1, m2, a1, solo], tags: [brautTag])

        let sections = f.registrationSections
        #expect(sections.map(\.label) == ["Brautpaar", "Familie Abel", "Familie Müller", "Einzeln hinzugefügt"])
        #expect(sections.first?.isBridal == true)
    }

    @Test("Gefilterte Gruppe behält durchgefallene Mitglieder als gedimmten Kontext")
    func dimmedContextMembers() {
        let group = UUID()
        let inFilter = guest("Clara", "Stein", group: group)
        let outFilter = guest("Heike", "Becker", group: group)
        let faschingTag = tag("Fasching", .activity, guests: [inFilter])

        let f = GuestListFiltering(guests: [inFilter, outFilter], tags: [faschingTag], tagFilter: .activity)
        let sections = f.registrationSections
        #expect(sections.count == 1)
        let visibleNames = sections[0].guests.map(\.firstName)
        let dimmedNames = sections[0].dimmedGuests.map(\.firstName)
        #expect(visibleNames == ["Clara"])
        #expect(dimmedNames == ["Heike"])
    }

    @Test("FunFact-Filter macht eine flache Liste statt Gruppen")
    func funFactFilterFlat() {
        let group = UUID()
        let a = guest("Bea", "Z", group: group, funFact: "x", approved: true)
        let b = guest("Ada", "Y", group: group, funFact: "y", approved: true)
        let f = GuestListFiltering(guests: [a, b], tags: [], statusFilter: .funfactGood)
        let sections = f.registrationSections
        #expect(sections.count == 1)
        #expect(sections[0].id == "funfact-flat")
        #expect(sections[0].guests.map(\.firstName) == ["Ada", "Bea"])  // alphabetisch
    }

    // MARK: - sectionLabel

    @Test("sectionLabel: eine dominante Familie → 'Familie X'")
    func sectionLabelSingleFamily() {
        let f = GuestListFiltering(guests: [], tags: [])
        let members = [guest("Max", "Müller"), guest("Mia", "Müller")]
        #expect(f.sectionLabel(for: members) == "Familie Müller")
    }

    @Test("sectionLabel: zwei kombinierte Familien → 'A & B' alphabetisch")
    func sectionLabelCombined() {
        let f = GuestListFiltering(guests: [], tags: [])
        let members = [guest("Clara", "Stein"), guest("Heike", "Becker")]
        #expect(f.sectionLabel(for: members) == "Becker & Stein")
    }

    @Test("sectionLabel: ohne Nachnamen → Vornamen")
    func sectionLabelNoLastNames() {
        let f = GuestListFiltering(guests: [], tags: [])
        let members = [guest("Anna"), guest("Bob")]
        #expect(f.sectionLabel(for: members) == "Anna & Bob")
    }

    // MARK: - counts

    @Test("countForSide: smarte Unzugeordnet-Zählung deckt sich mit Filter")
    func countForSideUnassigned() {
        let group = UUID()
        let assigned = guest("A", side: .partner1, group: group)
        let peer = guest("B", side: .unassigned, group: group)
        let open = guest("C", side: .unassigned)
        let f = GuestListFiltering(guests: [assigned, peer, open], tags: [])
        #expect(f.countForSide(.unassigned) == 1)
        #expect(f.countForSide(.partner1) == 1)
    }

    @Test("countForStatus deckt alle Status ab")
    func countForStatusAll() {
        let seated = guest("S", seated: true)
        let pinned = guest("P", pinned: true)
        let allergic = guest("A", intolerances: ["Nüsse"])
        let good = guest("G", funFact: "x", approved: true)
        let f = GuestListFiltering(guests: [seated, pinned, allergic, good], tags: [])
        #expect(f.countForStatus(.assigned) == 1)
        #expect(f.countForStatus(.unassigned) == 3)
        #expect(f.countForStatus(.pinned) == 1)
        #expect(f.countForStatus(.allergies) == 1)
        #expect(f.countForStatus(.funfactGood) == 1)
        #expect(f.countForStatus(.funfactEmpty) == 3)
    }

    @Test("tagCategoryCount zählt Familie inkl. familyRole-Gäste ohne Doppelzählung")
    func tagCategoryCountFamily() {
        let taggedAndRole = guest("Beides", familyRole: .mother)
        let onlyRole = guest("NurRolle", familyRole: .father)
        let onlyTag = guest("NurTag")
        let familyTag = tag("Kern", .family, guests: [taggedAndRole, onlyTag])
        let f = GuestListFiltering(guests: [taggedAndRole, onlyRole, onlyTag], tags: [familyTag])
        // taggedAndRole + onlyRole + onlyTag = 3, kein Doppel
        #expect(f.tagCategoryCount(.family) == 3)
    }

    @Test("isFunFactFilterActive nur bei FunFact-Status")
    func isFunFactFilterActiveFlag() {
        #expect(GuestListFiltering(guests: [], tags: [], statusFilter: .funfactGood).isFunFactFilterActive)
        #expect(GuestListFiltering(guests: [], tags: [], statusFilter: .pinned).isFunFactFilterActive == false)
        #expect(GuestListFiltering(guests: [], tags: []).isFunFactFilterActive == false)
    }
}
