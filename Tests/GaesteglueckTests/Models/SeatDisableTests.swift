import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Seat Disable")
struct SeatDisableTests {
    @Test("disabledSeatIndices roundtrip")
    func roundtrip() {
        GuestTable.activeRules = .default
        let table = GuestTable(name: "T", shape: .rectangular, width: 140, depth: 80)
        #expect(table.disabledSeatIndices.isEmpty)
        table.disabledSeatIndices = [1, 3]
        #expect(table.disabledSeatIndices == [1, 3])
    }

    @Test("effectiveCapacity subtracts disabled count")
    func effectiveCapacity() {
        GuestTable.activeRules = .default
        let table = GuestTable(name: "T", shape: .rectangular, width: 140, depth: 80)
        #expect(table.effectiveCapacity == 6)
        table.disabledSeatIndices = [0, 4]
        #expect(table.effectiveCapacity == 4)
    }
}
