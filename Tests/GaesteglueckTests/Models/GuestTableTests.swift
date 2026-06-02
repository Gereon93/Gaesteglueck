import Testing
import Foundation
@testable import Gaesteglueck

@Suite("GuestTable Model")
struct GuestTableTests {
    @Test("Round table calculates capacity from diameter")
    func roundTableCapacity() {
        let table = GuestTable(name: "Tisch 1", shape: .round, diameter: 180)
        #expect(table.capacity == 9)
    }

    @Test("Rectangular table 200x100 has 8 seats with default rules")
    func rectangularTable200x100() {
        GuestTable.activeRules = .default
        let table = GuestTable(name: "T", shape: .rectangular, width: 200, depth: 100)
        #expect(table.capacity == 8)
    }

    @Test("Rectangular table 140x80 has 6 seats with default rules")
    func rectangularTable140x80() {
        GuestTable.activeRules = .default
        let table = GuestTable(name: "T", shape: .rectangular, width: 140, depth: 80)
        #expect(table.capacity == 6)
    }

    @Test("Rectangular table 140x50 has 4 seats (kurzseite zu schmal)")
    func rectangularTable140x50() {
        GuestTable.activeRules = .default
        let table = GuestTable(name: "T", shape: .rectangular, width: 140, depth: 50)
        #expect(table.capacity == 4)
    }

    @Test("capacity(rules:) reacts to seatWidth changes")
    func capacityWithCustomRules() {
        let table = GuestTable(name: "T", shape: .rectangular, width: 140, depth: 80)
        let rules70 = SeatingRules(seatWidthCm: 70, tableMinDistanceCm: 80, aisleWidthCm: 120)
        let rules80 = SeatingRules(seatWidthCm: 80, tableMinDistanceCm: 80, aisleWidthCm: 120)
        #expect(table.capacity(rules: rules70) == 6)  // 2*Int(140/70)+2 = 4+2
        #expect(table.capacity(rules: rules80) == 4)  // 2*Int(140/80)+2 = 2+2
    }

    @Test("Square table 200x200 has 8 seats with default rules")
    func squareTable() {
        GuestTable.activeRules = .default
        let table = GuestTable(name: "Quadrat", shape: .square, width: 200)
        // 2*Int(200/60) + 2 = 6 + 2
        #expect(table.capacity == 8)
    }

    @Test("Remaining seats calculation")
    func remainingSeats() {
        let table = GuestTable(name: "Test", shape: .round, diameter: 180)
        #expect(table.remainingSeats == table.capacity)
    }

    @Test("Table is full detection")
    func isFull() {
        let table = GuestTable(name: "Test", shape: .round, diameter: 180)
        #expect(!table.isFull)
    }

    @Test("Child table flag")
    func childTable() {
        let table = GuestTable(name: "Kindertisch", shape: .round, diameter: 120, isChildTable: true)
        #expect(table.isChildTable)
    }

    @Test("attendingGuests excludes declined (ghost) guests")
    func attendingExcludesDeclined() {
        let table = GuestTable(name: "T", shape: .round, diameter: 180)
        let coming = Guest(firstName: "Anna", rsvpStatus: .confirmed)
        let ghost = Guest(firstName: "Tante", rsvpStatus: .declined)
        coming.table = table
        ghost.table = table
        table.guests = [coming, ghost]
        #expect(table.attendingGuests.map(\.firstName) == ["Anna"])
    }

    @Test("ghostGuests are the seated declined guests")
    func ghostGuestsAreDeclined() {
        let table = GuestTable(name: "T", shape: .round, diameter: 180)
        let coming = Guest(firstName: "Anna", rsvpStatus: .confirmed)
        let ghost = Guest(firstName: "Tante", rsvpStatus: .declined)
        coming.table = table
        ghost.table = table
        table.guests = [coming, ghost]
        #expect(table.ghostGuests.map(\.firstName) == ["Tante"])
    }

    @Test("Occupancy ignores declined ghost guests")
    func occupancyIgnoresGhost() {
        let table = GuestTable(name: "T", shape: .round, diameter: 180)
        let coming = Guest(firstName: "Anna", rsvpStatus: .confirmed)
        let ghost = Guest(firstName: "Tante", rsvpStatus: .declined)
        coming.table = table
        ghost.table = table
        table.guests = [coming, ghost]
        // Nur Anna belegt einen Platz — die abgesagte Tante nicht.
        #expect(table.remainingSeats == table.capacity - 1)
    }

    @Test("Combination group with order")
    func combinationGroup() {
        let t1 = GuestTable(name: "T1", shape: .rectangular, width: 200, depth: 100)
        let t2 = GuestTable(name: "T2", shape: .rectangular, width: 200, depth: 100)
        let groupID = UUID()
        t1.combinationGroup = groupID
        t1.combinationOrder = 0
        t2.combinationGroup = groupID
        t2.combinationOrder = 1
        #expect(t1.combinationGroup == t2.combinationGroup)
        #expect(t1.combinationOrder == 0)
        #expect(t2.combinationOrder == 1)
    }
}
