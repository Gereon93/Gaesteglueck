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

    @Test("Bride table calculates one-sided capacity")
    func brideTableCapacity() {
        let table = GuestTable(name: "Brauttisch", shape: .brideTable, width: 400, depth: 100)
        #expect(table.capacity == 6)
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

    @Test("Combined rectangular tables increase capacity")
    func combinedTables() {
        let t1 = GuestTable(name: "T1", shape: .rectangular, width: 200, depth: 100)
        let t2 = GuestTable(name: "T2", shape: .rectangular, width: 200, depth: 100)
        t1.linkedTableID = t2.id
        t2.linkedTableID = t1.id
        let combinedCap = t1.combinedCapacity(with: t2)
        #expect(combinedCap > t1.capacity)
    }
}
