#if canImport(SwiftUI)
import Testing
import Foundation
import SwiftUI
@testable import Gaesteglueck

@Suite("TafelLayout")
struct TafelLayoutTests {
    private func makeTable(width: Double, depth: Double, x: Double, order: Int) -> GuestTable {
        let t = GuestTable(name: "T\(order)", shape: .rectangular, width: width, depth: depth, positionX: x, positionY: 0)
        t.combinationGroup = UUID()
        t.combinationOrder = order
        return t
    }

    @Test("Two 140x80 tables form a 280x80 tafel with 10 seats")
    func twoTables() {
        let rules = SeatingRules.default
        let t0 = makeTable(width: 140, depth: 80, x: -70, order: 0)
        let t1 = makeTable(width: 140, depth: 80, x: 70, order: 1)
        let geo = TafelLayout.geometry(of: [t0, t1], rules: rules)
        #expect(geo.totalWidth == 280)
        #expect(geo.depth == 80)
        // 2 * floor(280/60) + 2 = 2*4 + 2 = 10
        #expect(geo.capacity == 10)
        #expect(geo.seats.count == 10)
    }

    @Test("Three 140x80 tables form a 420x80 tafel with 16 seats")
    func threeTables() {
        let rules = SeatingRules.default
        let t0 = makeTable(width: 140, depth: 80, x: -140, order: 0)
        let t1 = makeTable(width: 140, depth: 80, x: 0, order: 1)
        let t2 = makeTable(width: 140, depth: 80, x: 140, order: 2)
        let geo = TafelLayout.geometry(of: [t0, t1, t2], rules: rules)
        // 2 * floor(420/60) + 2 = 2*7 + 2 = 16
        #expect(geo.capacity == 16)
        #expect(geo.seats.count == 16)
    }

    @Test("Outer end seats belong to outermost tables")
    func endSeatMapping() {
        let rules = SeatingRules.default
        let t0 = makeTable(width: 140, depth: 80, x: -70, order: 0)
        let t1 = makeTable(width: 140, depth: 80, x: 70, order: 1)
        let geo = TafelLayout.geometry(of: [t0, t1], rules: rules)

        let leftEnd = geo.seats.min(by: { $0.position.x < $1.position.x })!
        #expect(leftEnd.tableID == t0.id)

        let rightEnd = geo.seats.max(by: { $0.position.x < $1.position.x })!
        #expect(rightEnd.tableID == t1.id)
    }

    @Test("Custom seatWidth changes capacity")
    func customSeatWidth() {
        var rules = SeatingRules.default
        rules.seatWidthCm = 70
        let t0 = makeTable(width: 140, depth: 80, x: -70, order: 0)
        let t1 = makeTable(width: 140, depth: 80, x: 70, order: 1)
        let geo = TafelLayout.geometry(of: [t0, t1], rules: rules)
        // 2 * floor(280/70) + 2 = 8 + 2 = 10
        #expect(geo.capacity == 10)
    }
}
#endif
