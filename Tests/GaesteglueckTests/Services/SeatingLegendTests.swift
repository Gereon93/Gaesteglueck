import Testing
import Foundation
@testable import Gaesteglueck

@Suite("SeatingLegend")
struct SeatingLegendTests {
    @Test("Empty guest list → empty legend")
    func emptyLegend() {
        let legend = SeatingLegend(guests: [])
        #expect(legend.isEmpty)
        #expect(legend.entries.isEmpty)
    }

    @Test("Unique intolerances become numbered 1..n in case-insensitive alphabetical order")
    func numberingIsAlphabeticalAndStable() {
        let a = Guest(firstName: "Anna", partnerAssignment: .partner1, intolerances: ["Gluten", "Laktose"])
        let b = Guest(firstName: "Ben", partnerAssignment: .partner2, intolerances: ["nüsse", "Gluten"])
        let legend = SeatingLegend(guests: [a, b])

        // Sortiert: Gluten, Laktose, nüsse
        #expect(legend.entries.map(\.name) == ["Gluten", "Laktose", "nüsse"])
        #expect(legend.entries.map(\.number) == [1, 2, 3])

        // Gast-Nummern korrekt aufgelöst
        #expect(legend.numbers(for: a) == [1, 2])      // Gluten=1, Laktose=2
        #expect(legend.numbers(for: b) == [1, 3])      // Gluten=1, nüsse=3
    }

    @Test("Whitespace and empty intolerances are normalized/ignored")
    func normalizesEntries() {
        let g = Guest(
            firstName: "Carla",
            partnerAssignment: .partner1,
            intolerances: ["  Gluten  ", "", "   "]
        )
        let legend = SeatingLegend(guests: [g])
        #expect(legend.entries.map(\.name) == ["Gluten"])
        #expect(legend.numbers(for: g) == [1])
    }

    @Test("Guest without intolerances → empty numbers")
    func guestWithoutIntolerances() {
        let g = Guest(firstName: "Dora", partnerAssignment: .partner1)
        let legend = SeatingLegend(guests: [g])
        #expect(legend.isEmpty)
        #expect(legend.numbers(for: g) == [])
    }

    @Test("Nur vorhandene Nicht-Erwachsenen-Altersgruppen, in natürlicher Reihenfolge")
    func ageCategoriesPresentOnly() {
        let adult = Guest(firstName: "Anna", partnerAssignment: .partner1, ageCategory: .adult)
        let baby = Guest(firstName: "Ben", partnerAssignment: .partner2, ageCategory: .baby)
        let child = Guest(firstName: "Cara", partnerAssignment: .partner1, ageCategory: .child)
        let legend = SeatingLegend(guests: [adult, baby, child])

        // Erwachsene tauchen NICHT auf; Reihenfolge folgt allCases (Kind < Baby).
        #expect(legend.ageCategories == [.child, .baby])
        #expect(legend.hasAgeMarkers)
    }

    @Test("Nur Erwachsene → keine Alters-Marker")
    func adultsOnlyNoAgeMarkers() {
        let a = Guest(firstName: "Anna", partnerAssignment: .partner1, ageCategory: .adult)
        let legend = SeatingLegend(guests: [a])
        #expect(!legend.hasAgeMarkers)
        #expect(legend.ageCategories.isEmpty)
    }

    @Test("Case-/Diakritika-insensitive Dedup: ein Allergen, stabile Nummer")
    func caseInsensitiveDedup() {
        let a = Guest(firstName: "A", partnerAssignment: .partner1, intolerances: ["Gluten"])
        let b = Guest(firstName: "B", partnerAssignment: .partner2, intolerances: ["gluten", "NÜSSE"])
        let c = Guest(firstName: "C", partnerAssignment: .partner1, intolerances: ["nüsse"])
        let legend = SeatingLegend(guests: [a, b, c])
        // "Gluten"/"gluten" → 1 Eintrag; "NÜSSE"/"nüsse" → 1 Eintrag (nur Case).
        #expect(legend.entries.count == 2)
        // a und b teilen dieselbe Gluten-Nummer (1).
        #expect(legend.numbers(for: a) == [1])
        #expect(legend.numbers(for: b).contains(1))
        // b und c teilen die Nüsse-Nummer.
        #expect(legend.numbers(for: c).first == legend.numbers(for: b).last)
        // Anzeigename behält die zuerst gesehene Original-Schreibweise.
        #expect(legend.entries.contains { $0.name == "Gluten" })
    }
}
