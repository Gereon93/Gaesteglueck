import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Happiness Scorer")
struct HappinessScorerTests {
    func makeGuest(_ firstName: String, assignment: PartnerAssignment = .partner1) -> Guest {
        Guest(firstName: firstName, partnerAssignment: assignment)
    }

    @Test("Empty table scores zero")
    func emptyTable() {
        let table = GuestTable(name: "T1", shape: .round)
        let score = HappinessScorer.scoreTable(table, tags: [], constraints: [])
        #expect(score == 0)
    }

    @Test("Tag members at same table scores positively")
    func tagMembersAtSameTable() {
        let alice = makeGuest("Alice")
        let bob = makeGuest("Bob", assignment: .partner2)
        let table = GuestTable(name: "T1", shape: .round)
        table.guests = [alice, bob]

        let tag = Tag(name: "Unigruppe", category: .friendGroup)
        tag.guestIDs = [alice.id, bob.id]
        let score = HappinessScorer.scoreTable(table, tags: [tag], constraints: [])
        #expect(score > 0)
    }

    @Test("Mixed assignments bonus")
    func mixedAssignmentsBonus() {
        let p1Guest = makeGuest("A", assignment: .partner1)
        let p2Guest = makeGuest("B", assignment: .partner2)
        let table = GuestTable(name: "T1", shape: .round)
        table.guests = [p1Guest, p2Guest]

        let score = HappinessScorer.scoreTable(table, tags: [], constraints: [])
        #expect(score > 0)
    }

    @Test("Overall score sums all tables")
    func overallScore() {
        let t1 = GuestTable(name: "T1", shape: .round)
        let t2 = GuestTable(name: "T2", shape: .round)
        let alice = makeGuest("Alice")
        let bob = makeGuest("Bob")
        t1.guests = [alice]
        t2.guests = [bob]

        let total = HappinessScorer.scoreAllTables([t1, t2], tags: [], constraints: [])
        #expect(total == HappinessScorer.scoreTable(t1, tags: [], constraints: []) + HappinessScorer.scoreTable(t2, tags: [], constraints: []))
    }

    @Test("Must-sit-together constraint separated produces violation")
    func mustSitTogetherViolation() {
        let alice = makeGuest("Alice")
        let bob = makeGuest("Bob")
        let t1 = GuestTable(name: "T1", shape: .round)
        let t2 = GuestTable(name: "T2", shape: .round)
        t1.guests = [alice]
        t2.guests = [bob]

        let constraint = Constraint(type: .mustSitTogether, guestIDs: [alice.id, bob.id], reason: "Ehepaar")
        let violations = HappinessScorer.findViolations(tables: [t1, t2], constraints: [constraint])
        #expect(!violations.isEmpty)
        #expect(violations.first?.type == .constraintViolated)
    }

    @Test("Must-not-sit-together at same table produces violation")
    func mustNotSitTogetherViolation() {
        let alice = makeGuest("Alice")
        let eve = makeGuest("Eve")
        let table = GuestTable(name: "T1", shape: .round)
        table.guests = [alice, eve]

        let constraint = Constraint(type: .mustNotSitTogether, guestIDs: [alice.id, eve.id], reason: "Konflikt")
        let violations = HappinessScorer.findViolations(tables: [table], constraints: [constraint])
        #expect(!violations.isEmpty)
        #expect(violations.first?.type == .constraintViolated)
    }

    @Test("Sweet-spot: well-filled table scores higher than nearly empty one")
    func sweetSpotBonus() {
        // Big round table ~ capacity 9.
        let full = GuestTable(name: "Voll", shape: .round, diameter: 180)
        full.guests = (0..<8).map { makeGuest("F\($0)") }

        let empty = GuestTable(name: "Leer", shape: .round, diameter: 180)
        empty.guests = (0..<2).map { makeGuest("E\($0)") }

        let fullScore = HappinessScorer.scoreTable(full, tags: [], constraints: [])
        let emptyScore = HappinessScorer.scoreTable(empty, tags: [], constraints: [])
        #expect(fullScore > emptyScore)
    }

    @Test("Bridge person at a well-tagged table boosts score")
    func bridgePersonBonus() {
        let hub = makeGuest("Hub")
        let a = makeGuest("A")
        let b = makeGuest("B")
        let table = GuestTable(name: "T", shape: .round)
        table.guests = [hub, a, b]

        let tag1 = Tag(name: "Arbeit", category: .work)
        tag1.guestIDs = [hub.id, a.id]
        let tag2 = Tag(name: "Sport", category: .activity)
        tag2.guestIDs = [hub.id, b.id]

        let withBridge = HappinessScorer.scoreTable(table, tags: [tag1, tag2], constraints: [])

        // Same guests, but no tags at all.
        let noTags = HappinessScorer.scoreTable(table, tags: [], constraints: [])
        #expect(withBridge > noTags)
    }

    @Test("Generation mix at an adult table is rewarded")
    func generationMixBonus() {
        let mama = makeGuest("Mama")
        let kind = Guest(firstName: "Kind", ageCategory: .child)
        let mixed = GuestTable(name: "Mixed", shape: .round)
        mixed.guests = [mama, kind]

        // Use disjoint guests so SwiftData inverse handling doesn't steal mama.
        let papa = makeGuest("Papa", assignment: .partner2)
        let oma = makeGuest("Oma")
        let adultOnly = GuestTable(name: "Adults", shape: .round)
        adultOnly.guests = [papa, oma]

        let mixedScore = HappinessScorer.scoreTable(mixed, tags: [], constraints: [])
        let adultScore = HappinessScorer.scoreTable(adultOnly, tags: [], constraints: [])
        #expect(mixedScore > adultScore)
    }

    @Test("Dietary cluster at one table is rewarded")
    func dietaryClusterBonus() {
        let a = makeGuest("A"); a.dietaryChoice = "Vegan"
        let b = makeGuest("B"); b.dietaryChoice = "Vegan"
        let c = makeGuest("C"); c.dietaryChoice = "Vegan"
        let table = GuestTable(name: "Vegan", shape: .round)
        table.guests = [a, b, c]

        let d = makeGuest("D"); d.dietaryChoice = "Fleisch"
        let e = makeGuest("E"); e.dietaryChoice = "Fleisch"
        let f = makeGuest("F"); f.dietaryChoice = "Fleisch"
        let baseline = GuestTable(name: "Fleisch", shape: .round)
        baseline.guests = [d, e, f]

        let veganScore = HappinessScorer.scoreTable(table, tags: [], constraints: [])
        let meatScore = HappinessScorer.scoreTable(baseline, tags: [], constraints: [])
        #expect(veganScore > meatScore)
    }
}
