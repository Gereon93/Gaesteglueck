#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Gemeinsame Tisch-Anlage-Logik für Bibliothek, Inventar-Stepper und
/// Auto-Vorschlag. Reine Logik ohne UI — operiert auf den aktuellen Tischen
/// und dem ModelContext.
enum RoomTableActions {
    static func nextPosition(tableCount: Int) -> (x: Double, y: Double) {
        let cols = 4
        let spacing: Double = 140
        let index = tableCount
        let col = index % cols
        let row = index / cols
        return (x: 100 + Double(col) * spacing, y: 100 + Double(row) * spacing)
    }

    static func nameForNewTable(template: TableTemplate, nextNumber: Int) -> String {
        if template.isBridal { return "Brauttafel" }
        switch template.shape {
        case .rectangular: return "Tafel \(nextNumber)"
        case .square: return "Kindertisch"
        case .round: return "T\(nextNumber)"
        }
    }

    static func addTable(from template: TableTemplate, tables: [GuestTable], in modelContext: ModelContext) {
        let nextNumber = tables.count + 1
        let name = nameForNewTable(template: template, nextNumber: nextNumber)
        let position = nextPosition(tableCount: tables.count)
        let table = GuestTable(
            name: name,
            shape: template.shape,
            diameter: template.diameter,
            width: template.width,
            depth: template.depth,
            positionX: position.x,
            positionY: position.y,
            isChildTable: template.capacity == 4,
            isBridalTable: template.isBridal
        )
        modelContext.insert(table)
    }
}
#endif
