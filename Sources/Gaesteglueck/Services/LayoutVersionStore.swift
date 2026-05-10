#if canImport(SwiftData)
import Foundation
import SwiftData

@MainActor
enum LayoutVersionStore {
    static func snapshot(
        event: Event,
        name: String,
        note: String,
        tables: [GuestTable],
        labels: [CanvasLabel],
        guests: [Guest],
        modelContext: ModelContext
    ) -> LayoutVersion {
        let version = LayoutVersion(name: name, note: note)
        version.event = event
        modelContext.insert(version)

        for t in tables {
            let snap = LayoutTableSnapshot(
                id: t.id,
                name: t.name,
                shape: t.shape,
                diameter: t.diameter,
                width: t.width,
                depth: t.depth,
                positionX: t.positionX,
                positionY: t.positionY,
                rotation: t.rotation,
                isChildTable: t.isChildTable,
                isBridalTable: t.isBridalTable,
                combinationGroup: t.combinationGroup,
                combinationOrder: t.combinationOrder,
                disabledSeatIndicesData: t.disabledSeatIndicesData
            )
            snap.version = version
            modelContext.insert(snap)
        }

        for l in labels {
            let snap = LayoutLabelSnapshot(
                id: l.id,
                text: l.text,
                positionX: l.positionX,
                positionY: l.positionY,
                rotation: l.rotation
            )
            snap.version = version
            modelContext.insert(snap)
        }

        for g in guests where g.table != nil {
            let snap = LayoutSeatSnapshot(
                guestID: g.id,
                tableID: g.table!.id,
                seatIndex: g.seatIndex
            )
            snap.version = version
            modelContext.insert(snap)
        }

        try? modelContext.save()
        return version
    }

    static func restore(
        version: LayoutVersion,
        event: Event,
        currentTables: [GuestTable],
        currentLabels: [CanvasLabel],
        currentGuests: [Guest],
        modelContext: ModelContext
    ) {
        // Strategie: existierende GuestTables IN-PLACE updaten statt
        // delete + recreate — sonst koennen SwiftUI-Views noch auf die
        // geloeschten Refs zugreifen und SwiftData crasht beim Auflesen
        // (BackingData detached from context). Nur Waisen werden geloescht.

        // 1. Sitzplatz-Refs der Gaeste auf null — vor jeder Tisch-Mutation,
        //    damit keine inverse-Relationship-Fault auf einem alten Tisch landet.
        for g in currentGuests {
            g.table = nil
            g.seatIndex = nil
        }

        // 2. Snapshot-Tische anwenden: pro snap.id passenden GuestTable
        //    finden und Felder ueberschreiben; sonst neu anlegen.
        let currentByID = Dictionary(uniqueKeysWithValues: currentTables.map { ($0.id, $0) })
        var tablesByID: [UUID: GuestTable] = [:]
        var snapshotTableIDs: Set<UUID> = []

        for snap in version.tables {
            snapshotTableIDs.insert(snap.id)
            if let existing = currentByID[snap.id] {
                existing.name = snap.name
                existing.shape = snap.shape
                existing.diameter = snap.diameter
                existing.width = snap.width
                existing.depth = snap.depth
                existing.positionX = snap.positionX
                existing.positionY = snap.positionY
                existing.rotation = snap.rotation
                existing.isChildTable = snap.isChildTable
                existing.isBridalTable = snap.isBridalTable
                existing.combinationGroup = snap.combinationGroup
                existing.combinationOrder = snap.combinationOrder
                existing.disabledSeatIndicesData = snap.disabledSeatIndicesData
                tablesByID[snap.id] = existing
            } else {
                let t = GuestTable(
                    name: snap.name,
                    shape: snap.shape,
                    diameter: snap.diameter,
                    width: snap.width,
                    depth: snap.depth,
                    positionX: snap.positionX,
                    positionY: snap.positionY,
                    rotation: snap.rotation,
                    isChildTable: snap.isChildTable,
                    isBridalTable: snap.isBridalTable
                )
                t.id = snap.id
                t.combinationGroup = snap.combinationGroup
                t.combinationOrder = snap.combinationOrder
                t.disabledSeatIndicesData = snap.disabledSeatIndicesData
                modelContext.insert(t)
                tablesByID[snap.id] = t
            }
        }

        // 3. Labels: delete + recreate ist hier ok (keine Live-Refs aus Canvas-Items
        //    auf Label-Objekte ausser via @Query, das wird robust neu aufgeloest).
        for l in currentLabels { modelContext.delete(l) }
        for snap in version.labels {
            let l = CanvasLabel(
                text: snap.text,
                positionX: snap.positionX,
                positionY: snap.positionY,
                rotation: snap.rotation
            )
            l.event = event
            modelContext.insert(l)
        }

        // 4. Gaeste an Tische zuweisen (snap.tableID = original GuestTable.id)
        let guestsByID = Dictionary(uniqueKeysWithValues: currentGuests.map { ($0.id, $0) })
        for seatSnap in version.seats {
            guard let guest = guestsByID[seatSnap.guestID],
                  let table = tablesByID[seatSnap.tableID]
            else { continue }
            guest.table = table
            guest.seatIndex = seatSnap.seatIndex
        }

        // 5. Waisen-Tische (nicht im Snapshot) loeschen — als letztes,
        //    nachdem alle Refs umgehaengt sind.
        for t in currentTables where !snapshotTableIDs.contains(t.id) {
            modelContext.delete(t)
        }

        event.activeVersionID = version.id
        try? modelContext.save()
    }

    static func delete(
        version: LayoutVersion,
        event: Event,
        modelContext: ModelContext
    ) {
        if event.activeVersionID == version.id {
            event.activeVersionID = nil
        }
        modelContext.delete(version)
        try? modelContext.save()
    }
}
#endif
