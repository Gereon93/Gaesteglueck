#if canImport(SwiftUI)
import Foundation
import SwiftUI

enum TafelLayout {
    struct Seat: Equatable {
        let position: CGPoint
        let tableID: UUID
        let localSeatIndex: Int
    }

    struct TafelGeometry {
        let totalWidth: CGFloat
        let depth: CGFloat
        let center: CGPoint
        let rotation: Double
        let capacity: Int
        let seats: [Seat]
    }

    /// Berechnet Tafel-Geometrie aus den Tischen einer Group.
    /// Tische werden nach combinationOrder sortiert; alle haben gleiche depth.
    static func geometry(of tables: [GuestTable], rules: SeatingRules) -> TafelGeometry {
        let sorted = tables.sorted { ($0.combinationOrder ?? 0) < ($1.combinationOrder ?? 0) }
        guard let firstTable = sorted.first, let lastTable = sorted.last else {
            return TafelGeometry(totalWidth: 0, depth: 0, center: .zero, rotation: 0, capacity: 0, seats: [])
        }

        let totalWidth = CGFloat(sorted.reduce(0.0) { $0 + $1.width })
        let depth = CGFloat(sorted.map(\.depth).max() ?? 0)
        let centerX = CGFloat(sorted.reduce(0.0) { $0 + $1.positionX * $1.width } / max(sorted.reduce(0.0) { $0 + $1.width }, 0.001))
        let centerY = CGFloat(firstTable.positionY)
        let rotation = firstTable.rotation

        let seatWidth = CGFloat(rules.seatWidthCm)
        let nLong = Int(totalWidth / seatWidth)
        let seatGap: CGFloat = 14

        var localTopSeats: [CGPoint] = []
        var localBottomSeats: [CGPoint] = []

        for i in 0..<nLong {
            let denom = max(nLong, 1)
            let x = -totalWidth/2 + (CGFloat(i) + 0.5) * (totalWidth / CGFloat(denom))
            localTopSeats.append(CGPoint(x: x, y: -depth/2 - seatGap))
            localBottomSeats.append(CGPoint(x: x, y: depth/2 + seatGap))
        }

        let leftEnd = CGPoint(x: -totalWidth/2 - seatGap, y: 0)
        let rightEnd = CGPoint(x: totalWidth/2 + seatGap, y: 0)

        struct TableRange { let table: GuestTable; let xStart: CGFloat; let xEnd: CGFloat }
        var ranges: [TableRange] = []
        var cursor = -totalWidth/2
        var localIndexCounter: [UUID: Int] = [:]
        for t in sorted {
            let w = CGFloat(t.width)
            ranges.append(TableRange(table: t, xStart: cursor, xEnd: cursor + w))
            cursor += w
            localIndexCounter[t.id] = 0
        }

        func tableForX(_ x: CGFloat) -> GuestTable {
            for r in ranges where x >= r.xStart && x <= r.xEnd { return r.table }
            return lastTable
        }

        var seats: [Seat] = []
        let cosR = cos(rotation * .pi / 180)
        let sinR = sin(rotation * .pi / 180)

        func toGlobal(_ local: CGPoint) -> CGPoint {
            let rx = local.x * cosR - local.y * sinR
            let ry = local.x * sinR + local.y * cosR
            return CGPoint(x: centerX + rx, y: centerY + ry)
        }

        for p in localTopSeats {
            let table = tableForX(p.x)
            let idx = localIndexCounter[table.id, default: 0]
            localIndexCounter[table.id] = idx + 1
            seats.append(Seat(position: toGlobal(p), tableID: table.id, localSeatIndex: idx))
        }
        for p in localBottomSeats {
            let table = tableForX(p.x)
            let idx = localIndexCounter[table.id, default: 0]
            localIndexCounter[table.id] = idx + 1
            seats.append(Seat(position: toGlobal(p), tableID: table.id, localSeatIndex: idx))
        }
        let leftIdx = localIndexCounter[firstTable.id, default: 0]
        localIndexCounter[firstTable.id] = leftIdx + 1
        seats.append(Seat(position: toGlobal(leftEnd), tableID: firstTable.id, localSeatIndex: leftIdx))

        let rightIdx = localIndexCounter[lastTable.id, default: 0]
        localIndexCounter[lastTable.id] = rightIdx + 1
        seats.append(Seat(position: toGlobal(rightEnd), tableID: lastTable.id, localSeatIndex: rightIdx))

        let capacity = 2 * nLong + 2
        return TafelGeometry(
            totalWidth: totalWidth,
            depth: depth,
            center: CGPoint(x: centerX, y: centerY),
            rotation: rotation,
            capacity: capacity,
            seats: seats
        )
    }
}
#endif
