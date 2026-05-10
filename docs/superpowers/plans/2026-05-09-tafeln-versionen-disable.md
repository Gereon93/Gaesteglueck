# KI-Tafeln + Plan-Versionen + Sitze deaktivieren — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Drei zusammenhängende Features in einem Schema-Bump (V4→V5):
- **B:** KI-Vorschläge mit Tafel-Bewusstsein (mehrere rectangular Tische → Tafel)
- **C:** Plan-Versionen (Snapshots speichern, laden, wechseln)
- **D:** Einzelne Sitze deaktivieren (z.B. gegenüber vom Brautpaar)

**Architecture:**
- Schema V5 mit drei neuen Snapshot-Models + `disabledSeatIndicesData` auf `GuestTable` + `rectangularMaxTafelLength` auf `SaalInventar`.
- Auto-Lightweight-Migration (kein migrationPlan).
- KI-Tafel-Aware: Prompt-Erweiterung, Output-JSON-Parser, Apply-Logik mit `combinationGroup`/`combinationOrder`.
- LayoutVersionStore: snapshot/restore/delete reine MainActor-Funktionen.
- Sitz-Disable: per-Tisch `Set<Int>`, gerendert via SeatChipView-Flag.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, Swift Testing.

**Branch:** `feat/tafel-layout-spec` (alle Commits hier).

---

## File Structure

**Create:**
- `Sources/Gaesteglueck/Models/LayoutVersion.swift` — alle vier @Model-Klassen (Version + 3 Snapshots) in einer Datei
- `Sources/Gaesteglueck/Models/Schemas/SchemaV5.swift`
- `Sources/Gaesteglueck/Services/LayoutVersionStore.swift`
- `Sources/Gaesteglueck/Views/LayoutVersionsSheet.swift` — UI für Liste, Speichern, Laden
- `Tests/GaesteglueckTests/Services/LayoutVersionStoreTests.swift`
- `Tests/GaesteglueckTests/Models/SeatDisableTests.swift`

**Modify:**
- `Sources/Gaesteglueck/Models/GuestTable.swift` — `disabledSeatIndicesData` + `effectiveCapacity`
- `Sources/Gaesteglueck/Models/Event.swift` — `versions`-Relation, `activeVersionID`
- `Sources/Gaesteglueck/GaesteglueckApp.swift` — Schema = V5
- `Sources/Gaesteglueck/Services/SaalKonfigurator.swift` — `rectangularMaxTafelLength`, Prompt-Erweiterung, `tafelGroup`-Parser, `validateAndFixTafelGroups`
- `Sources/Gaesteglueck/Views/SaalKonfiguratorView.swift` — Tafel-Stepper, Apply-Logik mit `combinationGroup`
- `Sources/Gaesteglueck/Views/Canvas/SeatChipView.swift` — `isDisabled`, Drop-Skip, Kontext-Menü „Sitz sperren"
- `Sources/Gaesteglueck/Views/Canvas/TableCanvasItemView.swift` — `effectiveCapacity` in Label, `isDisabled` durchreichen, Toggle-Handler
- `Sources/Gaesteglueck/Views/RoomCanvasView.swift` — „Versionen"-Toolbar-Button

---

## Wave-Reihenfolge

- **Wave 1 (Datenmodell):** Tasks 1–3 — disabledSeats, LayoutVersion-Modelle, Schema V5
- **Wave 2 (Sitz-Disable v1):** Task 4 — Render + Toggle (sichtbares Feature, eigenständig getestet)
- **Wave 3 (LayoutVersionStore):** Tasks 5–6 — Store + UI
- **Wave 4 (KI-Tafeln):** Tasks 7–9 — Inventar-Stepper, Prompt+Parser, Apply

---

## Task 1: GuestTable.disabledSeatIndices + effectiveCapacity

**Files:**
- Modify: `Sources/Gaesteglueck/Models/GuestTable.swift`
- Create: `Tests/GaesteglueckTests/Models/SeatDisableTests.swift`

- [ ] **Step 1.1: Test schreiben**

`Tests/GaesteglueckTests/Models/SeatDisableTests.swift`:
```swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Seat Disable")
struct SeatDisableTests {
    @Test("disabledSeatIndices roundtrip")
    func roundtrip() {
        GuestTable.activeRules = .default
        let table = GuestTable(name: "T", shape: .rectangular, width: 140, depth: 80)
        #expect(table.disabledSeatIndices.isEmpty)
        table.disabledSeatIndices = [1, 3]
        #expect(table.disabledSeatIndices == [1, 3])
    }

    @Test("effectiveCapacity subtracts disabled count")
    func effectiveCapacity() {
        GuestTable.activeRules = .default
        let table = GuestTable(name: "T", shape: .rectangular, width: 140, depth: 80)
        #expect(table.effectiveCapacity == 6)
        table.disabledSeatIndices = [0, 4]
        #expect(table.effectiveCapacity == 4)
    }
}
```

- [ ] **Step 1.2: Test laufen lassen — soll FEHLschlagen**

Run: `swift test --filter "Seat Disable"`
Expected: FAIL — `disabledSeatIndices` und `effectiveCapacity` unbekannt.

