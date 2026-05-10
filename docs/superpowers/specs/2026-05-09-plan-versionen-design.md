# Plan-Versionen (Sitzpläne speichern und laden)

**Datum:** 2026-05-09
**Status:** Design — bereit für Plan
**Scope:** neues Datenmodell, Versions-UI, Save/Load-Logik

## Problem

User probiert Sitzpläne durch („Idee 1: Familien zusammen, Idee 2: Freunde gemischt") — aber jede Änderung überschreibt den Vorgänger. Will A/B-Vergleich, will zu „Idee 1" zurückkehren wenn „Idee 2" schlechter ist. Heute: keine Versionierung, jede Iteration ist Einbahn.

## Ziele

- Aktuellen Saalplan-Zustand als benannten Snapshot speichern.
- Snapshot enthält: Tische (Position, Rotation, Dimensionen, Tafel-Verbindungen), Gast-Sitzzuweisungen, Canvas-Labels.
- Mehrere Snapshots pro Event nebeneinander.
- Laden eines Snapshots ersetzt den aktuellen Saalplan.
- Aktive Version markiert; Wechsel ohne Datenverlust (auto-save vor Wechsel angeboten).

## Nicht-Ziele

- Diff/Vergleich zwischen Versionen.
- Branching/Merge.
- Cloud-Sync der Versionen.
- Auto-Versions-Snapshots (z.B. „alle 5 Minuten") — User entscheidet wann gespeichert wird.

---

## Sektion 1 — Datenmodell

Snapshots als eigenständige `@Model`-Entitäten. Drei neue Modelle:

```swift
@Model
final class LayoutVersion {
    var id: UUID
    var name: String              // "Idee 1: Verteilt"
    var note: String              // Optional, freier Kommentar
    var createdAt: Date
    var event: Event?
    @Relationship(deleteRule: .cascade, inverse: \LayoutTableSnapshot.version)
    var tables: [LayoutTableSnapshot] = []
    @Relationship(deleteRule: .cascade, inverse: \LayoutLabelSnapshot.version)
    var labels: [LayoutLabelSnapshot] = []
    @Relationship(deleteRule: .cascade, inverse: \LayoutSeatSnapshot.version)
    var seats: [LayoutSeatSnapshot] = []
    init(name: String) { ... }
}

@Model
final class LayoutTableSnapshot {
    var id: UUID                  // matches original GuestTable.id
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
    var version: LayoutVersion?
    init(...) { ... }
}

@Model
final class LayoutLabelSnapshot {
    var id: UUID
    var text: String
    var positionX: Double
    var positionY: Double
    var rotation: Double
    var version: LayoutVersion?
}

@Model
final class LayoutSeatSnapshot {
    var id: UUID                  // synthetic
    var guestID: UUID             // matches Guest.id
    var tableID: UUID             // matches LayoutTableSnapshot.id (= original GuestTable.id)
    var seatIndex: Int?
    var version: LayoutVersion?
}
```

Auf `Event` neu:
```swift
@Relationship(deleteRule: .cascade, inverse: \LayoutVersion.event)
var versions: [LayoutVersion] = []

var activeVersionID: UUID?    // welche Version ist gerade „live" geladen
```

**Schema V5:** zwei neue Modelle = lightweight migration.

## Sektion 2 — Save/Restore-Logik

Neuer Service `LayoutVersionStore` (`Sources/Gaesteglueck/Services/LayoutVersionStore.swift`):

```swift
enum LayoutVersionStore {
    @MainActor
    static func snapshot(
        event: Event,
        name: String,
        note: String = "",
        modelContext: ModelContext
    ) -> LayoutVersion {
        // 1. neue LayoutVersion erstellen
        // 2. für jeden GuestTable eine LayoutTableSnapshot anlegen (id wird kopiert)
        // 3. für jeden CanvasLabel eine LayoutLabelSnapshot anlegen
        // 4. für jeden Guest mit table != nil eine LayoutSeatSnapshot anlegen
        // 5. version.event = event; modelContext.insert(version); save
    }

    @MainActor
    static func restore(
        version: LayoutVersion,
        event: Event,
        currentTables: [GuestTable],
        currentGuests: [Guest],
        currentLabels: [CanvasLabel],
        modelContext: ModelContext
    ) throws {
        // 1. alle currentTables, currentLabels löschen (cascade entfernt Gast.table-Refs)
        // 2. alle Guest.table = nil, Guest.seatIndex = nil setzen
        // 3. für jeden LayoutTableSnapshot einen neuen GuestTable mit gleicher ID anlegen
        // 4. für jeden LayoutLabelSnapshot einen neuen CanvasLabel anlegen
        // 5. für jeden LayoutSeatSnapshot Guest finden, table+seatIndex setzen
        // 6. event.activeVersionID = version.id
        // 7. save
    }

    @MainActor
    static func delete(
        version: LayoutVersion,
        event: Event,
        modelContext: ModelContext
    ) {
        if event.activeVersionID == version.id {
            event.activeVersionID = nil
        }
        modelContext.delete(version)
    }
}
```

**Wichtig — ID-Kontinuität:** Beim `restore` werden neue `GuestTable`-Instanzen mit den ORIGINAL-IDs angelegt. Gäste referenzieren `table` via SwiftData-Relation — diese sind nach Lösch-und-Neuanlage zwar logisch dieselben, aber das `.table`-Relationship ist eine Object-Reference, kein UUID-Lookup. Daher muss Schritt 5 explizit per UUID-Lookup mappen: für jeden Snapshot-Sitz den neuen `GuestTable` finden und `guest.table = newTable` setzen.

Alternative wäre, GuestTable-IDs zu fixen statt zu löschen — aber das ist gefährlich bei Tafel-Konfigurationen mit unterschiedlichen Tisch-Counts pro Version. Lösch-und-Neuanlage ist sauber.

## Sektion 3 — UI: Versions-Liste

Neue Sidebar-Komponente / Toolbar-Knopf im `RoomCanvasView` (oder im AppSidebar): „Versionen" öffnet ein Sheet/Popover mit:

```
┌─────────────────────────────┐
│ Versionen                   │
├─────────────────────────────┤
│ ● Idee 1: Verteilt   [Laden]│  ← aktiv
│   16. März, 14:32           │
│   "Familien zusammen"       │
├─────────────────────────────┤
│   Idee 2: Gemischt   [Laden]│
│   16. März, 15:01           │
├─────────────────────────────┤
│ [+ Aktuellen Stand speichern]│
└─────────────────────────────┘
```

Funktionen:
- **Speichern**: Sheet mit TextField „Name" (Default: „Idee \(count+1)"), optional Notiz. OK → `LayoutVersionStore.snapshot(...)`.
- **Laden**: Wenn aktueller Zustand seit letztem Snapshot geändert wurde → Confirm-Dialog: „Aktueller Stand verwerfen? Oder erst speichern?". Drei Optionen: Verwerfen, Erst speichern, Abbrechen.
- **Umbenennen**: Inline-Edit auf Name.
- **Löschen**: Mit Confirm.
- **Aktive Markierung**: Grüner Punkt links wenn `event.activeVersionID == version.id`.

## Sektion 4 — Tracking „dirty since last snapshot"

Heuristik: jedes Mal wenn der User in `RoomCanvasView` etwas ändert (Tisch verschoben, Gast zugewiesen, Label hinzugefügt etc.), setzen wir `event.layoutModifiedAt = Date.now`. Beim Snapshot setzen wir `event.lastSnapshotAt = Date.now`.

`isDirty`-Computed-Property: `layoutModifiedAt > lastSnapshotAt`.

Vereinfachung: für v1 gehen wir defensiv vor und fragen IMMER beim Laden „Aktuellen Stand erst speichern?". Wenn das nervt, später `isDirty` als Optimierung. Damit sparen wir das Tracking.

## Sektion 5 — Tests

`LayoutVersionStoreTests`:
- snapshot speichert korrekte Tische, Labels, Sitze.
- restore mit modifiziertem Zustand setzt zurück (Tische gleicher Anzahl/Position, Sitze wiederhergestellt).
- restore mit unterschiedlicher Tisch-Anzahl funktioniert (alte gelöscht, neue angelegt).
- delete entfernt Version + alle Snapshot-Children, setzt activeVersionID auf nil falls aktiv.
- snapshot+restore roundtrip ist idempotent: zwei Snapshots vom gleichen Zustand sind gleich.

## Sektion 6 — Schema V5 + Migration

`Sources/Gaesteglueck/Models/Schemas/SchemaV5.swift`:
```swift
enum SchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [
            Event.self, Guest.self, GuestTable.self, Tag.self, Constraint.self,
            RoomPlan.self, TableInventoryItem.self, CanvasLabel.self,
            LayoutVersion.self, LayoutTableSnapshot.self,
            LayoutLabelSnapshot.self, LayoutSeatSnapshot.self,
        ]
    }
}
```

`GaesteglueckApp.swift`: Schema-Referenz auf V5 ändern (`Schema(SchemaV5.models)`).

**Achtung:** Wir nutzen weiterhin **kein** `migrationPlan` — Auto-Lightweight-Inference reicht (neue Entities, neue optionale Felder).

## Erfolgs-Kriterien

- User klickt „+ Speichern", gibt „Idee 1" ein → Snapshot erscheint in Liste.
- Macht Tisch-Änderung → klickt „Speichern" mit „Idee 2" → zwei Versionen sichtbar.
- Klickt „Laden" auf „Idee 1" → Tische/Sitze/Labels werden auf Stand von Idee 1 zurückgesetzt.
- Beim Wechsel auf „Idee 2" → wieder zweiter Stand.
- Schließen + neu öffnen → Versionen sind persistent.
- Tests grün.
