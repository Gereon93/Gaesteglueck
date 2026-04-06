import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Seating Optimizer")
struct SeatingOptimizerTests {
    func makeGuest(_ firstName: String, assignment: PartnerAssignment = .partner1) -> Guest {
        Guest(firstName: firstName, partnerAssignment: assignment)
    }

    @Test("Must-sit-together guests are assigned to same table")
    func mustSitTogetherStay() {
        let alice = makeGuest("Alice")
        let bob = makeGuest("Bob", assignment: .partner2)
        let table = GuestTable(name: "T1", shape: .round, diameter: 180)
        let constraint = Constraint(type: .mustSitTogether, guestIDs: [alice.id, bob.id], reason: "Ehepaar")

        let result = SeatingOptimizer.solve(
            guests: [alice, bob],
            tables: [table],
            tags: [],
            constraints: [constraint]
        )
        #expect(result[alice.id] == result[bob.id])
    }

    @Test("Must-not-sit-together guests are separated")
    func mustNotSitTogetherSeparated() {
        let alice = makeGuest("Alice")
        let eve = makeGuest("Eve")
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)
        let constraint = Constraint(type: .mustNotSitTogether, guestIDs: [alice.id, eve.id], reason: "Konflikt")

        let result = SeatingOptimizer.solve(
            guests: [alice, eve],
            tables: [t1, t2],
            tags: [],
            constraints: [constraint]
        )
        #expect(result[alice.id] != result[eve.id])
    }

    @Test("Family members cluster together")
    func familyClusters() {
        let fid = UUID()
        let a = makeGuest("A")
        a.familyID = fid
        let b = makeGuest("B")
        b.familyID = fid
        let c = makeGuest("C", assignment: .partner2)
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)

        let result = SeatingOptimizer.solve(
            guests: [a, b, c],
            tables: [t1, t2],
            tags: [],
            constraints: []
        )
        #expect(result[a.id] == result[b.id])
    }

    @Test("Respects table capacity")
    func respectsCapacity() {
        let guests = (0..<12).map { makeGuest("G\($0)") }
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180) // ~9 seats
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180) // ~9 seats

        let result = SeatingOptimizer.solve(
            guests: guests,
            tables: [t1, t2],
            tags: [],
            constraints: []
        )
        let t1Count = result.values.filter { $0 == t1.id }.count
        let t2Count = result.values.filter { $0 == t2.id }.count
        #expect(t1Count <= t1.capacity)
        #expect(t2Count <= t2.capacity)
    }

    @Test("Pinned guests stay at their table")
    func pinnedGuestsStay() {
        let alice = makeGuest("Alice")
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)
        alice.table = t1
        alice.isPinned = true

        let result = SeatingOptimizer.solve(
            guests: [alice],
            tables: [t1, t2],
            tags: [],
            constraints: []
        )
        #expect(result[alice.id] == t1.id)
    }

    @Test("All guests get assigned")
    func allGuestsAssigned() {
        let guests = (0..<12).map { makeGuest("G\($0)") }
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180) // ~9
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180) // ~9

        let result = SeatingOptimizer.solve(
            guests: guests,
            tables: [t1, t2],
            tags: [],
            constraints: []
        )
        #expect(result.count == 12)
    }

    @Test("Children from same family stay with parents")
    func childrenWithParents() {
        let fid = UUID()
        let parent = makeGuest("Mama")
        parent.familyID = fid
        let child = Guest(firstName: "Kind", ageCategory: .child, familyID: fid)
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)

        let result = SeatingOptimizer.solve(
            guests: [parent, child],
            tables: [t1, t2],
            tags: [],
            constraints: []
        )
        #expect(result[parent.id] == result[child.id])
    }
}