- [ ] **Step 1.3: GuestTable erweitern**

In `Sources/Gaesteglueck/Models/GuestTable.swift` direkt nach `var combinationOrder: Int?` ergänzen:
```swift
    var disabledSeatIndicesData: Data?
```

In `init` nach `self.combinationOrder = nil` ergänzen:
```swift
        self.disabledSeatIndicesData = nil
```

Direkt nach dem Init-Block (vor dem ersten `var capacity`) ergänzen:
```swift
    var disabledSeatIndices: Set<Int> {
        get {
            guard let data = disabledSeatIndicesData,
                  let arr = try? JSONDecoder().decode([Int].self, from: data)
            else { return [] }
            return Set(arr)
        }
        set {
            disabledSeatIndicesData = try? JSONEncoder().encode(Array(newValue).sorted())
        }
    }

    func effectiveCapacity(rules: SeatingRules) -> Int {
        capacity(rules: rules) - disabledSeatIndices.count
    }

    var effectiveCapacity: Int { effectiveCapacity(rules: GuestTable.activeRules) }
```

- [ ] **Step 1.4: Tests laufen lassen — sollen bestehen**

Run: `swift test --filter "Seat Disable"`
Expected: PASS.

Run: `swift test`
Expected: alle 143 Tests grün.

- [ ] **Step 1.5: Commit**

```bash
git add Sources/Gaesteglueck/Models/GuestTable.swift Tests/GaesteglueckTests/Models/SeatDisableTests.swift
git commit -m "feat(model): GuestTable.disabledSeatIndices + effectiveCapacity"
```

---

## Task 2: LayoutVersion + Snapshot-Models

**Files:**
- Create: `Sources/Gaesteglueck/Models/LayoutVersion.swift`
- Modify: `Sources/Gaesteglueck/Models/Event.swift`

- [ ] **Step 2.1: LayoutVersion.swift anlegen**

`Sources/Gaesteglueck/Models/LayoutVersion.swift`:
```swift
import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class LayoutVersion {
    var id: UUID
    var name: String
    var note: String
    var createdAt: Date
    var event: Event?
    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \LayoutTableSnapshot.version)
    #endif
    var tables: [LayoutTableSnapshot] = []
    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \LayoutLabelSnapshot.version)
    #endif
    var labels: [LayoutLabelSnapshot] = []
    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \LayoutSeatSnapshot.version)
    #endif
    var seats: [LayoutSeatSnapshot] = []

    init(name: String, note: String = "") {
        self.id = UUID()
        self.name = name
        self.note = note
        self.createdAt = .now
        self.event = nil
    }
}

#if canImport(SwiftData)
@Model
#endif
final class LayoutTableSnapshot {
    var id: UUID
    var name: String
    var shape: TableShape
    var diameter: Double
    var width: Double
    var depth: Double
    var positionX: Double
    var positionY: Double
    var rotation: Double
    var isChildTable: Bool
    var isBridalTable: Bool
    var combinationGroup: UUID?
    var combinationOrder: Int?
    var disabledSeatIndicesData: Data?
    var version: LayoutVersion?

    init(
        id: UUID,
        name: String,
        shape: TableShape,
        diameter: Double,
        width: Double,
        depth: Double,
        positionX: Double,
        positionY: Double,
        rotation: Double,
        isChildTable: Bool,
        isBridalTable: Bool,
        combinationGroup: UUID?,
        combinationOrder: Int?,
        disabledSeatIndicesData: Data?
    ) {
        self.id = id
        self.name = name
        self.shape = shape
        self.diameter = diameter
        self.width = width
        self.depth = depth
        self.positionX = positionX
        self.positionY = positionY
        self.rotation = rotation
        self.isChildTable = isChildTable
        self.isBridalTable = isBridalTable
        self.combinationGroup = combinationGroup
        self.combinationOrder = combinationOrder
        self.disabledSeatIndicesData = disabledSeatIndicesData
        self.version = nil
    }
}

#if canImport(SwiftData)
@Model
#endif
final class LayoutLabelSnapshot {
    var id: UUID
    var text: String
    var positionX: Double
    var positionY: Double
    var rotation: Double
    var version: LayoutVersion?

    init(id: UUID, text: String, positionX: Double, positionY: Double, rotation: Double) {
        self.id = id
        self.text = text
        self.positionX = positionX
        self.positionY = positionY
        self.rotation = rotation
        self.version = nil
    }
}

#if canImport(SwiftData)
@Model
#endif
final class LayoutSeatSnapshot {
    var id: UUID
    var guestID: UUID
    var tableID: UUID
    var seatIndex: Int?
    var version: LayoutVersion?

    init(guestID: UUID, tableID: UUID, seatIndex: Int?) {
        self.id = UUID()
        self.guestID = guestID
        self.tableID = tableID
        self.seatIndex = seatIndex
        self.version = nil
    }
}
```

- [ ] **Step 2.2: Event erweitern**

In `Sources/Gaesteglueck/Models/Event.swift` nach `var labels: [CanvasLabel] = []` ergänzen:
```swift
    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \LayoutVersion.event)
    #endif
    var versions: [LayoutVersion] = []
    var activeVersionID: UUID?
```

