#if canImport(Testing) && canImport(SwiftUI)
import Foundation
import SwiftUI
import Testing
@testable import Gaesteglueck

@Suite("Seat Layout")
struct SeatLayoutTests {
    @Test("Round table places seats around a circle")
    func roundTable() {
        let positions = SeatLayout.positions(
            shape: .round,
            capacity: 8,
            scaledDiameter: 100,
            scaledWidth: 0,
            scaledDepth: 0
        )
        #expect(positions.count == 8)
        // Erster Sitz oben (12 Uhr) → x≈0, y negativ
        #expect(abs(positions[0].x) < 0.5)
        #expect(positions[0].y < 0)
        // Sitze gleichmäßig um Zentrum (gleicher Abstand zur Mitte)
        let radius = SeatLayout.seatGap + 50  // diameter/2 + gap
        for p in positions {
            let dist = sqrt(p.x * p.x + p.y * p.y)
            #expect(abs(dist - radius) < 0.5)
        }
    }

    @Test("Rectangular table uses long sides + ends")
    func rectTable() {
        let positions = SeatLayout.positions(
            shape: .rectangular,
            capacity: 10,
            scaledDiameter: 0,
            scaledWidth: 200,
            scaledDepth: 80
        )
        #expect(positions.count == 10)
        // Erste 4 oben, nächste 4 unten, dann 2 Enden (kapazitätsabhängig)
        // Vereinfacht: Top-Sitze haben y < 0, Bottom y > 0
        let topSeats = positions.filter { $0.y < -10 }
        let bottomSeats = positions.filter { $0.y > 10 }
        #expect(topSeats.count >= 3)
        #expect(bottomSeats.count >= 3)
    }

    @Test("Capacity 0 yields no positions")
    func empty() {
        let positions = SeatLayout.positions(
            shape: .round,
            capacity: 0,
            scaledDiameter: 100,
            scaledWidth: 0,
            scaledDepth: 0
        )
        #expect(positions.isEmpty)
    }

    @Test("Square table distributes around 4 sides")
    func squareTable() {
        let positions = SeatLayout.positions(
            shape: .square,
            capacity: 8,
            scaledDiameter: 0,
            scaledWidth: 120,
            scaledDepth: 0
        )
        #expect(positions.count == 8)
    }
}
#endif
