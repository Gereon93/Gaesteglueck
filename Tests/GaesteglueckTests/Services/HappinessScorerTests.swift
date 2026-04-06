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
}