In `init` ergänzen (vor `self.createdAt = .now`):
```swift
        self.versions = []
        self.activeVersionID = nil
```

- [ ] **Step 2.3: Build prüfen**

Run: `swift build`
Expected: SUCCESS.

- [ ] **Step 2.4: Commit**

```bash
git add Sources/Gaesteglueck/Models/LayoutVersion.swift Sources/Gaesteglueck/Models/Event.swift
git commit -m "feat(model): LayoutVersion + Snapshot-Modelle fuer Plan-Versionen"
```

---

## Task 3: Schema V5

**Files:**
- Create: `Sources/Gaesteglueck/Models/Schemas/SchemaV5.swift`
- Modify: `Sources/Gaesteglueck/GaesteglueckApp.swift`

- [ ] **Step 3.1: SchemaV5 anlegen**

`Sources/Gaesteglueck/Models/Schemas/SchemaV5.swift`:
```swift
#if canImport(SwiftData)
import Foundation
import SwiftData

enum SchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Event.self,
            Guest.self,
            GuestTable.self,
            Tag.self,
            Constraint.self,
            RoomPlan.self,
            TableInventoryItem.self,
            CanvasLabel.self,
            LayoutVersion.self,
            LayoutTableSnapshot.self,
            LayoutLabelSnapshot.self,
            LayoutSeatSnapshot.self,
        ]
    }
}
#endif
```

- [ ] **Step 3.2: GaesteglueckApp Schema-Referenz**

In `Sources/Gaesteglueck/GaesteglueckApp.swift` Zeile 33:
```swift
        let schema = Schema(SchemaV5.models)
```

`migrationPlan` BLEIBT entfernt (Auto-Lightweight).

- [ ] **Step 3.3: Build + Tests**

Run: `swift build && swift test`
Expected: SUCCESS, alle Tests grün.

- [ ] **Step 3.4: Commit**

```bash
git add Sources/Gaesteglueck/Models/Schemas/SchemaV5.swift Sources/Gaesteglueck/GaesteglueckApp.swift
git commit -m "feat(schema): SchemaV5 mit LayoutVersion + Snapshot-Modelle

Auto-Lightweight-Migration."
```

---

## Task 4: SeatChipView mit isDisabled + UI in TableCanvasItemView

**Files:**
- Modify: `Sources/Gaesteglueck/Views/Canvas/SeatChipView.swift`
- Modify: `Sources/Gaesteglueck/Views/Canvas/TableCanvasItemView.swift`

- [ ] **Step 4.1: SeatChipView erweitern**

In `Sources/Gaesteglueck/Views/Canvas/SeatChipView.swift` nach `let onClear: () -> Void` ergänzen:
```swift
    let isDisabled: Bool
    let onToggleDisabled: () -> Void
```

(Default-Werte sind nicht erlaubt bei `let`-Property mit Memberwise-Init in struct — alle Aufrufer müssen aktualisiert werden, siehe nächster Schritt.)

In den `var body` Render-Block:

Direkt unter dem `Circle().fill(fillColor)`-Rendering, vor den Initials, ergänzen — sodass disabled durchgestrichen wirkt:
```swift
            if isDisabled {
                // Diagonale Linie für gesperrt
                Path { p in
                    p.move(to: CGPoint(x: 4, y: 18))
                    p.addLine(to: CGPoint(x: 18, y: 4))
                }
                .stroke(Tokens.Colors.ink3, lineWidth: 1.5)
            }
```

`fillColor`-Property anpassen:
```swift
    private var fillColor: Color {
        if isDisabled { return Tokens.Colors.surface.opacity(0.4) }
        if isDropTargeted { return Tokens.Colors.accentSoft }
        return occupant == nil ? Tokens.Colors.surface : Tokens.Colors.accentTint
    }
```

`.dropDestination(for: String.self)` umschließen mit `isDisabled`-Check:
```swift
        .dropDestination(for: String.self) { items, _ in
            guard !isDisabled else { return false }
            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
            return onDrop(id)
        } isTargeted: { targeted in
            isDropTargeted = !isDisabled && targeted
        }
```

`.contextMenu`-Block ergänzen — neuer Eintrag am Ende:
```swift
        .contextMenu {
            if occupant != nil {
                Button(role: .destructive) {
                    onClear()
                } label: {
                    Label("Sitzplatz freigeben", systemImage: "person.fill.xmark")
                }
            }
            Button {
                onToggleDisabled()
            } label: {
                Label(isDisabled ? "Sitz aktivieren" : "Sitz sperren",
                      systemImage: isDisabled ? "checkmark.circle" : "xmark.circle")
            }
        }
```

`conditionalDraggable` lassen — wenn ein Gast da ist und Sitz disabled wird, soll der Gast trotzdem draggable bleiben (User entfernt ihn selbst). Pragmatisch ok.

- [ ] **Step 4.2: TableCanvasItemView Aufrufer aktualisieren**

In `Sources/Gaesteglueck/Views/Canvas/TableCanvasItemView.swift` `seatChipsLayer` zwei `SeatChipView`-Konstruktoren erweitern.

