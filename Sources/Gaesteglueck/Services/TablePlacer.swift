import Foundation

struct TablePlacement {
    let tableID: UUID
    let x: Double
    let y: Double
}

enum TablePlacer {
    private static let chairBuffer: Double = 80
    private static let walkwayBuffer: Double = 100
    private static let wallMargin: Double = 120

    static func suggestLayout(
        tables: [GuestTable],
        roomWidthCM: Double,
        roomDepthCM: Double
    ) -> [TablePlacement] {
        var placements: [TablePlacement] = []

        let sorted = tables.sorted { a, b in
            tableFootprint(a) > tableFootprint(b)
        }

        for table in sorted {
            let position = findNonOverlappingPosition(
                    for: table,
                    existing: placements,
                    allTables: tables,
                    roomWidth: roomWidthCM,
                    roomDepth: roomDepthCM
                )

            placements.append(TablePlacement(tableID: table.id, x: position.x, y: position.y))
        }

        return placements
    }

    private static func tableFootprint(_ table: GuestTable) -> Double {
        switch table.shape {
        case .round:
            return table.diameter + 2 * chairBuffer
        case .rectangular, .square:
            return max(table.width, table.depth) + 2 * chairBuffer
        }
    }

    private static func findNonOverlappingPosition(
        for table: GuestTable,
        existing: [TablePlacement],
        allTables: [GuestTable],
        roomWidth: Double,
        roomDepth: Double
    ) -> (x: Double, y: Double) {
        let tableMap = Dictionary(uniqueKeysWithValues: allTables.map { ($0.id, $0) })
        let footprint = tableFootprint(table)

        let stepSize = footprint * 0.8
        var bestPos = (x: roomWidth / 2, y: roomDepth / 2)
        var bestMinDist = -Double.infinity

        var y = wallMargin + footprint / 2
        while y < roomDepth - wallMargin {
            var x = wallMargin + footprint / 2
            while x < roomWidth - wallMargin {
                let minDist = existing.map { p -> Double in
                    let otherTable = tableMap[p.tableID]
                    let otherFootprint = otherTable.map { tableFootprint($0) } ?? footprint
                    let requiredDist = (footprint + otherFootprint) / 2 + walkwayBuffer
                    let actualDist = sqrt(pow(x - p.x, 2) + pow(y - p.y, 2))
                    return actualDist - requiredDist
                }.min() ?? Double.infinity

                if minDist > bestMinDist {
                    bestMinDist = minDist
                    bestPos = (x, y)
                }

                x += stepSize
            }
            y += stepSize
        }

        return bestPos
    }
}
