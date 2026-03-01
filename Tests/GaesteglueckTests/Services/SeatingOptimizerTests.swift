import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Seating Optimizer")
struct SeatingOptimizerTests {
    func makeGuest(_ name: String, side: Side = .bride, groupType: GroupType? = nil) -> Guest {
        Guest(name: name, side: side, groupType: groupType)
    }

    @Test("Partners are assigned to same table")
    func partnersStayTogether() {
        let alice = makeGuest("Alice")
        let bob = makeGuest("Bob", side: .groom)
        let table = GuestTable(name: "T1", shape: .round, diameter: 180)
        let rel = Relationship(personAID: alice.id, personBID: bob.id, type: .partner)

        let result = SeatingOptimizer.solve(
            guests: [alice, bob],
            tables: [table],
            relationships: [rel]
        )
        // Partners must be at the same table
        #expect(result[alice.id] == result[bob.id])
    }

    @Test("Toxic guests are separated")
    func toxicSeparated() {
        let alice = makeGuest("Alice")
        let eve = makeGuest("Eve")
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)
        let rel = Relationship(personAID: alice.id, personBID: eve.id, type: .toxic)

        let result = SeatingOptimizer.solve(
            guests: [alice, eve],
            tables: [t1, t2],
            relationships: [rel]
        )
        #expect(result[alice.id] != result[eve.id])
    }

    @Test("Family members cluster together")
    func familyClusters() {
        let fid = UUID()
        let a = makeGuest("A", groupType: .immediateFamily)
        a.familyID = fid
        let b = makeGuest("B", groupType: .immediateFamily)
        b.familyID = fid
        let c = makeGuest("C", side: .groom)
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)

        let result = SeatingOptimizer.solve(
            guests: [a, b, c],
            tables: [t1, t2],
            relationships: []
        )
        #expect(result[a.id] == result[b.id]) // Family stays together
    }

    @Test("Respects table capacity")
    func respectsCapacity() {
        let guests = (0..<12).map { makeGuest("G\($0)") }
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180) // ~9 seats
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180) // ~9 seats

        let result = SeatingOptimizer.solve(
            guests: guests,
            tables: [t1, t2],
            relationships: []
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
            relationships: []
        )
        #expect(result[alice.id] == t1.id)
    }

    @Test("Large group splits across tables when needed")
    func groupSplitting() {
        // 12 JGA friends, 9-seat tables -> must split
        let guests = (0..<12).map { makeGuest("JGA\($0)", groupType: .jga) }
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180) // ~9
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180) // ~9

        let result = SeatingOptimizer.solve(
            guests: guests,
            tables: [t1, t2],
            relationships: []
        )
        // All guests should be assigned
        #expect(result.count == 12)
    }

    @Test("Children from same family stay with parents")
    func childrenWithParents() {
        let fid = UUID()
        let parent = makeGuest("Mama")
        parent.familyID = fid
        let child = makeGuest("Kind", groupType: .immediateFamily)
        child.familyID = fid
        child.isChild = true
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)

        let result = SeatingOptimizer.solve(
            guests: [parent, child],
            tables: [t1, t2],
            relationships: []
        )
        #expect(result[parent.id] == result[child.id])
    }
}