**Tafel-Branch (innerhalb `if let geo = tafelGeometry`):**
```swift
                let targetTable = groupTables.first(where: { $0.id == seat.tableID }) ?? table
                let isSeatDisabled = targetTable.disabledSeatIndices.contains(seat.localSeatIndex)
                SeatChipView(
                    seatIndex: idx,
                    occupant: occ,
                    onDrop: { guestID in
                        assignGuestToTafelSeat(guestID: guestID, seat: seat)
                    },
                    onClear: {
                        if let occ {
                            occ.seatIndex = nil
                        }
                    },
                    isDisabled: isSeatDisabled,
                    onToggleDisabled: {
                        var s = targetTable.disabledSeatIndices
                        if s.contains(seat.localSeatIndex) {
                            s.remove(seat.localSeatIndex)
                        } else {
                            s.insert(seat.localSeatIndex)
                            if let occ { occ.seatIndex = nil }
                        }
                        targetTable.disabledSeatIndices = s
                    }
                )
```

**Solo-Branch (else):**
```swift
                SeatChipView(
                    seatIndex: idx,
                    occupant: occupant(at: idx),
                    onDrop: { guestID in
                        assignGuestToSeat(guestID: guestID, seatIndex: idx)
                    },
                    onClear: {
                        if let occ = occupant(at: idx) {
                            occ.seatIndex = nil
                        }
                    },
                    isDisabled: table.disabledSeatIndices.contains(idx),
                    onToggleDisabled: {
                        var s = table.disabledSeatIndices
                        if s.contains(idx) {
                            s.remove(idx)
                        } else {
                            s.insert(idx)
                            if let occ = occupant(at: idx) { occ.seatIndex = nil }
                        }
                        table.disabledSeatIndices = s
                    }
                )
```

**capacityLabel** auf `effectiveCapacity` umstellen:
```swift
    private var capacityLabel: String {
        if let geo = tafelGeometry {
            let occupied = groupTables.reduce(0) { $0 + $1.guests.filter { $0.seatIndex != nil }.count }
            let totalDisabled = groupTables.reduce(0) { $0 + $1.disabledSeatIndices.count }
            return "\(occupied)/\(geo.capacity - totalDisabled)"
        }
        return "\(table.guests.count)/\(table.effectiveCapacity)"
    }
```

`isFull`-Konsumenten in der View checken — der existierende Code nutzt `table.isFull`. `isFull` ist auf `GuestTable` definiert; muss um `effectiveCapacity` erweitert werden:

In `Sources/Gaesteglueck/Models/GuestTable.swift` die `isFull`-Property anpassen:
```swift
    var isFull: Bool { guests.count >= effectiveCapacity }
```

- [ ] **Step 4.3: Build + Tests**

Run: `swift build`
Expected: SUCCESS.

Run: `swift test`
Expected: alle bestehenden Tests grün; SeatDisableTests grün.

- [ ] **Step 4.4: Commit**

```bash
git add Sources/Gaesteglueck/Views/Canvas/SeatChipView.swift \
        Sources/Gaesteglueck/Views/Canvas/TableCanvasItemView.swift \
        Sources/Gaesteglueck/Models/GuestTable.swift
git commit -m "feat(canvas): Sitze per Rechtsklick sperren

Disabled-Flag im SeatChipView, Drop-Target gesperrt, durchgestrichen.
effectiveCapacity zieht gesperrte Sitze ab; Tafel summiert sie."
```

---

## Task 5: LayoutVersionStore Service + Tests

**Files:**
- Create: `Sources/Gaesteglueck/Services/LayoutVersionStore.swift`
- Create: `Tests/GaesteglueckTests/Services/LayoutVersionStoreTests.swift`

- [ ] **Step 5.1: Service implementieren**

`Sources/Gaesteglueck/Services/LayoutVersionStore.swift`:
```swift
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
        // 1. Gast-Sitz-Refs lösen
        for g in currentGuests {
            g.table = nil
            g.seatIndex = nil
        }
        // 2. Aktuelle Tische und Labels löschen
        for t in currentTables { modelContext.delete(t) }
        for l in currentLabels { modelContext.delete(l) }

        // 3. Aus Snapshot neu anlegen
        var newTablesByID: [UUID: GuestTable] = [:]
        for snap in version.tables {
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
            // ID kann bei SwiftData nicht direkt zugewiesen werden — wir mappen über alte → neue ID via guestID-Lookup unten.
            t.combinationGroup = snap.combinationGroup
            t.combinationOrder = snap.combinationOrder
            t.disabledSeatIndicesData = snap.disabledSeatIndicesData
            modelContext.insert(t)
            newTablesByID[snap.id] = t   // Mapping: alte SnapshotID → neuer GuestTable
        }

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

        // 4. Gäste an Tische zuweisen über Snapshot-Map
        let guestsByID = Dictionary(uniqueKeysWithValues: currentGuests.map { ($0.id, $0) })
        for seatSnap in version.seats {
            guard let guest = guestsByID[seatSnap.guestID],
                  let table = newTablesByID[seatSnap.tableID]
            else { continue }
            guest.table = table
            guest.seatIndex = seatSnap.seatIndex
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
```

