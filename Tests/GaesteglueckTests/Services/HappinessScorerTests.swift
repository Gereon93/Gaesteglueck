import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Happiness Scorer")
struct HappinessScorerTests {
    func makeGuest(_ name: String, side: Side = .bride) -> Guest {
        Guest(name: name, side: side)
    }

    @Test("Empty table scores zero")
    func emptyTable() {
        let table = GuestTable(name: "T1", shape: .round)
        let score = HappinessScorer.scoreTable(table, relationships: [])
        #expect(score == 0)
    }

    @Test("Partners at same table scores positively")
    func partnersAtSameTable() {
        let alice = makeGuest("Alice")
        let bob = makeGuest("Bob", side: .groom)
        let table = GuestTable(name: "T1", shape: .round)
        table.guests = [alice, bob]

        let rel = Relationship(personAID: alice.id, personBID: bob.id, type: .partner)
        let score = HappinessScorer.scoreTable(table, relationships: [rel])
        #expect(score > 0)
    }

    @Test("Toxic guests at same table scores very negatively")
    func toxicAtSameTable() {
        let alice = makeGuest("Alice")
        let eve = makeGuest("Eve")
        let table = GuestTable(name: "T1", shape: .round)
        table.guests = [alice, eve]

        let rel = Relationship(personAID: alice.id, personBID: eve.id, type: .toxic)
        let score = HappinessScorer.scoreTable(table, relationships: [rel])
        #expect(score < 0)
    }

    @Test("Mixed sides bonus")
    func mixedSidesBonus() {
        let brideGuest = makeGuest("A", side: .bride)
        let groomGuest = makeGuest("B", side: .groom)
        let table = GuestTable(name: "T1", shape: .round)
        table.guests = [brideGuest, groomGuest]

        let score = HappinessScorer.scoreTable(table, relationships: [])
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

        let total = HappinessScorer.scoreAllTables([t1, t2], relationships: [])
        #expect(total == HappinessScorer.scoreTable(t1, relationships: []) + HappinessScorer.scoreTable(t2, relationships: []))
    }

    @Test("Partners separated across tables produces violation")
    func partnersSeparated() {
        let alice = makeGuest("Alice")
        let bob = makeGuest("Bob")
        let t1 = GuestTable(name: "T1", shape: .round)
        let t2 = GuestTable(name: "T2", shape: .round)
        t1.guests = [alice]
        t2.guests = [bob]

        let rel = Relationship(personAID: alice.id, personBID: bob.id, type: .partner)
        let violations = HappinessScorer.findViolations(tables: [t1, t2], relationships: [rel])
        #expect(!violations.isEmpty)
        #expect(violations.first?.type == .partnersSeparated)
    }

    @Test("Toxic at same table produces violation")
    func toxicViolation() {
        let alice = makeGuest("Alice")
        let eve = makeGuest("Eve")
        let table = GuestTable(name: "T1", shape: .round)
        table.guests = [alice, eve]

        let rel = Relationship(personAID: alice.id, personBID: eve.id, type: .toxic)
        let violations = HappinessScorer.findViolations(tables: [table], relationships: [rel])
        #expect(!violations.isEmpty)
        #expect(violations.first?.type == .toxicAtSameTable)
    }
}
