import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Table Placer")
struct TablePlacerTests {
    @Test("Places tables without overlap")
    func noOverlap() {
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)
        let roomWidth: Double = 1000
        let roomDepth: Double = 800

        let placements = TablePlacer.suggestLayout(
            tables: [t1, t2],
            roomWidthCM: roomWidth,
            roomDepthCM: roomDepth
        )

        #expect(placements.count == 2)

        let p1 = placements[0]
        let p2 = placements[1]
        let distance = sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))
        let minDistance = (t1.diameter / 2 + t2.diameter / 2) + 160
        #expect(distance >= minDistance)
    }

    @Test("Bride table placed centrally")
    func brideTableCentered() {
        let bt = GuestTable(name: "Brauttisch", shape: .brideTable, width: 400, depth: 100)
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)

        let placements = TablePlacer.suggestLayout(
            tables: [bt, t1],
            roomWidthCM: 1000,
            roomDepthCM: 800
        )

        let bridePlace = placements.first { $0.tableID == bt.id }!
        #expect(bridePlace.x > 300 && bridePlace.x < 700)
    }

    @Test("Tables fit within room bounds")
    func withinBounds() {
        let tables = (0..<5).map { GuestTable(name: "T\($0)", shape: .round, diameter: 180) }

        let placements = TablePlacer.suggestLayout(
            tables: tables,
            roomWidthCM: 1200,
            roomDepthCM: 1000
        )

        for p in placements {
            #expect(p.x > 0 && p.x < 1200)
            #expect(p.y > 0 && p.y < 1000)
        }
    }
}