**Wichtiger Hinweis:** `GuestTable.id` ist bei SwiftData nicht direkt zuweisbar nach Init, daher kommen die wiederhergestellten Tische mit NEUEN IDs daher. Das Mapping über `newTablesByID` (Snapshot-ID → neuer Tisch-Reference) übersetzt für die Gast-Zuweisung. Externes Verhalten bleibt korrekt.

- [ ] **Step 5.2: Tests**

`Tests/GaesteglueckTests/Services/LayoutVersionStoreTests.swift`:
```swift
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

        // Alter t1 wurde gelöscht, neuer angelegt — finden wir über g1.table
        #expect(g1.table != nil)
        #expect(g1.table?.name == "T1")
        #expect(g1.table?.positionX == 0)  // wieder Original
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
```

- [ ] **Step 5.3: Build + Tests**

Run: `swift test --filter LayoutVersionStore`
Expected: PASS, 3 Tests grün.

Run: `swift test`
Expected: alle Tests grün.

- [ ] **Step 5.4: Commit**

```bash
git add Sources/Gaesteglueck/Services/LayoutVersionStore.swift \
        Tests/GaesteglueckTests/Services/LayoutVersionStoreTests.swift
git commit -m "feat(service): LayoutVersionStore — snapshot/restore/delete

Snapshot kopiert Tische/Labels/Sitzzuweisungen in parallele Entities.
Restore loescht aktuellen Stand und legt aus Snapshot neu an, mappt
Gaeste per UUID-Lookup auf neue Tisch-Instanzen."
```

---

## Task 6: LayoutVersionsSheet UI + Toolbar-Button

**Files:**
- Create: `Sources/Gaesteglueck/Views/LayoutVersionsSheet.swift`
- Modify: `Sources/Gaesteglueck/Views/RoomCanvasView.swift`

- [ ] **Step 6.1: LayoutVersionsSheet anlegen**

`Sources/Gaesteglueck/Views/LayoutVersionsSheet.swift`:
```swift
#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct LayoutVersionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let event: Event
    @Query private var allTables: [GuestTable]
    @Query private var allLabels: [CanvasLabel]
    @Query private var allGuests: [Guest]
    @State private var newName: String = ""
    @State private var pendingRestore: LayoutVersion?

    private var versions: [LayoutVersion] {
        event.versions.sorted(by: { $0.createdAt > $1.createdAt })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                List {
                    Section("Aktuell speichern") {
                        HStack {
                            TextField("z.B. Idee 1", text: $newName)
                            Button("Speichern") {
                                let name = newName.isEmpty ? "Idee \(versions.count + 1)" : newName
                                _ = LayoutVersionStore.snapshot(
                                    event: event,
                                    name: name,
                                    note: "",
                                    tables: allTables,
                                    labels: allLabels,
                                    guests: allGuests,
                                    modelContext: modelContext
                                )
                                newName = ""
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                    }

                    Section("Gespeicherte Versionen") {
                        if versions.isEmpty {
                            Text("Noch keine Versionen.")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(versions) { v in
                            HStack {
                                if event.activeVersionID == v.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(v.name).font(.body.weight(.medium))
                                    Text(v.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Laden") { pendingRestore = v }
                                Button(role: .destructive) {
                                    LayoutVersionStore.delete(version: v, event: event, modelContext: modelContext)
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Versionen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .confirmationDialog(
                "Aktuellen Stand verwerfen?",
                isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
                presenting: pendingRestore
            ) { v in
                Button("Erst speichern, dann laden") {
                    let name = "Auto-Sicherung vor \(v.name)"
                    _ = LayoutVersionStore.snapshot(
                        event: event, name: name, note: "",
                        tables: allTables, labels: allLabels, guests: allGuests,
                        modelContext: modelContext
                    )
                    LayoutVersionStore.restore(
                        version: v, event: event,
                        currentTables: allTables, currentLabels: allLabels, currentGuests: allGuests,
                        modelContext: modelContext
                    )
                    pendingRestore = nil
                    dismiss()
                }
                Button("Verwerfen und laden", role: .destructive) {
                    LayoutVersionStore.restore(
                        version: v, event: event,
                        currentTables: allTables, currentLabels: allLabels, currentGuests: allGuests,
                        modelContext: modelContext
                    )
                    pendingRestore = nil
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) { pendingRestore = nil }
            }
        }
        .frame(minWidth: 480, minHeight: 400)
    }
}
#endif
```

- [ ] **Step 6.2: RoomCanvasView Toolbar-Button**

In `Sources/Gaesteglueck/Views/RoomCanvasView.swift` neuen `@State` ergänzen:
```swift
    @State private var showingVersionsSheet = false
```

In dem `+ Label`-HStack-Bereich (oder als zweiter Button im selben Overlay), neben „Label" einen weiteren Button:
```swift
                    Button {
                        showingVersionsSheet = true
                    } label: {
                        Label("Versionen", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .disabled(event == nil)
```

Dann den Sheet-Modifier am gleichen View-Level wie der Label-Button:
```swift
            .sheet(isPresented: $showingVersionsSheet) {
                if let event = event {
                    LayoutVersionsSheet(event: event)
                }
            }
```

