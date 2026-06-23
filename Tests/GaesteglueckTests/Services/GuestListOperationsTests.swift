import Testing
import Foundation
@testable import Gaesteglueck

/// Tests für die aus GuestListView/GuestInspectorView extrahierte
/// Geschäftslogik (Issue #4) — vorher als private View-Methoden ungetestet.

@Suite("FunFactWorklist")
struct FunFactWorklistTests {
    private func guest(_ first: String, _ last: String = "", funFact: String = "",
                       approved: Bool = false, rsvp: RSVPStatus = .confirmed) -> Guest {
        let g = Guest(firstName: first, lastName: last, funFact: funFact, rsvpStatus: rsvp)
        g.funFactApproved = approved
        return g
    }

    @Test("incompleteCount zählt fehlende ODER unbestätigte — ohne RSVP-Filter")
    func pendingCount() {
        let ok = guest("OK", funFact: "klettert", approved: true)
        let empty = guest("Empty", funFact: "  ")
        let unapproved = guest("Unappr", funFact: "nett", approved: false)
        let declinedEmpty = guest("Weg", funFact: "", approved: true, rsvp: .declined)
        // declinedEmpty zählt mit, weil pendingCount RSVP bewusst ignoriert
        #expect(FunFactWorklist.incompleteCount(in: [ok, empty, unapproved, declinedEmpty]) == 3)
    }

    @Test("followUpList: nur needsFunFactFollowUp (inkl. RSVP), alphabetisch sortiert")
    func exportList() {
        let ok = guest("OK", funFact: "x", approved: true)            // raus (bestätigt)
        let bea = guest("Bea", "Z", funFact: "")                       // rein
        let ada = guest("Ada", "Y", funFact: "y", approved: false)     // rein
        let declined = guest("Weg", funFact: "", rsvp: .declined)      // raus (RSVP)
        let list = FunFactWorklist.followUpListByName(in: [ok, bea, ada, declined])
        #expect(list.map(\.firstName) == ["Ada", "Bea"])
    }

    @Test("followUpList sortiert bei gleichem Vornamen nach Nachname")
    func exportListTieBreak() {
        let a = guest("Max", "Zander", funFact: "")
        let b = guest("Max", "Albers", funFact: "")
        #expect(FunFactWorklist.followUpListByName(in: [a, b]).map(\.lastName) == ["Albers", "Zander"])
    }

    @Test("checkCandidates: nicht-leer und unbestätigt")
    func checkCandidates() {
        let cand = guest("Cand", funFact: "y", approved: false)
        let approved = guest("App", funFact: "y", approved: true)
        let empty = guest("Empt", funFact: " ")
        #expect(FunFactWorklist.checkCandidates(in: [cand, approved, empty]).map(\.firstName) == ["Cand"])
    }

    @Test("changedProposals filtert unveränderte (getrimmt) heraus")
    func changedProposals() {
        let changed = FunFactNormalizer.Result(guestID: UUID(), original: "a", normalized: "b")
        let sameTrimmed = FunFactNormalizer.Result(guestID: UUID(), original: " x ", normalized: "x")
        let identical = FunFactNormalizer.Result(guestID: UUID(), original: "c", normalized: "c")
        let out = FunFactWorklist.changedProposals([changed, sameTrimmed, identical])
        #expect(out.count == 1)
        #expect(out.first?.original == "a")
    }
}

@Suite("GuestTagSelection")
struct GuestTagSelectionTests {
    @Test("tagsOnAny liefert nur Tags mit mindestens einem Mitglied der Auswahl")
    func tagsOnAny() {
        let g1 = Guest(firstName: "A"), g2 = Guest(firstName: "B"), g3 = Guest(firstName: "C")
        let tagA = Gaesteglueck.Tag(name: "A", category: .custom); tagA.guestIDs = [g1.id, g2.id]
        let tagB = Gaesteglueck.Tag(name: "B", category: .custom); tagB.guestIDs = [g3.id]
        let result = GuestTagSelection.tagsOnAny(of: [g1.id], in: [tagA, tagB])
        #expect(result.map(\.name) == ["A"])
    }

    @Test("members liefert die Schnittmenge aus Tag und Auswahl")
    func members() {
        let g1 = Guest(firstName: "A"), g2 = Guest(firstName: "B"), g3 = Guest(firstName: "C")
        let tag = Gaesteglueck.Tag(name: "T", category: .custom); tag.guestIDs = [g1.id, g2.id, g3.id]
        let result = GuestTagSelection.members(of: tag, in: [g1.id, g3.id])
        #expect(Set(result) == [g1.id, g3.id])
        #expect(result.count == 2)
    }
}

@Suite("MustSitTogetherLink")
struct MustSitTogetherLinkTests {
    @Test("alreadyLinked ist reihenfolge-unabhängig und nur für mustSitTogether")
    func alreadyLinked() {
        let a = UUID(), b = UUID(), c = UUID()
        let link = Constraint(type: .mustSitTogether, guestIDs: [a, b])
        let taboo = Constraint(type: .mustNotSitTogether, guestIDs: [a, c])
        #expect(MustSitTogetherLink.alreadyLinked([b, a], in: [link, taboo]))
        #expect(!MustSitTogetherLink.alreadyLinked([a, c], in: [link, taboo]))  // ist ein Tabu, kein Link
        #expect(!MustSitTogetherLink.alreadyLinked([a, b, c], in: [link, taboo]))
    }

    @Test("reason: Vornamen alphabetisch verknüpft")
    func reason() {
        let bea = Guest(firstName: "Bea"), ada = Guest(firstName: "Ada")
        let text = MustSitTogetherLink.reason(for: [bea.id, ada.id], in: [bea, ada])
        #expect(text == "Müssen zusammen sitzen: Ada + Bea")
    }

    @Test("reason: Fallback wenn keine Namen auflösbar")
    func reasonFallback() {
        let text = MustSitTogetherLink.reason(for: [UUID()], in: [])
        #expect(text == "Manuell verknüpft")
    }
}
