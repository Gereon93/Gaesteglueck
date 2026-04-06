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

    @Test("Rectangular table calculates capacity from dimensions")
    func rectangularTableCapacity() {
        let table = GuestTable(name: "Tisch 2", shape: .rectangular, width: 200, depth: 100)
        #expect(table.capacity == 8)
    }

    @Test("Square table calculates capacity from width")
    func squareTableCapacity() {
        let table = GuestTable(name: "Quadrat", shape: .square, width: 200)
        // perimeter = 4 * 200 = 800, seats = 800/60 = 13
        #expect(table.capacity == 13)
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

    @Test("Combination group")
    func combinationGroup() {
        let t1 = GuestTable(name: "T1", shape: .rectangular, width: 200, depth: 100)
        let t2 = GuestTable(name: "T2", shape: .rectangular, width: 200, depth: 100)
        let groupID = UUID()
        t1.combinationGroup = groupID
        t1.combinationRole = .head
        t2.combinationGroup = groupID
        t2.combinationRole = .end
        #expect(t1.combinationGroup == t2.combinationGroup)
    }
}
