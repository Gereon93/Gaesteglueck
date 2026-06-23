#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Modell-Mutationen aus dem Kontextmenü (Drehen, Leeren, Tafel lösen).
/// Reines Verhalten ohne UI/State — daher als Helper ausgelagert und testbar.
enum TableCanvasMutations {
    /// Dreht den Tisch um 90°. Bei einer Tafel rotiert die gesamte Gruppe um
    /// ihren gemeinsamen Mittelpunkt.
    static func rotateBy90(table: GuestTable, groupTables: [GuestTable], rules: SeatingRules) {
        let newRot = (table.rotation + 90).truncatingRemainder(dividingBy: 360)
        if table.combinationGroup != nil {
            let geo = TafelLayout.geometry(of: groupTables, rules: rules)
            let cx = Double(geo.center.x)
            let cy = Double(geo.center.y)
            let cosD = cos(Double.pi / 2)
            let sinD = sin(Double.pi / 2)
            for t in groupTables {
                let dx = t.positionX - cx
                let dy = t.positionY - cy
                t.positionX = cx + dx * cosD - dy * sinD
                t.positionY = cy + dx * sinD + dy * cosD
                t.rotation = newRot
            }
        } else {
            table.rotation = newRot
        }
    }

    /// Entfernt alle nicht-gepinnten Gäste vom Tisch (table = nil, seatIndex = nil).
    /// Bei Tafel: leert alle Gruppen-Tische gemeinsam.
    static func clearTable(table: GuestTable, groupTables: [GuestTable]) {
        let targets: [GuestTable] = table.combinationGroup != nil ? groupTables : [table]
        for t in targets {
            for g in t.guests where !g.isPinned {
                g.seatIndex = nil
                g.table = nil
            }
        }
    }

    static func dissolveTafel(table: GuestTable, allTables: [GuestTable]) {
        guard let groupID = table.combinationGroup else { return }
        for t in allTables where t.combinationGroup == groupID {
            t.combinationGroup = nil
            t.combinationOrder = nil
            t.combinationRole = nil
        }
    }
}
#endif
