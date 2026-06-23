#if canImport(SwiftUI) && canImport(SwiftData)
import Foundation
import SwiftData

// Reine Platzierungs- und Übernahme-Logik für den Saal-Konfigurator.
// Ohne UI, damit testbar.
enum SaalTablePlacement {
    static func nextGridPosition(for index: Int) -> (x: Double, y: Double) {
        let cols = 4
        let spacing: Double = 160
        let col = index % cols
        let row = index / cols
        return (Double(col) * spacing + 80, Double(row) * spacing + 80)
    }

    static func mergedTables(existing: [GuestTable], created: [GuestTable]) -> [GuestTable] {
        var seen = Set<UUID>()
        var result: [GuestTable] = []
        for t in existing + created where !seen.contains(t.id) {
            seen.insert(t.id)
            result.append(t)
        }
        return result
    }

    @discardableResult
    static func insertProposedTables(
        _ specs: [ProposedTable],
        existingCount: Int,
        into modelContext: ModelContext
    ) -> [GuestTable] {
        let baseIndex = existingCount
        var created: [GuestTable] = []
        var groupIDs: [String: UUID] = [:]
        var groupAnchors: [String: (x: Double, y: Double)] = [:]
        var groupCursorOffset: [String: Double] = [:]
        var soloIndex = baseIndex

        for spec in specs {
            let table = GuestTable(
                name: spec.name,
                shape: spec.shape,
                diameter: spec.shape == .round ? spec.diameterCM : 0,
                width: spec.shape == .round ? 0 : spec.widthCM,
                depth: spec.shape == .round ? 0 : spec.depthCM,
                positionX: 0,
                positionY: 0,
                isChildTable: spec.isChild,
                isBridalTable: spec.isBridal
            )

            if let group = spec.tafelGroup, let order = spec.tafelOrder {
                let groupID = groupIDs[group] ?? UUID()
                groupIDs[group] = groupID
                table.combinationGroup = groupID
                table.combinationOrder = order

                if order == 0 {
                    let anchor = nextGridPosition(for: soloIndex)
                    groupAnchors[group] = anchor
                    table.positionX = anchor.x
                    table.positionY = anchor.y
                    groupCursorOffset[group] = spec.widthCM / 2
                    soloIndex += 1
                } else {
                    let anchor = groupAnchors[group] ?? nextGridPosition(for: soloIndex)
                    let prevRightEdge = groupCursorOffset[group] ?? 0
                    table.positionX = anchor.x + prevRightEdge + spec.widthCM / 2
                    table.positionY = anchor.y
                    groupCursorOffset[group] = prevRightEdge + spec.widthCM
                }
            } else {
                let pos = nextGridPosition(for: soloIndex)
                table.positionX = pos.x
                table.positionY = pos.y
                soloIndex += 1
            }

            modelContext.insert(table)
            created.append(table)
        }

        // Tafel-Members nachträglich um Owner-Mittelpunkt zentrieren
        let tafelMembers = created.filter { $0.combinationGroup != nil }
        let groupedByID = Dictionary(grouping: tafelMembers, by: { $0.combinationGroup! })
        for (_, members) in groupedByID {
            let totalWidth = members.reduce(0.0) { $0 + $1.width }
            guard let owner = members.first(where: { ($0.combinationOrder ?? 0) == 0 }) else { continue }
            let shift = -totalWidth / 2 + owner.width / 2
            for m in members {
                m.positionX += shift
            }
        }

        return created
    }

    static func applyAssignments(
        _ assignments: [UUID: UUID],
        in tablePool: [GuestTable],
        guests: [Guest]
    ) {
        let tablesByID = Dictionary(uniqueKeysWithValues: tablePool.map { ($0.id, $0) })
        for (guestID, tableID) in assignments {
            guard let guest = guests.first(where: { $0.id == guestID }),
                  let table = tablesByID[tableID],
                  !guest.isPinned else { continue }
            guest.table = table
        }
    }
}
#endif
