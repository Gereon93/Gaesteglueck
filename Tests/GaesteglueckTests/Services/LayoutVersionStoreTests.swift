#if canImport(SwiftData)
import Testing
import Foundation
import SwiftData
@testable import Gaesteglueck

@Suite("LayoutVersionStore")
struct LayoutVersionStoreTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV5.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("Snapshot speichert Tische, Labels und Sitze")
    @MainActor
    func snapshot() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let event = Event(name: "Test")
        ctx.insert(event)

        let table = GuestTable(name: "T1", shape: .rectangular, width: 140, depth: 80)
        ctx.insert(table)

        let label = CanvasLabel(text: "Eingang", positionX: 10, positionY: 20)
        label.event = event
        ctx.insert(label)

        let guest = Guest(firstName: "Anna", lastName: "B")
        guest.table = table
        guest.seatIndex = 2
        ctx.insert(guest)

        let v = LayoutVersionStore.snapshot(
            event: event, name: "Idee 1", note: "",
            tables: [table], labels: [label], guests: [guest],
            modelContext: ctx
        )

        #expect(v.name == "Idee 1")
        #expect(v.tables.count == 1)
        #expect(v.tables[0].name == "T1")
        #expect(v.labels.count == 1)
        #expect(v.seats.count == 1)
        #expect(v.seats[0].seatIndex == 2)
    }

    @Test("Restore stellt Tische und Sitzzuweisungen wieder her")
    @MainActor
    func restore() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let event = Event(name: "Test")
        ctx.insert(event)

        let t1 = GuestTable(name: "T1", shape: .rectangular, width: 140, depth: 80)
        ctx.insert(t1)
        let g1 = Guest(firstName: "Anna", lastName: "B")
        g1.table = t1
        g1.seatIndex = 0
        ctx.insert(g1)

        let v1 = LayoutVersionStore.snapshot(
            event: event, name: "Idee 1", note: "",
            tables: [t1], labels: [], guests: [g1],
            modelContext: ctx
        )

        // Zustand ändern: t1 verschieben, g1 entfernen
        t1.positionX = 999
        g1.table = nil
        g1.seatIndex = nil

        // Restore
        LayoutVersionStore.restore(
            version: v1, event: event,
            currentTables: [t1], currentLabels: [], currentGuests: [g1],
            modelContext: ctx
        )

        #expect(g1.table != nil)
        #expect(g1.table?.name == "T1")
        #expect(g1.table?.positionX == 0)  // Original-Wert
        #expect(g1.seatIndex == 0)
        #expect(event.activeVersionID == v1.id)
    }

    @Test("Delete entfernt Version und resetet activeVersionID")
    @MainActor
    func delete() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let event = Event(name: "Test")
        ctx.insert(event)

        let v = LayoutVersionStore.snapshot(
            event: event, name: "X", note: "",
            tables: [], labels: [], guests: [],
            modelContext: ctx
        )
        event.activeVersionID = v.id

        LayoutVersionStore.delete(version: v, event: event, modelContext: ctx)

        #expect(event.activeVersionID == nil)
    }
}
#endif
