import Testing
import Foundation
@testable import Gaesteglueck

@Suite("FunFactReminderGenerator")
struct FunFactReminderGeneratorTests {
    @Test("Anrede nutzt den Vornamen")
    func usesFirstName() {
        let g = Guest(firstName: "Berni", lastName: "Müller", partnerAssignment: .partner1)
        let event = Event(name: "X", partner1Name: "Lisa", partner2Name: "Tom")
        let msg = FunFactReminderGenerator.message(for: g, event: event)
        #expect(msg.contains("Hallo Berni"))
    }

    @Test("Beispiele referenzieren Partner-Seite")
    func referencesPartnerSide() {
        let bridesSide = Guest(firstName: "Anna", partnerAssignment: .partner1)
        let event = Event(name: "X", partner1Name: "Lisa", partner2Name: "Tom")
        let msg = FunFactReminderGenerator.message(for: bridesSide, event: event)
        #expect(msg.contains("Lisa"))
    }

    @Test("Familienrolle steuert die Beispiele")
    func roleShapesExamples() {
        let mom = Guest(firstName: "Inge", partnerAssignment: .partner1)
        mom.familyRole = .mother
        let event = Event(name: "X", partner1Name: "Lisa", partner2Name: "Tom")
        let msg = FunFactReminderGenerator.message(for: mom, event: event)
        #expect(msg.contains("Kindheit") || msg.contains("Kind"))
    }

    @Test("Ohne Event-Partner-Namen fällt Text auf 'uns' zurück")
    func fallbackForMissingPartnerNames() {
        let g = Guest(firstName: "Pia", partnerAssignment: .partner1)
        let msg = FunFactReminderGenerator.message(for: g, event: nil)
        #expect(msg.contains("uns"))
    }
}
