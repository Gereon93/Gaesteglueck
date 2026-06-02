import Testing
import Foundation
@testable import Gaesteglueck

@Suite("FunFact Game Cards")
struct FunFactGameCardsExporterTests {
    @Test("Declined guests get no game card even with a FunFact")
    func declinedExcluded() {
        let coming = Guest(firstName: "Anna", funFact: "Klettert gern", rsvpStatus: .confirmed)
        let gone = Guest(firstName: "Tante", funFact: "War bei der Mondlandung", rsvpStatus: .declined)
        let cards = FunFactGameCardsExporter.cardGuests([coming, gone])
        #expect(cards.map(\.firstName) == ["Anna"])
    }

    @Test("Guests without a FunFact get no card")
    func emptyFunFactExcluded() {
        let withFact = Guest(firstName: "Anna", funFact: "Klettert gern", rsvpStatus: .confirmed)
        let without = Guest(firstName: "Ben", rsvpStatus: .confirmed)
        let cards = FunFactGameCardsExporter.cardGuests([withFact, without])
        #expect(cards.map(\.firstName) == ["Anna"])
    }
}