(Read RoomCanvasView, finde den Bereich, in dem der „+ Label"-Button gerendert wird, und ergänze daneben.)

- [ ] **Step 6.3: Build + Manueller Test**

Run: `swift build && swift test`
Expected: SUCCESS.

Manueller Smoke-Test (User durchläuft):
- „Versionen"-Button → Sheet öffnet sich
- „Idee 1" eintippen → Speichern → Version erscheint
- Tische verschieben → „Idee 2" speichern
- „Idee 1" laden → bei Confirm-Dialog „Verwerfen und laden" → Saalplan zurück auf Idee 1

- [ ] **Step 6.4: Commit**

```bash
git add Sources/Gaesteglueck/Views/LayoutVersionsSheet.swift \
        Sources/Gaesteglueck/Views/RoomCanvasView.swift
git commit -m "feat(canvas): Versions-Sheet mit Speichern, Laden, Loeschen"
```

---

## Task 7: SaalInventar.rectangularMaxTafelLength + UI-Stepper

**Files:**
- Modify: `Sources/Gaesteglueck/Services/SaalKonfigurator.swift`
- Modify: `Sources/Gaesteglueck/Views/SaalKonfiguratorView.swift`

- [ ] **Step 7.1: Inventar erweitern**

In `Sources/Gaesteglueck/Services/SaalKonfigurator.swift` `SaalInventar` ergänzen:
```swift
struct SaalInventar: Sendable, Equatable {
    // ... existing ...
    var rectangularMaxTafelLength: Int = 1   // 1 = nur Solo
    // ... existing ...
}
```

(Default 1 = bestehendes Verhalten unverändert.)

- [ ] **Step 7.2: View-Stepper ergänzen**

In `Sources/Gaesteglueck/Views/SaalKonfiguratorView.swift` direkt unter dem rechteckigen Tisch-Block (Zeile ~145, im Bereich `doubleField(label: "Tiefe (cm)", value: $inventory.rectangularDepthCM)`) ergänzen:
```swift
                stepperField(label: "Max. Tische pro Tafel", value: $inventory.rectangularMaxTafelLength, range: 1...8)
```

(Wenn `rectangularMaxTafelLength == 1`, dann nur Solo-Tische erlaubt. Wenn ≥2, kann KI Tafeln bauen.)

- [ ] **Step 7.3: Build + Tests**

Run: `swift build && swift test`
Expected: SUCCESS.

- [ ] **Step 7.4: Commit**

```bash
git add Sources/Gaesteglueck/Services/SaalKonfigurator.swift \
        Sources/Gaesteglueck/Views/SaalKonfiguratorView.swift
git commit -m "feat(konfigurator): rectangularMaxTafelLength im Inventar"
```

---

## Task 8: KI-Prompt + JSON-Parser für Tafeln

**Files:**
- Modify: `Sources/Gaesteglueck/Services/SaalKonfigurator.swift`

- [ ] **Step 8.1: ProposedTable erweitern**

In `Sources/Gaesteglueck/Services/SaalKonfigurator.swift` `ProposedTable` ergänzen:
```swift
struct ProposedTable: Sendable, Identifiable, Equatable {
    var id: UUID = UUID()
    var shape: TableShape
    var name: String
    var widthCM: Double
    var depthCM: Double
    var diameterCM: Double
    var capacity: Int
    var isBridal: Bool
    var isChild: Bool
    var clusters: [String]
    var reason: String
    var tafelGroup: String?
    var tafelOrder: Int?
}
```

- [ ] **Step 8.2: parseTable um tafelGroup/tafelOrder**

In `parseTable(_ entry:inventory:)` (Zeile ~244) am Ende vor dem `return ProposedTable(...)`:
```swift
        let tafelGroup = entry["tafelGroup"] as? String
        let tafelOrder = entry["tafelOrder"] as? Int
```

Im `return ProposedTable(...)` die zwei neuen Felder mit angeben.

- [ ] **Step 8.3: Prompt-Erweiterung**

In `buildUserPrompt` direkt nach `prompt += clusterContext` und vor `return prompt`:
```swift
        let rules = GuestTable.activeRules
        prompt += "\n## Sitzregel\n\nSitzabstand: \(Int(rules.seatWidthCm)) cm pro Person.\n"

        if inventory.rectangularMaxTafelLength > 1 {
            let maxLen = inventory.rectangularMaxTafelLength
            let w = Int(inventory.rectangularWidthCM)
            let d = Int(inventory.rectangularDepthCM)
            let sw = rules.seatWidthCm
            let cap2 = 2 * Int(Double(2 * w) / sw) + 2
            let cap3 = 2 * Int(Double(3 * w) / sw) + 2
            let cap4 = 2 * Int(Double(4 * w) / sw) + 2
            prompt += """

## Tafel-Möglichkeit

Aus den rechteckigen \(w)×\(d) cm Tischen kannst du Tafeln bauen, indem du sie aneinanderschiebst. Erlaubte Tafel-Längen: 2 bis \(maxLen) Tische.

Eine Tafel aus N solchen Tischen hat 2*floor(N*\(w)/\(Int(sw))) + 2 Plätze.
Beispiel-Tafeln (mit Sitzabstand \(Int(sw))cm):
- 2×\(w)×\(d) → \(cap2) Plätze
- 3×\(w)×\(d) → \(cap3) Plätze
- 4×\(w)×\(d) → \(cap4) Plätze

Bevorzuge Tafeln, wenn eine zusammenhängende Gruppe größer ist als ein einzelner Tisch fasst. Markiere Tafel-Mitglieder im Output:
- "tafelGroup": "G1" (oder G2, G3 ...) bei allen Mitgliedern derselben Tafel
- "tafelOrder": 0, 1, 2 ... in Reihenfolge der Tafel
- Alle Mitglieder einer Tafel haben gleiche depthCM

"""
        }
```

- [ ] **Step 8.4: validateAndFixTafelGroups**

Zwischen `parseResponse` und `enforceInventoryLimits` neue Funktion ergänzen:
```swift
    private func validateAndFixTafelGroups(_ tables: [ProposedTable], inventory: SaalInventar) -> [ProposedTable] {
        var bySolo: [ProposedTable] = []
        var byGroup: [String: [ProposedTable]] = [:]
        for t in tables {
            if let g = t.tafelGroup {
                byGroup[g, default: []].append(t)
            } else {
                bySolo.append(t)
            }
        }

        var result = bySolo
        for (_, members) in byGroup {
            let sorted = members.sorted { ($0.tafelOrder ?? 0) < ($1.tafelOrder ?? 0) }
            // Validate: depths gleich
            let depths = Set(sorted.map { $0.depthCM })
            // Validate: tafelOrder lückenlos 0..n-1
            let orders = sorted.compactMap { $0.tafelOrder }
            let expectedOrders = Array(0..<sorted.count)
            // Validate: Länge ≤ maxTafelLength
            let withinMax = sorted.count <= inventory.rectangularMaxTafelLength
            // Validate: alle rechteckig
            let allRect = sorted.allSatisfy { $0.shape == .rectangular }

            let valid = depths.count == 1 && orders == expectedOrders && withinMax && allRect && sorted.count >= 2

            if valid {
                result.append(contentsOf: sorted)
            } else {
                // Degradieren: Group/Order entfernen → werden zu Solos
                for var m in sorted {
                    m.tafelGroup = nil
                    m.tafelOrder = nil
                    result.append(m)
                }
            }
        }
        return result
    }
```

In `parseResponse` aufrufen vor `enforceInventoryLimits`:
```swift
        let parsed_ = tablesRaw.compactMap { entry in parseTable(entry, inventory: inventory) }
        let groupValidated = validateAndFixTafelGroups(parsed_, inventory: inventory)
        let validated = enforceInventoryLimits(groupValidated, inventory: inventory)
```

- [ ] **Step 8.5: System-Prompt JSON-Beispiel ergänzen**

In `buildSystemPrompt`-Block den JSON-Output-Beispiel ergänzen — nach den existierenden Tisch-Beispielen einen Tafel-Block hinzufügen:
```
,
{
  "shape": "rectangular",
  "widthCM": 140,
  "depthCM": 80,
  "name": "Großfamilie Maier",
  "capacity": 6,
  "isBridal": false,
  "isChild": false,
  "tafelGroup": "G1",
  "tafelOrder": 0,
  "clusters": ["Familie Maier"],
  "reason": "Erster von 3 verbundenen Tischen — ergibt 16 Plätze."
},
{
  "shape": "rectangular",
  "widthCM": 140,
  "depthCM": 80,
  "name": "Großfamilie Maier",
  "capacity": 6,
  "isBridal": false,
  "isChild": false,
  "tafelGroup": "G1",
  "tafelOrder": 1,
  "clusters": ["Familie Maier"],
  "reason": "Mittelteil der 16er-Tafel."
}
```

(Rohstring-Anpassung — vorsichtig editieren.)

- [ ] **Step 8.6: Build + Tests**

Run: `swift build && swift test`
Expected: SUCCESS.

- [ ] **Step 8.7: Commit**

```bash
git add Sources/Gaesteglueck/Services/SaalKonfigurator.swift
git commit -m "feat(konfigurator): KI-Prompt mit Tafel-Bewusstsein

ProposedTable um tafelGroup/tafelOrder erweitert.
buildUserPrompt fuegt Tafel-Hinweis hinzu wenn maxTafelLength > 1.
validateAndFixTafelGroups filtert inkonsistente Gruppen."
```

---

## Task 9: SaalKonfigurator Apply-Logik mit combinationGroup

**Files:**
- Modify: `Sources/Gaesteglueck/Views/SaalKonfiguratorView.swift`

- [ ] **Step 9.1: insertProposedTables erweitern**

In `Sources/Gaesteglueck/Views/SaalKonfiguratorView.swift` `insertProposedTables(_:)` (Zeile ~542) ersetzen durch:
```swift
    private func insertProposedTables(_ specs: [ProposedTable]) -> [GuestTable] {
        let baseIndex = existingTables.count
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
                // Tafel-Mitglied
                let groupID = groupIDs[group] ?? UUID()
                groupIDs[group] = groupID
                table.combinationGroup = groupID
                table.combinationOrder = order

                if order == 0 {
                    let anchor = nextGridPosition(for: soloIndex)
                    groupAnchors[group] = anchor
                    table.positionX = anchor.x
                    table.positionY = anchor.y
                    groupCursorOffset[group] = spec.widthCM
                    soloIndex += 1
                } else {
                    let anchor = groupAnchors[group] ?? nextGridPosition(for: soloIndex)
                    let offset = groupCursorOffset[group] ?? 0
                    table.positionX = anchor.x + offset
                    table.positionY = anchor.y
                    groupCursorOffset[group] = offset + spec.widthCM
                }
            } else {
                // Solo
                let pos = nextGridPosition(for: soloIndex)
                table.positionX = pos.x
                table.positionY = pos.y
                soloIndex += 1
            }

            modelContext.insert(table)
            created.append(table)
        }

        // Tafel-Member zentrieren um Owner-Mittelpunkt: bislang stehen Tische
        // mit Kursor-X von 0 ausgehend nach rechts. Verschiebe so dass Owner
        // in der Mitte der Tafel landet.
        for (group, members) in Dictionary(grouping: created.filter { $0.combinationGroup != nil }, by: { $0.combinationGroup! }) {
            _ = group
            let totalWidth = members.reduce(0.0) { $0 + $1.width }
            let owner = members.first(where: { ($0.combinationOrder ?? 0) == 0 })
            guard let owner = owner else { continue }
            let originalX = owner.positionX
            // Owner-Mitte sollte bei (originalX + totalWidth/2 - owner.width/2 - prevSum) liegen
            // Pragmatisch: alle in Tafel verschieben um -totalWidth/2 + owner.width/2
            let shift = -totalWidth / 2 + owner.width / 2
            for m in members {
                m.positionX += shift
            }
        }

        return created
    }
```

- [ ] **Step 9.2: Build + Tests**

Run: `swift build && swift test`
Expected: SUCCESS.

- [ ] **Step 9.3: Commit**

```bash
git add Sources/Gaesteglueck/Views/SaalKonfiguratorView.swift
git commit -m "feat(konfigurator): Apply legt Tafeln mit combinationGroup an

Tafel-Mitglieder werden aneinandergeschoben und gemeinsam zentriert."
```

---

## Task 10: Final Test + Smoke

- [ ] **Step 10.1: Vollständiger Test-Lauf**

Run: `swift test`
Expected: alle Tests grün (≥147 erwartet).

- [ ] **Step 10.2: App-Smoke-Test**

(User checkt manuell):
- App startet, Schema-Migration V4→V5 sauber.
- SaalKonfigurator: „Max. Tische pro Tafel" Stepper sichtbar; auf 4 setzen.
- KI-Vorschlag generieren mit ~20 Gästen, 2 Großfamilien (10+8), Freundeskreis (6).
- Erwartung: Vorschlag enthält 1 Tafel à 3 Tische (16 Plätze) + 1 Tafel à 2 Tische (10 Plätze) + ggf. Rundtisch.
- Apply → Tische erscheinen als Tafel auf Canvas.
- Versionen: Sheet öffnen, „Idee 1" speichern, Tische bewegen, „Idee 2" speichern, „Idee 1" laden → Stand kommt zurück.
- Sitz-Disable: Rechtsklick auf einen Sitzchip → „Sitz sperren" → Sitz wird durchgestrichen, Drop nicht möglich. Capacity zeigt z.B. „2/4" statt „2/6".

---

## Self-Review

**Spec-Coverage:**
- Spec B Sektion 1 (JSON): Task 8 ✓
- Spec B Sektion 2 (Inventar): Task 7 ✓
- Spec B Sektion 3 (Prompt): Task 8 ✓
- Spec B Sektion 4 (Validation): Task 8 ✓
- Spec B Sektion 5 (Apply): Task 9 ✓
- Spec C Sektion 1 (Datenmodell): Task 2 ✓
- Spec C Sektion 2 (Save/Restore): Task 5 ✓
- Spec C Sektion 3 (UI): Task 6 ✓
- Spec C Sektion 4 (Dirty-Tracking): explizit weggelassen ("immer Confirm") — Spec sagt das selbst
- Spec C Sektion 6 (Schema V5): Task 3 ✓
- Spec D Sektion 1 (Datenmodell): Task 1 ✓
- Spec D Sektion 2 (Capacity): Task 1 + Task 4 (`isFull`/`capacityLabel`) ✓
- Spec D Sektion 3 (UI): Task 4 ✓

**Type-Konsistenz:**
- `LayoutVersion`/`LayoutTableSnapshot`/`LayoutLabelSnapshot`/`LayoutSeatSnapshot` durchgängig.
- `disabledSeatIndices: Set<Int>` (computed) und `disabledSeatIndicesData: Data?` (stored) konsistent.
- `tafelGroup: String?`/`tafelOrder: Int?` auf ProposedTable konsistent.
- `effectiveCapacity` definiert in Task 1, genutzt in Task 4.

**Placeholder-Scan:** keine TBD/TODO. Step 8.5 ist etwas weich (System-Prompt-Anpassung als Rohstring) — Implementer muss vorhandenen `buildSystemPrompt` lesen und das Beispiel sauber einfügen.

Plan ist konsistent. Bereit für Execution.
