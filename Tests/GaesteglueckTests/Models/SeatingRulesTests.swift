import Testing
import Foundation
@testable import Gaesteglueck

@Suite("SeatingRules")
struct SeatingRulesTests {
    @Test("Default rules have spec values")
    func defaultValues() {
        let rules = SeatingRules.default
        #expect(rules.seatWidthCm == 60)
        #expect(rules.tableMinDistanceCm == 80)
        #expect(rules.aisleWidthCm == 120)
    }

    @Test("Validation: seatWidth must be at least 40")
    func minSeatWidth() {
        #expect(SeatingRules.default.isValid)
        var rules = SeatingRules.default
        rules.seatWidthCm = 39
        #expect(!rules.isValid)
    }

    @Test("Validation: aisleWidth must be >= tableMinDistance")
    func aisleVsTableDistance() {
        var rules = SeatingRules.default
        rules.aisleWidthCm = 70
        rules.tableMinDistanceCm = 80
        #expect(!rules.isValid)
    }

    @Test("Codable round-trip")
    func roundTrip() throws {
        let original = SeatingRules(seatWidthCm: 65, tableMinDistanceCm: 90, aisleWidthCm: 130)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SeatingRules.self, from: data)
        #expect(decoded == original)
    }

    @Test("Event seatingRules getter returns default when nil")
    func eventDefaultRules() {
        let event = Event(name: "Test")
        #expect(event.seatingRules == .default)
    }

    @Test("Event seatingRules setter persists")
    func eventSetRules() {
        let event = Event(name: "Test")
        var rules = SeatingRules.default
        rules.seatWidthCm = 70
        event.seatingRules = rules
        #expect(event.seatingRules.seatWidthCm == 70)
    }
}
