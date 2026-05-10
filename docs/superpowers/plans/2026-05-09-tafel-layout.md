# Tafel-Layout, Sitzregeln & Canvas-Labels — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tafeln aus mehreren Tischen rendern als ein durchgehendes Rechteck mit korrekten Außensitzen, Capacity-Formel geometrisch fixen (140×80 → 6 Plätze), Tische 90°-rotierbar, Sitzregeln (Sitzabstand/Mindestabstand/Gangbreite) editierbar, freie Canvas-Labels statt hardcoded „BÜHNE/EINGANG".

**Architecture:**
- **Datenmodell:** `SeatingRules`-Composite-Wert auf `Event`. Neuer `CanvasLabel`-`@Model`. `GuestTable.combinationRole` → `combinationOrder: Int?`. Schema-Bump V3 → V4 (lightweight).
- **Rules-Zugriff:** `GuestTable.activeRules` als statische Variable (default `.default`); `RoomCanvasView` setzt `activeRules = event.seatingRules` via `onChange`. Vermeidet API-Bruch an 25+ `.capacity`-Aufrufern. Tests setzen explizit. Pure-Function-Variante `capacity(rules:)` zusätzlich für rules-isolierte Tests.
- **Tafel-Render:** Neuer `TafelLayout`-Service berechnet Tafel-Geometrie + Sitz-Mapping (welcher Sitzindex zu welchem Tisch). `TableCanvasItemView` verzweigt: Solo / Tafel-Owner (rendert alle Tafel-Sitze) / Tafel-Folge (rendert nur Form).
- **Rotation:** `.rotationEffect(.degrees(table.rotation))` um Form + Sitze. Width/Depth bleiben unverändert. Tafel rotiert als Ganzes.
- **Labels:** Neues `CanvasLabel` mit Text/Position/Rotation, `event.labels`-Relation. Hardcoded Bühne/Eingang in `RoomCanvasView` raus, neuer `CanvasLabelsLayer` rendert `event.labels`.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, Swift Testing (`@Test`/`@Suite`/`#expect`).

**Branch:** `feat/tafel-layout-spec` (Spec liegt schon hier). Alle Implementation-Commits gehen auf diesen Branch.

**Test-Build:** `swift build` und `swift test` — Project nutzt Swift Package Manager (`Package.swift` im Root).

---

## File Structure

**Create:**
- `Sources/Gaesteglueck/Models/SeatingRules.swift` — Codable-Struct mit drei Werten, Default + Validierung
- `Sources/Gaesteglueck/Models/CanvasLabel.swift` — `@Model` mit text/position/rotation
- `Sources/Gaesteglueck/Services/TafelLayout.swift` — Tafel-Geometrie + Sitz→Tisch-Mapping
- `Sources/Gaesteglueck/Views/Canvas/CanvasLabelView.swift` — einzelnes Label mit Drag/Edit
- `Sources/Gaesteglueck/Views/Canvas/CanvasLabelsLayer.swift` — rendert alle `event.labels`
- `Sources/Gaesteglueck/Models/Schemas/SchemaV4.swift` — neue Schema-Version
- `Tests/GaesteglueckTests/Models/SeatingRulesTests.swift`
- `Tests/GaesteglueckTests/Models/CanvasLabelTests.swift`
- `Tests/GaesteglueckTests/Services/TafelLayoutTests.swift`

**Modify:**
- `Sources/Gaesteglueck/Models/GuestTable.swift` — neue capacity-Formel, `combinationOrder`, `activeRules`-static
- `Sources/Gaesteglueck/Models/Event.swift` — `seatingRulesData` + `labels`-Relation
- `Sources/Gaesteglueck/Models/Schemas/SchemaV3.swift` — bleibt (alte Version)
- `Sources/Gaesteglueck/Models/Schemas/AppMigrationPlan.swift` — V4 anhängen
- `Sources/Gaesteglueck/GaesteglueckApp.swift` — Schema = V4
- `Sources/Gaesteglueck/Services/TablePlacer.swift` — chairBuffer/wallMargin aus rules
- `Sources/Gaesteglueck/Services/SaalKonfigurator.swift` — `seatWidth` aus rules
- `Sources/Gaesteglueck/Views/Canvas/SeatLayout.swift` — Symmetrie-Fix, rules-aware
- `Sources/Gaesteglueck/Views/Canvas/TableCanvasItemView.swift` — Render-Switch, Rotation, Tafel-Drag
- `Sources/Gaesteglueck/Views/Canvas/TableCombineSheet.swift` — Mehrfachauswahl, Depth-Filter, Sitz-Reset
- `Sources/Gaesteglueck/Views/RoomSetupView.swift` — Sitzregeln-Stepper, hardcoded `seatWidth: 60` raus
- `Sources/Gaesteglueck/Views/RoomCanvasView.swift` — Bühne/Eingang raus, Labels-Layer, „+ Label"-Button, `activeRules`-Sync
- `Tests/GaesteglueckTests/Models/GuestTableTests.swift` — neue Erwartungen
- `Tests/GaesteglueckTests/Views/SeatLayoutTests.swift` — Symmetrie-Tests

---

## Wave-Reihenfolge

Tasks sind so geordnet, dass jede Wave unabhängig getestet werden kann:

- **Wave 1 (Datenmodell):** Tasks 1–4 — `SeatingRules`, `CanvasLabel`, `combinationOrder`, Schema-Bump
- **Wave 2 (Capacity & Layout-Logik):** Tasks 5–7 — neue capacity-Formel, SeatLayout-Symmetrie, TafelLayout-Service
- **Wave 3 (Service-Refactor):** Tasks 8–9 — TablePlacer/SaalKonfigurator rules-aware
- **Wave 4 (Canvas-Render):** Tasks 10–13 — Rotation, Tafel-Render, Combine-Sheet, Tafel-Drag
- **Wave 5 (UI):** Tasks 14–17 — Sitzregeln-Stepper, Bühne raus, Label-Render, Label-Button
- **Wave 6 (Polish):** Task 18 — manueller Smoke-Test, finale Commit

---

## Task 1: SeatingRules-Struct

**Files:**
- Create: `Sources/Gaesteglueck/Models/SeatingRules.swift`
- Create: `Tests/GaesteglueckTests/Models/SeatingRulesTests.swift`

- [ ] **Step 1.1: Test schreiben — Default-Werte**

`Tests/GaesteglueckTests/Models/SeatingRulesTests.swift`:
```swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("SeatingRules")
struct SeatingRulesTests {
    @Test("Default rules have spec values")
    func defaultValues() {
        let rules = SeatingRules.default
        #expect(rules.seatWidthCm == 60)
        #expect(rules.tableMinDistanceCm == 80)
        #expect(rules.aisleWidthCm == 120)
    }
}
```

- [ ] **Step 1.2: Test laufen lassen — soll FEHLschlagen**

Run: `swift test --filter SeatingRulesTests`
Expected: FAIL — `SeatingRules` ist unbekannt.

- [ ] **Step 1.3: Minimale Implementation**

`Sources/Gaesteglueck/Models/SeatingRules.swift`:
```swift
import Foundation

struct SeatingRules: Codable, Equatable, Sendable {
    var seatWidthCm: Double
    var tableMinDistanceCm: Double
    var aisleWidthCm: Double

    static let `default` = SeatingRules(
        seatWidthCm: 60,
        tableMinDistanceCm: 80,
        aisleWidthCm: 120
    )
}
```

- [ ] **Step 1.4: Test laufen lassen — soll bestehen**

Run: `swift test --filter SeatingRulesTests`
Expected: PASS.

- [ ] **Step 1.5: Test schreiben — Validierung**

In derselben Datei `SeatingRulesTests.swift` ergänzen:
```swift
    @Test("Validation: seatWidth must be at least 40")
    func minSeatWidth() {
        #expect(SeatingRules.default.isValid)
        var rules = SeatingRules.default
        rules.seatWidthCm = 39
        #expect(!rules.isValid)
    }

    @Test("Validation: aisleWidth must be >= tableMinDistance")
    func aisleVsTableDistance() {
        var rules = SeatingRules.default
        rules.aisleWidthCm = 70
        rules.tableMinDistanceCm = 80
        #expect(!rules.isValid)
    }

    @Test("Codable round-trip")
    func roundTrip() throws {
        let original = SeatingRules(seatWidthCm: 65, tableMinDistanceCm: 90, aisleWidthCm: 130)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SeatingRules.self, from: data)
        #expect(decoded == original)
    }
```

- [ ] **Step 1.6: Tests laufen lassen — sollen FEHLschlagen**

Run: `swift test --filter SeatingRulesTests`
Expected: FAIL — `isValid` fehlt.

- [ ] **Step 1.7: `isValid` ergänzen**

In `Sources/Gaesteglueck/Models/SeatingRules.swift` ergänzen:
```swift
    var isValid: Bool {
        seatWidthCm >= 40 && aisleWidthCm >= tableMinDistanceCm
    }
```

- [ ] **Step 1.8: Tests laufen lassen — sollen bestehen**

Run: `swift test --filter SeatingRulesTests`
Expected: PASS, alle 4 Tests.

- [ ] **Step 1.9: Commit**

```bash
git add Sources/Gaesteglueck/Models/SeatingRules.swift Tests/GaesteglueckTests/Models/SeatingRulesTests.swift
git commit -m "feat(model): SeatingRules-Struct mit Default und Validierung"
```

---

## Task 2: CanvasLabel-Model

**Files:**
- Create: `Sources/Gaesteglueck/Models/CanvasLabel.swift`
- Create: `Tests/GaesteglueckTests/Models/CanvasLabelTests.swift`

- [ ] **Step 2.1: Test schreiben — Init**

`Tests/GaesteglueckTests/Models/CanvasLabelTests.swift`:
```swift
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("CanvasLabel Model")
struct CanvasLabelTests {
    @Test("Init with text and default position")
    func defaultInit() {
        let label = CanvasLabel(text: "Eingang")
        #expect(label.text == "Eingang")
        #expect(label.positionX == 0)
        #expect(label.positionY == 0)
        #expect(label.rotation == 0)
    }

    @Test("Init with explicit position and rotation")
    func explicitInit() {
        let label = CanvasLabel(text: "DJ", positionX: 100, positionY: 200, rotation: 90)
        #expect(label.positionX == 100)
        #expect(label.positionY == 200)
        #expect(label.rotation == 90)
    }
}
```

- [ ] **Step 2.2: Test laufen lassen — soll FEHLschlagen**

Run: `swift test --filter CanvasLabelTests`
Expected: FAIL — `CanvasLabel` unbekannt.

- [ ] **Step 2.3: Minimal-Implementation**

`Sources/Gaesteglueck/Models/CanvasLabel.swift`:
```swift
import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class CanvasLabel {
    var id: UUID
    var text: String
    var positionX: Double
    var positionY: Double
    var rotation: Double
    var event: Event?

    init(
        text: String,
        positionX: Double = 0,
        positionY: Double = 0,
        rotation: Double = 0
    ) {
        self.id = UUID()
        self.text = text
        self.positionX = positionX
        self.positionY = positionY
        self.rotation = rotation
        self.event = nil
    }
}
```

- [ ] **Step 2.4: Test laufen lassen — soll bestehen**

Run: `swift test --filter CanvasLabelTests`
Expected: PASS.

- [ ] **Step 2.5: Commit**

```bash
git add Sources/Gaesteglueck/Models/CanvasLabel.swift Tests/GaesteglueckTests/Models/CanvasLabelTests.swift
git commit -m "feat(model): CanvasLabel @Model fuer freie Saalplan-Labels"
```

---

## Task 3: GuestTable bekommt `combinationOrder` + `activeRules`

**Files:**
- Modify: `Sources/Gaesteglueck/Models/GuestTable.swift`
- Modify: `Tests/GaesteglueckTests/Models/GuestTableTests.swift`

- [ ] **Step 3.1: Test schreiben — combinationOrder**

In `Tests/GaesteglueckTests/Models/GuestTableTests.swift` den Test `combinationGroup` ersetzen durch:
```swift
    @Test("Combination group with order")
    func combinationGroup() {
        let t1 = GuestTable(name: "T1", shape: .rectangular, width: 200, depth: 100)
        let t2 = GuestTable(name: "T2", shape: .rectangular, width: 200, depth: 100)
        let groupID = UUID()
        t1.combinationGroup = groupID
        t1.combinationOrder = 0
        t2.combinationGroup = groupID
        t2.combinationOrder = 1
        #expect(t1.combinationGroup == t2.combinationGroup)
        #expect(t1.combinationOrder == 0)
        #expect(t2.combinationOrder == 1)
    }
```

- [ ] **Step 3.2: Test laufen lassen — soll FEHLschlagen**

Run: `swift test --filter "GuestTable Model"`
Expected: FAIL — `combinationOrder` unbekannt.

- [ ] **Step 3.3: GuestTable erweitern**

In `Sources/Gaesteglueck/Models/GuestTable.swift`:

Nach Zeile 22 (`var combinationRole: CombinationRole?`) ergänzen:
```swift
    var combinationOrder: Int?
```

Im `init` nach `self.combinationRole = nil` (Zeile 72) ergänzen:
```swift
        self.combinationOrder = nil
```

- [ ] **Step 3.4: Test laufen lassen — soll bestehen**

Run: `swift test --filter "GuestTable Model"`
Expected: PASS.

- [ ] **Step 3.5: `activeRules`-static + capacity(rules:) hinzufügen**

In `Sources/Gaesteglueck/Models/GuestTable.swift` direkt vor `var capacity: Int {` (Zeile 28) einfügen:
```swift
    /// App-weiter Default für Sitzregeln. Wird von der UI gesetzt, wenn ein
    /// Event geladen ist (siehe `RoomCanvasView`). Tests setzen explizit.
    nonisolated(unsafe) static var activeRules: SeatingRules = .default

    func capacity(rules: SeatingRules) -> Int {
        let seatWidth = rules.seatWidthCm
        switch shape {
        case .round:
            let circumference = Double.pi * diameter
            return Int(circumference / seatWidth)
        case .rectangular:
            let longSeats  = 2 * Int(width / seatWidth)
            let shortSeats = 2 * (depth >= seatWidth ? 1 : 0)
            return longSeats + shortSeats
        case .square:
            let longSeats  = 2 * Int(width / seatWidth)
            let shortSeats = 2 * (width >= seatWidth ? 1 : 0)
            return longSeats + shortSeats
        }
    }
```

Den existierenden `var capacity: Int { ... }`-Block (Zeilen 28-42) ersetzen durch:
```swift
    var capacity: Int { capacity(rules: GuestTable.activeRules) }
```

- [ ] **Step 3.6: Build prüfen**

Run: `swift build`
Expected: SUCCESS — keine Compile-Fehler in Aufrufern, da `capacity` weiterhin Property bleibt.

- [ ] **Step 3.7: Test schreiben — neue Capacity-Werte**

Den existierenden Test `rectangularTableCapacity` in `GuestTableTests.swift` ersetzen durch:
```swift
    @Test("Rectangular table 200x100 has 8 seats with default rules")
    func rectangularTable200x100() {
        GuestTable.activeRules = .default
        let table = GuestTable(name: "T", shape: .rectangular, width: 200, depth: 100)
        #expect(table.capacity == 8)
    }

    @Test("Rectangular table 140x80 has 6 seats with default rules")
    func rectangularTable140x80() {
        GuestTable.activeRules = .default
        let table = GuestTable(name: "T", shape: .rectangular, width: 140, depth: 80)
        #expect(table.capacity == 6)
    }

    @Test("Rectangular table 140x50 has 4 seats (kurzseite zu schmal)")
    func rectangularTable140x50() {
        GuestTable.activeRules = .default
        let table = GuestTable(name: "T", shape: .rectangular, width: 140, depth: 50)
        #expect(table.capacity == 4)
    }

    @Test("capacity(rules:) reacts to seatWidth changes")
    func capacityWithCustomRules() {
        let table = GuestTable(name: "T", shape: .rectangular, width: 140, depth: 80)
        let rules70 = SeatingRules(seatWidthCm: 70, tableMinDistanceCm: 80, aisleWidthCm: 120)
        let rules80 = SeatingRules(seatWidthCm: 80, tableMinDistanceCm: 80, aisleWidthCm: 120)
        #expect(table.capacity(rules: rules70) == 6)  // 2*Int(140/70)+2 = 4+2
        #expect(table.capacity(rules: rules80) == 4)  // 2*Int(140/80)+2 = 2+2
    }
```

Den existierenden Test `squareTableCapacity` ersetzen durch:
```swift
    @Test("Square table 200x200 has 8 seats with default rules")
    func squareTable() {
        GuestTable.activeRules = .default
        let table = GuestTable(name: "Quadrat", shape: .square, width: 200)
        // 2*Int(200/60) + 2 = 6 + 2
        #expect(table.capacity == 8)
    }
```

- [ ] **Step 3.8: Tests laufen lassen — sollen bestehen**

Run: `swift test --filter "GuestTable Model"`
Expected: PASS, alle Tests.

- [ ] **Step 3.9: Commit**

```bash
git add Sources/Gaesteglueck/Models/GuestTable.swift Tests/GaesteglueckTests/Models/GuestTableTests.swift
git commit -m "feat(model): combinationOrder + capacity(rules:) + neue Geometrie-Formel

140x80 ergibt jetzt 6 Plaetze (Laengsseiten + Kopfenden), nicht mehr 5
durch die fragwuerdige Umfang/60 - 2 Heuristik. Default-Rules ueber
GuestTable.activeRules, Tests setzen explizit."
```

---

## Task 4: Event bekommt SeatingRules + Labels-Relation; Schema V4

**Files:**
- Modify: `Sources/Gaesteglueck/Models/Event.swift`
- Create: `Sources/Gaesteglueck/Models/Schemas/SchemaV4.swift`
- Modify: `Sources/Gaesteglueck/Models/Schemas/AppMigrationPlan.swift`
- Modify: `Sources/Gaesteglueck/GaesteglueckApp.swift`

- [ ] **Step 4.1: Event erweitern**

In `Sources/Gaesteglueck/Models/Event.swift` nach Zeile 22 (`var createdAt: Date`) ergänzen:
```swift
    var seatingRulesData: Data?
    @Relationship(deleteRule: .cascade, inverse: \CanvasLabel.event)
    var labels: [CanvasLabel] = []
```

Wenn `@Relationship`-Import fehlt: am Datei-Anfang `#if canImport(SwiftData)`-Block bereits aktiv. Falls Compile-Fehler — der Relationship-Macro kommt aus SwiftData.

In den `init` von `Event` (vor `self.createdAt = .now`) ergänzen:
```swift
        self.seatingRulesData = nil
        self.labels = []
```

Direkt unter dem Init-Block ergänzen:
```swift
    var seatingRules: SeatingRules {
        get {
            guard let data = seatingRulesData,
                  let decoded = try? JSONDecoder().decode(SeatingRules.self, from: data)
            else { return .default }
            return decoded
        }
        set {
            seatingRulesData = try? JSONEncoder().encode(newValue)
        }
    }
```

- [ ] **Step 4.2: SchemaV4 anlegen**

`Sources/Gaesteglueck/Models/Schemas/SchemaV4.swift`:
```swift
#if canImport(SwiftData)
import Foundation
import SwiftData

enum SchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }

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
        ]
    }
}
#endif
```

- [ ] **Step 4.3: AppMigrationPlan erweitern**

`Sources/Gaesteglueck/Models/Schemas/AppMigrationPlan.swift` ersetzen durch:
```swift
#if canImport(SwiftData)
import SwiftData

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self),
            .lightweight(fromVersion: SchemaV3.self, toVersion: SchemaV4.self)
        ]
    }
}
#endif
```

- [ ] **Step 4.4: GaesteglueckApp Schema-Referenz aktualisieren**

In `Sources/Gaesteglueck/GaesteglueckApp.swift` Zeile 33 ändern:
```swift
        let schema = Schema(SchemaV4.models)
```

Falls die Datei den `migrationPlan` an `ModelContainer` übergibt, prüfen dass `migrationPlan: AppMigrationPlan.self` weiterhin gesetzt ist. Falls nicht: nach `let config = ModelConfiguration(schema: schema, url: storeURL)` (Zeile 37) ergänzen:
```swift
        let container = try ModelContainer(
            for: schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: [config]
        )
```
und den ursprünglichen `ModelContainer`-Init-Block ersetzen.

- [ ] **Step 4.5: Build prüfen**

Run: `swift build`
Expected: SUCCESS.

- [ ] **Step 4.6: Test schreiben — Event roundtrip mit Rules**

In `Tests/GaesteglueckTests/Models/SeatingRulesTests.swift` ergänzen:
```swift
    @Test("Event seatingRules getter returns default when nil")
    func eventDefaultRules() {
        let event = Event(name: "Test")
        #expect(event.seatingRules == .default)
    }

    @Test("Event seatingRules setter persists")
    func eventSetRules() {
        let event = Event(name: "Test")
        var rules = SeatingRules.default
        rules.seatWidthCm = 70
        event.seatingRules = rules
        #expect(event.seatingRules.seatWidthCm == 70)
    }
```

- [ ] **Step 4.7: Tests laufen lassen — sollen bestehen**

Run: `swift test --filter SeatingRulesTests`
Expected: PASS.

- [ ] **Step 4.8: Commit**

```bash
git add Sources/Gaesteglueck/Models/Event.swift \
        Sources/Gaesteglueck/Models/Schemas/SchemaV4.swift \
        Sources/Gaesteglueck/Models/Schemas/AppMigrationPlan.swift \
        Sources/Gaesteglueck/GaesteglueckApp.swift \
        Tests/GaesteglueckTests/Models/SeatingRulesTests.swift
git commit -m "feat(schema): SchemaV4 mit seatingRules + labels-Relation auf Event

Lightweight-Migration V3 -> V4 (neue optionale Felder)."
```

---

## Task 5: SeatLayout Symmetrie-Fix

**Files:**
- Modify: `Sources/Gaesteglueck/Views/Canvas/SeatLayout.swift`
- Modify: `Tests/GaesteglueckTests/Views/SeatLayoutTests.swift`

- [ ] **Step 5.1: Test schreiben — Symmetrie**

In `Tests/GaesteglueckTests/Views/SeatLayoutTests.swift` ergänzen (am Ende der `@Suite`):
```swift
    @Test("Rect with capacity 6 splits long sides evenly: 2 top + 2 bottom + 2 ends")
    func rectSymmetric6() {
        let positions = SeatLayout.positions(
            shape: .rectangular,
            capacity: 6,
            scaledDiameter: 0,
            scaledWidth: 140,
            scaledDepth: 80
        )
        #expect(positions.count == 6)
        let top = positions.filter { $0.y < -10 }
        let bottom = positions.filter { $0.y > 10 }
        let ends = positions.filter { abs($0.y) <= 10 }
        #expect(top.count == 2)
        #expect(bottom.count == 2)
        #expect(ends.count == 2)
    }

    @Test("Rect with capacity 8 splits 3 top + 3 bottom + 2 ends")
    func rectSymmetric8() {
        let positions = SeatLayout.positions(
            shape: .rectangular,
            capacity: 8,
            scaledDiameter: 0,
            scaledWidth: 200,
            scaledDepth: 100
        )
        #expect(positions.count == 8)
        let top = positions.filter { $0.y < -10 }
        let bottom = positions.filter { $0.y > 10 }
        #expect(top.count == 3)
        #expect(bottom.count == 3)
    }
```

- [ ] **Step 5.2: Tests laufen lassen — Symmetrie soll FEHLschlagen**

Run: `swift test --filter "Seat Layout"`
Expected: FAIL bei `rectSymmetric8` — heutige Implementation gibt 4 oben + 2 unten + 2 enden bei capacity 8 (sideSeats=6, topCount=3+0=3, bottomCount=3 → eigentlich okay) oder bei capacity 7 (sideSeats=5, topCount=3, bottomCount=2 → asymmetrisch). Lass den Test laufen, fix wenn rot.

(Hinweis: bei geraden `sideSeats` ist die heutige Implementation symmetrisch. Symmetrie-Fix bedeutet: bei ungeraden `sideSeats` rotieren wir den Rest-Sitz nicht immer nach oben, sondern verteilen so dass Top/Bottom maximal um 1 abweichen. Das ist heute schon der Fall. Der eigentlich wichtige Bug ist: bei `capacity=5` (sideSeats=3) bekommt oben 2, unten 1 — was eigentlich "geometrisch unvermeidbar" ist, also okay. Symmetrie ist für gerade Längsseiten-Zahl; das prüft unser Test mit capacity 6 und 8.)

- [ ] **Step 5.3: Falls Test passt → keine Änderung**

Wenn beide Tests grün laufen, ist `SeatLayout.rectPositions` heute schon korrekt für gerade `sideSeats`. Skip Step 5.4 und gehe zu 5.5.

- [ ] **Step 5.4: Falls FAIL: Symmetrie-Fix in `rectPositions`**

In `Sources/Gaesteglueck/Views/Canvas/SeatLayout.swift` Zeilen 38-67 (`rectPositions`-Body) ersetzen durch:
```swift
    private static func rectPositions(capacity: Int, w: CGFloat, d: CGFloat) -> [CGPoint] {
        guard capacity > 0 else { return [] }
        let endSeatCount: Int = capacity >= 4 ? 2 : 0
        let sideSeats = capacity - endSeatCount
        // Symmetrische Verteilung: bei ungerader Sitzanzahl bekommt oben den Rest
        let topCount = sideSeats / 2 + (sideSeats % 2)
        let bottomCount = sideSeats / 2
        var result: [CGPoint] = []

        for i in 0..<topCount {
            let denom = max(topCount, 1)
            let x = -w/2 + (CGFloat(i) + 0.5) * (w / CGFloat(denom))
            result.append(CGPoint(x: x, y: -d/2 - seatGap))
        }
        for i in 0..<bottomCount {
            let denom = max(bottomCount, 1)
            let x = -w/2 + (CGFloat(i) + 0.5) * (w / CGFloat(denom))
            result.append(CGPoint(x: x, y: d/2 + seatGap))
        }
        if endSeatCount >= 1 {
            result.append(CGPoint(x: -w/2 - seatGap, y: 0))
        }
        if endSeatCount >= 2 {
            result.append(CGPoint(x: w/2 + seatGap, y: 0))
        }
        return result
    }
```

(Diese Implementation ist effektiv identisch zur heutigen. Der Test erzwingt nur, dass Symmetrie für gerade Längsseiten gilt.)

- [ ] **Step 5.5: Tests laufen lassen — sollen bestehen**

Run: `swift test --filter "Seat Layout"`
Expected: PASS, alle Tests.

- [ ] **Step 5.6: Commit**

```bash
git add Sources/Gaesteglueck/Views/Canvas/SeatLayout.swift Tests/GaesteglueckTests/Views/SeatLayoutTests.swift
git commit -m "test(seatlayout): Symmetrie fuer gerade Laengsseiten-Sitze gesichert"
```

---

## Task 6: TafelLayout Service (Geometrie + Sitz-Mapping)

**Files:**
- Create: `Sources/Gaesteglueck/Services/TafelLayout.swift`
- Create: `Tests/GaesteglueckTests/Services/TafelLayoutTests.swift`

- [ ] **Step 6.1: Tests schreiben — Tafel-Geometrie**

`Tests/GaesteglueckTests/Services/TafelLayoutTests.swift`:
```swift
#if canImport(SwiftUI)
import Testing
import Foundation
import SwiftUI
@testable import Gaesteglueck

@Suite("TafelLayout")
struct TafelLayoutTests {
    private func makeTable(width: Double, depth: Double, x: Double, order: Int) -> GuestTable {
        let t = GuestTable(name: "T\(order)", shape: .rectangular, width: width, depth: depth, positionX: x, positionY: 0)
        t.combinationGroup = UUID()
        t.combinationOrder = order
        return t
    }

    @Test("Two 140x80 tables form a 280x80 tafel with 10 seats")
    func twoTables() {
        let rules = SeatingRules.default
        let t0 = makeTable(width: 140, depth: 80, x: -70, order: 0)
        let t1 = makeTable(width: 140, depth: 80, x: 70, order: 1)
        let geo = TafelLayout.geometry(of: [t0, t1], rules: rules)
        #expect(geo.totalWidth == 280)
        #expect(geo.depth == 80)
        // 2 * floor(280/60) + 2 = 2*4 + 2 = 10
        #expect(geo.capacity == 10)
        #expect(geo.seats.count == 10)
    }

    @Test("Three 140x80 tables form a 420x80 tafel with 16 seats")
    func threeTables() {
        let rules = SeatingRules.default
        let t0 = makeTable(width: 140, depth: 80, x: -140, order: 0)
        let t1 = makeTable(width: 140, depth: 80, x: 0, order: 1)
        let t2 = makeTable(width: 140, depth: 80, x: 140, order: 2)
        let geo = TafelLayout.geometry(of: [t0, t1, t2], rules: rules)
        // 2 * floor(420/60) + 2 = 2*7 + 2 = 16
        #expect(geo.capacity == 16)
        #expect(geo.seats.count == 16)
    }

    @Test("Outer end seats belong to outermost tables")
    func endSeatMapping() {
        let rules = SeatingRules.default
        let t0 = makeTable(width: 140, depth: 80, x: -70, order: 0)
        let t1 = makeTable(width: 140, depth: 80, x: 70, order: 1)
        let geo = TafelLayout.geometry(of: [t0, t1], rules: rules)

        // Linker Kopfsitz (kleinster x-Wert) → Tisch 0
        let leftEnd = geo.seats.min(by: { $0.position.x < $1.position.x })!
        #expect(leftEnd.tableID == t0.id)

        // Rechter Kopfsitz (größter x-Wert) → Tisch 1
        let rightEnd = geo.seats.max(by: { $0.position.x < $1.position.x })!
        #expect(rightEnd.tableID == t1.id)
    }

    @Test("Custom seatWidth changes capacity")
    func customSeatWidth() {
        var rules = SeatingRules.default
        rules.seatWidthCm = 70
        let t0 = makeTable(width: 140, depth: 80, x: -70, order: 0)
        let t1 = makeTable(width: 140, depth: 80, x: 70, order: 1)
        let geo = TafelLayout.geometry(of: [t0, t1], rules: rules)
        // 2 * floor(280/70) + 2 = 8 + 2 = 10
        #expect(geo.capacity == 10)
    }
}
#endif
```

- [ ] **Step 6.2: Tests laufen lassen — sollen FEHLschlagen**

Run: `swift test --filter TafelLayout`
Expected: FAIL — `TafelLayout` unbekannt.

- [ ] **Step 6.3: TafelLayout implementieren**

`Sources/Gaesteglueck/Services/TafelLayout.swift`:
```swift
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
        guard !sorted.isEmpty else {
            return TafelGeometry(totalWidth: 0, depth: 0, center: .zero, rotation: 0, capacity: 0, seats: [])
        }

        let totalWidth = CGFloat(sorted.reduce(0.0) { $0 + $1.width })
        let depth = CGFloat(sorted.map(\.depth).max() ?? 0)
        let centerX = CGFloat(sorted.reduce(0.0) { $0 + $1.positionX * $1.width } / max(sorted.reduce(0.0) { $0 + $1.width }, 0.001))
        let centerY = CGFloat(sorted[0].positionY)
        let rotation = sorted[0].rotation

        let seatWidth = CGFloat(rules.seatWidthCm)
        let nLong = Int(totalWidth / seatWidth)
        let seatGap: CGFloat = 14

        // Sitze in Tafel-lokalen Koordinaten (relativ zu center) berechnen
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

        // Tisch-Bereiche in lokalen Koordinaten: kumulative X-Grenzen relativ zur Tafel-Mitte
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
            return ranges.last!.table
        }

        var seats: [Seat] = []
        let cosR = cos(rotation * .pi / 180)
        let sinR = sin(rotation * .pi / 180)

        func toGlobal(_ local: CGPoint) -> CGPoint {
            let rx = local.x * cosR - local.y * sinR
            let ry = local.x * sinR + local.y * cosR
            return CGPoint(x: centerX + rx, y: centerY + ry)
        }

        // Reihenfolge: alle Top, alle Bottom, dann linker End, rechter End
        for p in localTopSeats {
            let table = tableForX(p.x)
            let idx = localIndexCounter[table.id]!
            localIndexCounter[table.id] = idx + 1
            seats.append(Seat(position: toGlobal(p), tableID: table.id, localSeatIndex: idx))
        }
        for p in localBottomSeats {
            let table = tableForX(p.x)
            let idx = localIndexCounter[table.id]!
            localIndexCounter[table.id] = idx + 1
            seats.append(Seat(position: toGlobal(p), tableID: table.id, localSeatIndex: idx))
        }
        // Linker Kopfsitz → erstes Tisch (order 0)
        let firstTable = sorted.first!
        let leftIdx = localIndexCounter[firstTable.id]!
        localIndexCounter[firstTable.id] = leftIdx + 1
        seats.append(Seat(position: toGlobal(leftEnd), tableID: firstTable.id, localSeatIndex: leftIdx))

        // Rechter Kopfsitz → letztes Tisch
        let lastTable = sorted.last!
        let rightIdx = localIndexCounter[lastTable.id]!
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
```

- [ ] **Step 6.4: Tests laufen lassen — sollen bestehen**

Run: `swift test --filter TafelLayout`
Expected: PASS, alle 4 Tests.

- [ ] **Step 6.5: Commit**

```bash
git add Sources/Gaesteglueck/Services/TafelLayout.swift Tests/GaesteglueckTests/Services/TafelLayoutTests.swift
git commit -m "feat(service): TafelLayout berechnet Tafel-Geometrie und Sitz-Mapping

Zwei 140x80-Tische ergeben eine 280x80-Tafel mit 10 Sitzen
(4 oben + 4 unten + 2 Aussen-Kopfsitze). Sitz-zu-Tisch-Mapping
ueber X-Position; Kopfsitze gehoeren zum aeussersten Tisch."
```

---

## Task 7: TablePlacer rules-aware

**Files:**
- Modify: `Sources/Gaesteglueck/Services/TablePlacer.swift`

- [ ] **Step 7.1: TablePlacer-Signaturen erweitern**

In `Sources/Gaesteglueck/Services/TablePlacer.swift`:

Zeilen 9-13 (`enum TablePlacer { ...wallMargin... }`) ersetzen durch:
```swift
enum TablePlacer {
    private static let walkwayBuffer: Double = 100  // interner Komfort-Puffer

    static func suggestLayout(
        tables: [GuestTable],
        roomWidthCM: Double,
        roomDepthCM: Double,
        rules: SeatingRules = .default
    ) -> [TablePlacement] {
```

Den existierenden `static func suggestLayout(...)` nur durch obige Signatur ersetzen (Body bleibt). Die alte `wallMargin`-Konstante entfernen.

- [ ] **Step 7.2: chairBuffer als ableitbar machen**

`tableFootprint`-Funktion (Zeile 40-47) ersetzen durch:
```swift
    private static func tableFootprint(_ table: GuestTable, rules: SeatingRules) -> Double {
        let chairBuffer = rules.tableMinDistanceCm
        switch table.shape {
        case .round:
            return table.diameter + 2 * chairBuffer
        case .rectangular, .square:
            return max(table.width, table.depth) + 2 * chairBuffer
        }
    }
```

- [ ] **Step 7.3: `findNonOverlappingPosition` rules-aware machen**

Lese die Funktion (`Sources/Gaesteglueck/Services/TablePlacer.swift:49-end`) und ersetze alle `wallMargin`-Vorkommen durch `rules.aisleWidthCm` und alle `tableFootprint($0)` durch `tableFootprint($0, rules: rules)`. Funktions-Signatur erweitern um `rules: SeatingRules`.

Pattern:
```swift
    private static func findNonOverlappingPosition(
        for table: GuestTable,
        existing: [TablePlacement],
        allTables: [GuestTable],
        roomWidth: Double,
        roomDepth: Double,
        rules: SeatingRules
    ) -> (x: Double, y: Double) {
        let tableMap = Dictionary(uniqueKeysWithValues: allTables.map { ($0.id, $0) })
        let footprint = tableFootprint(table, rules: rules)
        // ... `wallMargin` → `rules.aisleWidthCm` ersetzen ...
```

Den Aufruf in `suggestLayout` anpassen:
```swift
            let position = findNonOverlappingPosition(
                    for: table,
                    existing: placements,
                    allTables: tables,
                    roomWidth: roomWidthCM,
                    roomDepth: roomDepthCM,
                    rules: rules
                )
```

Sortier-Aufruf (Zeile 21-23) anpassen:
```swift
        let sorted = tables.sorted { a, b in
            tableFootprint(a, rules: rules) > tableFootprint(b, rules: rules)
        }
```

- [ ] **Step 7.4: Build prüfen**

Run: `swift build`
Expected: SUCCESS — alle existierenden Aufrufer von `TablePlacer.suggestLayout` funktionieren weiter (Default-Param).

- [ ] **Step 7.5: Existierende TablePlacer-Tests laufen lassen**

Run: `swift test --filter TablePlacer`
Expected: PASS — keine Regression durch Default-Parameter.

- [ ] **Step 7.6: Commit**

```bash
git add Sources/Gaesteglueck/Services/TablePlacer.swift
git commit -m "refactor(placer): TablePlacer liest chairBuffer/wallMargin aus SeatingRules"
```

---

## Task 8: SaalKonfigurator rules-aware

**Files:**
- Modify: `Sources/Gaesteglueck/Services/SaalKonfigurator.swift`

- [ ] **Step 8.1: seatWidth durch rules ersetzen**

In `Sources/Gaesteglueck/Services/SaalKonfigurator.swift`:

Zeile 283 (`let seatWidth: Double = 60`) finden und prüfen Kontext (mit `Read` zuerst).

Dann die Funktion, in der das vorkommt, um `rules: SeatingRules = .default` Parameter erweitern und `60` durch `rules.seatWidthCm` ersetzen.

(Falls die Funktion intern aufgerufen wird ohne Rules-Kontext: Default-Param `.default` ausreichend; spätere Aufrufer können explizit Rules durchreichen.)

- [ ] **Step 8.2: Build + Tests prüfen**

Run: `swift build && swift test`
Expected: SUCCESS — keine Regression.

- [ ] **Step 8.3: Commit**

```bash
git add Sources/Gaesteglueck/Services/SaalKonfigurator.swift
git commit -m "refactor(konfigurator): seatWidth aus SeatingRules statt hardcoded 60"
```

---

## Task 9: Rotation in TableCanvasItemView (Solo-Tisch)

**Files:**
- Modify: `Sources/Gaesteglueck/Views/Canvas/TableCanvasItemView.swift`

- [ ] **Step 9.1: rotationEffect am tableShape anbringen**

In `Sources/Gaesteglueck/Views/Canvas/TableCanvasItemView.swift` den `body` (Zeile 55) finden. Auf das äußere `ZStack { tableShape, VStack, seatChips }` einen `.rotationEffect(.degrees(table.rotation))` anbringen — direkt vor `.position(...)`.

Konkret: in Zeile 84 (`.position(x: ...)`) davor einfügen:
```swift
        .rotationEffect(.degrees(table.rotation))
```

Reihenfolge der Modifier muss sein: ZStack → rotationEffect → position → gesture/onTap/contextMenu.

- [ ] **Step 9.2: Kontext-Menü „Drehen 90°"**

In demselben File im `.contextMenu`-Block (Zeile 97-115) **vor** dem `if table.shape == .rectangular`-Block ergänzen:
```swift
            Button {
                table.rotation = (table.rotation + 90).truncatingRemainder(dividingBy: 360)
            } label: {
                Label("Drehen 90°", systemImage: "rotate.right")
            }
```

(Hinweis für Tafel: dieser Handler dreht erstmal nur den Solo-Tisch. Tafel-Rotation kommt in Task 11.)

- [ ] **Step 9.3: Build prüfen**

Run: `swift build`
Expected: SUCCESS.

- [ ] **Step 9.4: Manueller UI-Test**

(Beim Plan-Executor: optional. Bei Subagent-Mode: durch Plan-Executor manuell verifizieren.)

In Xcode App starten, einen rechteckigen Tisch erstellen, Rechtsklick → „Drehen 90°". Tisch dreht visuell, Sitze drehen mit. Width/Depth bleiben in den Properties unverändert.

- [ ] **Step 9.5: Commit**

```bash
git add Sources/Gaesteglueck/Views/Canvas/TableCanvasItemView.swift
git commit -m "feat(canvas): Rotation in 90Grad-Schritten via Kontext-Menue

table.rotation rendert via rotationEffect; width/depth bleiben
unangetastet (Capacity stabil ueber Drehung)."
```

---

## Task 10: Tafel-Render in TableCanvasItemView

**Files:**
- Modify: `Sources/Gaesteglueck/Views/Canvas/TableCanvasItemView.swift`

- [ ] **Step 10.1: Tafel-Hilfsfunktionen einführen**

In `TableCanvasItemView` nach `private var seatPositions: [CGPoint]` (Zeile 16) ergänzen:
```swift
    private var groupTables: [GuestTable] {
        guard let groupID = table.combinationGroup else { return [] }
        return allTables.filter { $0.combinationGroup == groupID }
    }

    private var isTafelOwner: Bool {
        table.combinationGroup != nil && (table.combinationOrder ?? 0) == 0
    }

    private var isTafelFollower: Bool {
        table.combinationGroup != nil && (table.combinationOrder ?? 0) > 0
    }

    private var tafelGeometry: TafelLayout.TafelGeometry? {
        guard isTafelOwner else { return nil }
        let rules = event?.seatingRules ?? .default
        return TafelLayout.geometry(of: groupTables, rules: rules)
    }

    @Query private var events: [Event]
    private var event: Event? { events.first }
```

- [ ] **Step 10.2: Body-Verzweigung**

Den `body`-Block finden (Zeile 55). Den ZStack-Inhalt durch eine Verzweigung ersetzen:
```swift
    var body: some View {
        Group {
            if isTafelFollower {
                tafelFollowerView
            } else {
                soloOrOwnerView
            }
        }
        .position(x: table.positionX + dragOffset.width, y: table.positionY + dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    applyDrag(value.translation)
                }
        )
        .onTapGesture(perform: onTap)
        .contextMenu {
            tafelContextMenu
        }
        .sheet(isPresented: $showingCombineSheet) {
            TableCombineSheet(table: table)
        }
    }

    @ViewBuilder
    private var tafelFollowerView: some View {
        tableShape
            .rotationEffect(.degrees(table.rotation))
        // Folge-Tisch: nur Form, kein Name, keine Sitze, kein Badge
    }

    @ViewBuilder
    private var soloOrOwnerView: some View {
        ZStack {
            tableShape
                .overlay(alignment: .topTrailing) { badgeOverlay }
            VStack(spacing: 3) {
                Text(table.name)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(capacityLabel)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(table.isFull ? Tokens.Colors.warn : Tokens.Colors.ink3)
                        .monospacedDigit()
                    allergyBadge
                }
                if table.combinationGroup != nil {
                    Image(systemName: "link")
                        .font(.system(size: 9))
                        .foregroundStyle(Tokens.Colors.accent)
                }
            }
            .padding(.horizontal, 6)
            seatChipsLayer
        }
        .rotationEffect(.degrees(table.rotation))
    }

    private var capacityLabel: String {
        if let geo = tafelGeometry {
            let occupied = groupTables.reduce(0) { $0 + $1.guests.filter { $0.seatIndex != nil }.count }
            return "\(occupied)/\(geo.capacity)"
        }
        return "\(table.guests.count)/\(table.capacity)"
    }
```

- [ ] **Step 10.3: seatChipsLayer für Owner und Solo**

Die existierende `seatChips`-Computed-Property (Zeile 164) umbenennen in `seatChipsLayer` und erweitern:
```swift
    @ViewBuilder
    private var seatChipsLayer: some View {
        if let geo = tafelGeometry {
            // Tafel-Owner: rendert Sitze der gesamten Tafel
            ForEach(Array(geo.seats.enumerated()), id: \.offset) { idx, seat in
                let occ = occupantInGroup(tableID: seat.tableID, seatIndex: seat.localSeatIndex)
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
                    }
                )
                .offset(
                    x: seat.position.x - table.positionX,
                    y: seat.position.y - table.positionY
                )
            }
        } else {
            let positions = seatPositions
            ForEach(0..<positions.count, id: \.self) { idx in
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
                    }
                )
                .offset(x: positions[idx].x, y: positions[idx].y)
            }
        }
    }

    private func occupantInGroup(tableID: UUID, seatIndex: Int) -> Guest? {
        guard let target = groupTables.first(where: { $0.id == tableID }) else { return nil }
        return target.guests.first { $0.seatIndex == seatIndex }
    }

    private func assignGuestToTafelSeat(guestID: UUID, seat: TafelLayout.Seat) -> Bool {
        guard let guest = allGuests.first(where: { $0.id == guestID }) else { return false }
        if guest.isPinned { return false }
        guard let target = allTables.first(where: { $0.id == seat.tableID }) else { return false }

        let prior = target.guests.first { $0.seatIndex == seat.localSeatIndex }
        let priorSeat = guest.table?.id == target.id ? guest.seatIndex : nil

        if let prior, prior.id != guest.id {
            prior.seatIndex = priorSeat
        }
        guest.table = target
        guest.seatIndex = seat.localSeatIndex
        return true
    }
```

- [ ] **Step 10.4: tafelContextMenu**

Vor der existierenden `contextMenu`-Logik (im Body) das Menü als ViewBuilder extrahieren:
```swift
    @ViewBuilder
    private var tafelContextMenu: some View {
        Button {
            rotateBy90()
        } label: {
            Label("Drehen 90°", systemImage: "rotate.right")
        }
        if table.shape == .rectangular && !isTafelFollower {
            Button {
                showingCombineSheet = true
            } label: {
                Label("Tisch verbinden", systemImage: "link")
            }
        }
        if table.combinationGroup != nil {
            Button(role: .destructive) {
                dissolveTafel()
            } label: {
                Label("Verbindung lösen", systemImage: "link.badge.plus")
            }
        }
    }

    private func rotateBy90() {
        let newRot = (table.rotation + 90).truncatingRemainder(dividingBy: 360)
        if table.combinationGroup != nil {
            // Tafel als Ganzes rotieren um Tafel-Mittelpunkt
            guard let geo = TafelLayout.geometry(of: groupTables, rules: event?.seatingRules ?? .default) as TafelLayout.TafelGeometry? else {
                table.rotation = newRot
                return
            }
            let cx = geo.center.x
            let cy = geo.center.y
            let cosD = cos(.pi / 2)
            let sinD = sin(.pi / 2)
            for t in groupTables {
                let dx = t.positionX - Double(cx)
                let dy = t.positionY - Double(cy)
                t.positionX = Double(cx) + dx * cosD - dy * sinD
                t.positionY = Double(cy) + dx * sinD + dy * cosD
                t.rotation = newRot
            }
        } else {
            table.rotation = newRot
        }
    }

    private func dissolveTafel() {
        guard let groupID = table.combinationGroup else { return }
        for t in allTables where t.combinationGroup == groupID {
            t.combinationGroup = nil
            t.combinationOrder = nil
            t.combinationRole = nil
        }
    }

    private func applyDrag(_ translation: CGSize) {
        if table.combinationGroup != nil {
            for t in groupTables {
                t.positionX += translation.width
                t.positionY += translation.height
            }
        } else {
            table.positionX += translation.width
            table.positionY += translation.height
        }
        dragOffset = .zero
    }
```

(Hinweis: Der existierende `assignGuestToSeat`-Body bleibt unverändert. Die alte `seatChips`-Property (Zeilen 163-181) wurde durch `seatChipsLayer` ersetzt — alte Property löschen.)

- [ ] **Step 10.5: Build prüfen**

Run: `swift build`
Expected: SUCCESS.

- [ ] **Step 10.6: Manueller Smoke-Test**

App starten: einen Rechteck-Tisch und einen zweiten Rechteck-Tisch erstellen. Combine: heute zeigt Sheet noch single-pick — d.h. Tafel hat 2 Tische, Owner-Render zeigt 10 Sitze (4 oben, 4 unten, 2 außen), Folge-Tisch ist nur Form. Drag verschiebt beide. Rechtsklick „Drehen 90°" rotiert Tafel als Ganzes.

(Falls Combine-Sheet noch broken: Task 12 macht Mehrfachauswahl. Single-Pick reicht für Smoke-Test.)

- [ ] **Step 10.7: Commit**

```bash
git add Sources/Gaesteglueck/Views/Canvas/TableCanvasItemView.swift
git commit -m "feat(canvas): Tafel-Render mit durchgehender Sitzreihe und Sammel-Drag

Owner-Tisch zeichnet Tafel-weite Sitze via TafelLayout, Folge-Tische
nur ihre Form. Drag/Rotation wirken auf gesamte Tafel."
```

---

## Task 11: TableCombineSheet — Mehrfachauswahl + Sitz-Reset

**Files:**
- Modify: `Sources/Gaesteglueck/Views/Canvas/TableCombineSheet.swift`

- [ ] **Step 11.1: Sheet auf Mehrfachauswahl umbauen**

`Sources/Gaesteglueck/Views/Canvas/TableCombineSheet.swift` komplett ersetzen durch:
```swift
#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TableCombineSheet: View {
    @Environment(\.dismiss) private var dismiss
    let table: GuestTable
    @Query(sort: \GuestTable.name) private var allTables: [GuestTable]
    @State private var selected: Set<UUID> = []

    private var availableTables: [GuestTable] {
        allTables.filter {
            $0.id != table.id
                && $0.shape == .rectangular
                && $0.combinationGroup == nil
                && $0.depth == table.depth
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if table.combinationGroup != nil {
                    Section {
                        Button("Verbindung lösen", role: .destructive) {
                            let groupID = table.combinationGroup
                            for t in allTables where t.combinationGroup == groupID {
                                t.combinationGroup = nil
                                t.combinationOrder = nil
                                t.combinationRole = nil
                            }
                            dismiss()
                        }
                    }
                }

                Section("Verfügbare Tische (gleiche Tiefe)") {
                    if availableTables.isEmpty {
                        Text("Keine kompatiblen Tische verfügbar.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(availableTables) { other in
                        Button {
                            if selected.contains(other.id) {
                                selected.remove(other.id)
                            } else {
                                selected.insert(other.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selected.contains(other.id) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(selected.contains(other.id) ? Color.accentColor : Color.secondary)
                                Text(other.name)
                                Spacer()
                                Text("\(other.width.formatted())×\(other.depth.formatted()) cm")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Tafel bauen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selected.isEmpty ? "Zur Tafel verbinden" : "\(selected.count + 1) verbinden") {
                        applyCombine()
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
    }

    private func applyCombine() {
        let chosen = availableTables.filter { selected.contains($0.id) }
        let all = [table] + chosen
        let groupID = table.combinationGroup ?? UUID()

        // Order setzen
        for (i, t) in all.enumerated() {
            t.combinationGroup = groupID
            t.combinationOrder = i
            t.combinationRole = nil
        }

        // Positionen ausrichten: Tafel um Owner-Mittelpunkt zentrieren
        let totalWidth = all.reduce(0.0) { $0 + $1.width }
        var cursor = table.positionX - totalWidth / 2
        for t in all {
            t.positionX = cursor + t.width / 2
            t.positionY = table.positionY
            t.rotation = table.rotation
            cursor += t.width
        }

        // Sitz-Reset: alle Gäste der Tafel verlieren ihren seatIndex
        for t in all {
            for g in t.guests {
                g.seatIndex = nil
            }
        }
    }
}
#endif
```

- [ ] **Step 11.2: Build prüfen**

Run: `swift build`
Expected: SUCCESS.

- [ ] **Step 11.3: Manueller Smoke-Test**

App: 3 Rechteck-Tische 140×80. Auf einem rechtsklicken → „Tisch verbinden", die anderen zwei selektieren, „3 verbinden". Tafel: drei Tische in Reihe, 16 Sitze (`2*Int(420/60)+2 = 14+2 = 16`).

- [ ] **Step 11.4: Commit**

```bash
git add Sources/Gaesteglueck/Views/Canvas/TableCombineSheet.swift
git commit -m "feat(canvas): Mehrfachauswahl im Combine-Sheet, Sitz-Reset bei Combine

Mehrere Tische gleicher Tiefe als Tafel verbinden; Positionen werden
aufgereiht, alle Gaeste verlieren ihren seatIndex (vorhersehbar)."
```

---

## Task 12: RoomCanvasView — Bühne raus, activeRules-Sync

**Files:**
- Modify: `Sources/Gaesteglueck/Views/RoomCanvasView.swift`

- [ ] **Step 12.1: Hardcoded Bühne/Eingang löschen**

In `Sources/Gaesteglueck/Views/RoomCanvasView.swift` Zeilen 483-518 (`Group { if let w = floorWidth ... } // BÜHNE/EINGANG`) komplett löschen.

- [ ] **Step 12.2: activeRules-Sync via onChange**

Im `RoomCanvasView`-`body` (Zeile 75) den `Group { ... }`-Block oder den äußersten `View`-Container finden und am Ende ergänzen:
```swift
        .onAppear {
            if let event = event {
                GuestTable.activeRules = event.seatingRules
            }
        }
        .onChange(of: event?.seatingRulesData) { _, _ in
            if let event = event {
                GuestTable.activeRules = event.seatingRules
            }
        }
```

- [ ] **Step 12.3: RoomSetupView Bühne raus**

In `Sources/Gaesteglueck/Views/RoomSetupView.swift` Zeilen 537-549 (`// Stage label` ZStack-Block mit „BÜHNE" Text) komplett löschen.

- [ ] **Step 12.4: Build prüfen**

Run: `swift build`
Expected: SUCCESS.

- [ ] **Step 12.5: Commit**

```bash
git add Sources/Gaesteglueck/Views/RoomCanvasView.swift Sources/Gaesteglueck/Views/RoomSetupView.swift
git commit -m "refactor(canvas): hardcoded BUEHNE/EINGANG entfernt, activeRules-Sync

Die Hinweise werden in Task 13/14 durch frei platzierbare CanvasLabels
ersetzt. activeRules wird vom geladenen Event in GuestTable gespiegelt
damit Capacity-Property reaktiv bleibt."
```

---

## Task 13: CanvasLabelView + CanvasLabelsLayer

**Files:**
- Create: `Sources/Gaesteglueck/Views/Canvas/CanvasLabelView.swift`
- Create: `Sources/Gaesteglueck/Views/Canvas/CanvasLabelsLayer.swift`

- [ ] **Step 13.1: CanvasLabelView**

`Sources/Gaesteglueck/Views/Canvas/CanvasLabelView.swift`:
```swift
#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct CanvasLabelView: View {
    @Bindable var label: CanvasLabel
    @Environment(\.modelContext) private var modelContext
    @State private var dragOffset: CGSize = .zero
    @State private var isEditing: Bool = false
    @State private var editText: String = ""

    var body: some View {
        Group {
            if isEditing {
                TextField("Text", text: $editText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .onSubmit { commitEdit() }
            } else {
                Text(label.text)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .tracking(0.5)
            }
        }
        .rotationEffect(.degrees(label.rotation))
        .position(
            x: label.positionX + dragOffset.width,
            y: label.positionY + dragOffset.height
        )
        .gesture(
            DragGesture()
                .onChanged { dragOffset = $0.translation }
                .onEnded { v in
                    label.positionX += v.translation.width
                    label.positionY += v.translation.height
                    dragOffset = .zero
                }
        )
        .onTapGesture(count: 2) {
            beginEdit()
        }
        .contextMenu {
            Button("Bearbeiten…") { beginEdit() }
            Button {
                label.rotation = (label.rotation + 90).truncatingRemainder(dividingBy: 360)
            } label: {
                Label("Drehen 90°", systemImage: "rotate.right")
            }
            Button(role: .destructive) {
                modelContext.delete(label)
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    private func beginEdit() {
        editText = label.text
        isEditing = true
    }

    private func commitEdit() {
        label.text = editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Label" : editText
        isEditing = false
    }
}
#endif
```

- [ ] **Step 13.2: CanvasLabelsLayer**

`Sources/Gaesteglueck/Views/Canvas/CanvasLabelsLayer.swift`:
```swift
#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct CanvasLabelsLayer: View {
    let event: Event?

    var body: some View {
        Group {
            if let event = event {
                ForEach(event.labels) { label in
                    CanvasLabelView(label: label)
                }
            }
        }
    }
}
#endif
```

- [ ] **Step 13.3: Build prüfen**

Run: `swift build`
Expected: SUCCESS.

- [ ] **Step 13.4: Commit**

```bash
git add Sources/Gaesteglueck/Views/Canvas/CanvasLabelView.swift \
        Sources/Gaesteglueck/Views/Canvas/CanvasLabelsLayer.swift
git commit -m "feat(canvas): CanvasLabelView + CanvasLabelsLayer

Drag, Doppel-Tap-Edit, Kontext-Menue (Bearbeiten/Drehen/Loeschen)."
```

---

## Task 14: RoomCanvasView — Labels-Layer + „+ Label"-Button

**Files:**
- Modify: `Sources/Gaesteglueck/Views/RoomCanvasView.swift`

- [ ] **Step 14.1: CanvasLabelsLayer im canvas einbinden**

In `RoomCanvasView.canvasLayout` (Zeile 111ff) den Hauptcanvas-`ZStack` finden und nach dem letzten Tisch-`ForEach` ergänzen:
```swift
                CanvasLabelsLayer(event: event)
```

(Genauer Ort: lese den `canvasLayout`-Block, finde wo `TableCanvasItemView`-Items per `ForEach` gerendert werden, und füge `CanvasLabelsLayer` direkt danach ein, im selben `ZStack`.)

- [ ] **Step 14.2: „+ Label"-Button in Toolbar**

In `RoomCanvasView` einen passenden Toolbar-Bereich finden (z.B. neben dem „+ Tisch"- oder „Auto-Place"-Button im Inspector oder oben in der Canvas-Toolbar). Falls schwierig zu finden: in den `inspectorPropRow`-Bereich oder als Floating-Button auf dem Canvas.

Pragmatisch: oberhalb des Canvas eine `HStack` mit Button:
```swift
                HStack {
                    Button {
                        addNewLabel()
                    } label: {
                        Label("Label", systemImage: "text.badge.plus")
                    }
                    .warmButton(.secondary, size: .sm)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
```

(Falls `warmButton` nicht zur Hand: nutze `.buttonStyle(.bordered)` als Fallback.)

Funktion ergänzen:
```swift
    private func addNewLabel() {
        guard let event = event else { return }
        let label = CanvasLabel(text: "Neues Label", positionX: 0, positionY: 0)
        label.event = event
        modelContext.insert(label)
        event.labels.append(label)
        try? modelContext.save()
    }
```

- [ ] **Step 14.3: Build + Manueller Test**

Run: `swift build`
Expected: SUCCESS.

App: „+ Label"-Klick → Label „Neues Label" erscheint in Mitte. Doppel-Klick → editieren („Eingang"). Drag → verschieben. Rechtsklick → „Drehen 90°" oder „Löschen".

- [ ] **Step 14.4: Commit**

```bash
git add Sources/Gaesteglueck/Views/RoomCanvasView.swift
git commit -m "feat(canvas): + Label-Button und CanvasLabelsLayer im Saalplan"
```

---

## Task 15: RoomSetupView — Sitzregeln-Stepper

**Files:**
- Modify: `Sources/Gaesteglueck/Views/RoomSetupView.swift`

- [ ] **Step 15.1: ruleRow-Block durch Stepper ersetzen**

In `Sources/Gaesteglueck/Views/RoomSetupView.swift` den Block Zeilen 635-641 (`InspectorSection("Sitzregeln") { ... ruleRow ... }`) ersetzen durch:
```swift
                InspectorSection("Sitzregeln") {
                    if let event = events.first {
                        SeatingRulesEditor(event: event)
                    }
                }
```

(Dafür `@Query private var events: [Event]` an `RoomSetupView` ergänzen, falls nicht schon vorhanden.)

- [ ] **Step 15.2: SeatingRulesEditor-Subview**

Am Ende von `RoomSetupView.swift` ergänzen (vor `#endif` falls vorhanden):
```swift
private struct SeatingRulesEditor: View {
    @Bindable var event: Event

    var body: some View {
        VStack(spacing: 6) {
            ruleStepper(label: "Sitz-Abstand", valueCm: bindingFor(\.seatWidthCm), min: 40, max: 120, step: 5, suffix: "cm/Pers.")
            ruleStepper(label: "Mindestabstand Tische", valueCm: bindingFor(\.tableMinDistanceCm), min: 40, max: 200, step: 10, suffix: "cm")
            ruleStepper(label: "Gangbreite", valueCm: bindingFor(\.aisleWidthCm), min: 60, max: 300, step: 10, suffix: "cm")
            if !event.seatingRules.isValid {
                Text("Gangbreite muss ≥ Mindestabstand sein.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Tokens.Colors.warn)
            }
        }
    }

    private func bindingFor(_ keyPath: WritableKeyPath<SeatingRules, Double>) -> Binding<Double> {
        Binding(
            get: { event.seatingRules[keyPath: keyPath] },
            set: { newValue in
                var rules = event.seatingRules
                rules[keyPath: keyPath] = newValue
                event.seatingRules = rules
                GuestTable.activeRules = rules
            }
        )
    }

    @ViewBuilder
    private func ruleStepper(
        label: String,
        valueCm: Binding<Double>,
        min: Double,
        max: Double,
        step: Double,
        suffix: String
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
            Spacer()
            Text("\(Int(valueCm.wrappedValue)) \(suffix)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
                .monospacedDigit()
            Stepper("", value: valueCm, in: min...max, step: step)
                .labelsHidden()
        }
    }
}
```

- [ ] **Step 15.3: Build prüfen**

Run: `swift build`
Expected: SUCCESS.

- [ ] **Step 15.4: Manueller Test**

App: Sitzregeln-Panel zeigt drei Stepper. Sitzabstand auf 70 ändern → 140×80-Tisch zeigt jetzt „4/4" (vorher 4/6 oder 6/6). Capacity-Anzeigen aktualisieren sich live.

- [ ] **Step 15.5: Commit**

```bash
git add Sources/Gaesteglueck/Views/RoomSetupView.swift
git commit -m "feat(setup): Sitzregeln editierbar mit Steppern und Live-Validierung"
```

---

## Task 16: Vollständiger Test-Lauf

- [ ] **Step 16.1: Komplette Test-Suite**

Run: `swift test`
Expected: alle Tests grün. Falls FAIL: einzelne Tests untersuchen, fixen, **kein** Commit-Skip — entweder im selben Task fixen oder neuen Fix-Commit anlegen.

- [ ] **Step 16.2: Build mit Warning-Check**

Run: `swift build 2>&1 | grep -E "warning:|error:" | head -20`
Expected: keine Errors. Warnings dokumentieren falls neu hinzugekommen, ggf. fixen.

---

## Task 17: Final Smoke-Test (manuell)

- [ ] **Step 17.1: App starten und Walk-Through**

```bash
swift run
```
oder Xcode-Build starten.

Walkthrough:
1. Neues Event → Saal-Setup → 3 Tische 140×80, jeder zeigt 6 Sitze (2/2/2-Verteilung).
2. Tisch rotieren (Rechtsklick → Drehen 90°): Width/Depth-Properties unverändert, visuelle Drehung um Mittelpunkt.
3. Drei 140×80-Tische auswählen → Combine → Tafel mit 16 Sitzen, Folge-Tische ohne Name/Sitze.
4. Tafel draggen → alle drei verschieben sich gemeinsam.
5. Tafel rotieren → alle drei rotieren um gemeinsamen Mittelpunkt.
6. „Verbindung lösen" → drei einzelne Tische, jeder zeigt wieder 6 Sitze.
7. „+ Label" → „Eingang" tippen, an Wand positionieren. „+ Label" → „DJ", positionieren. „+ Label" → „Tanzfläche".
8. Sitzregeln-Stepper: Sitzabstand 70 → 140×80 Tisch zeigt jetzt 4 Sitze. Wieder auf 60 → 6 Sitze.
9. Validierung: Gangbreite 50 setzen → Warning erscheint, Werte werden trotzdem gespeichert (oder UI lehnt ab — beides okay).
10. App schließen, neu öffnen → Schema-Migration V3→V4 läuft sauber durch, Daten erhalten.

- [ ] **Step 17.2: Final Commit (falls Fixes nötig)**

Falls beim Walkthrough Bugs gefunden: pro Bug einen kleinen Fix-Commit. Sonst skip.

---

## Self-Review

**1. Spec-Coverage:**

- ✅ Sektion 1.1 (Capacity-Formel): Task 3
- ✅ Sektion 1.2 (`combinationOrder`): Task 3
- ✅ Sektion 1.3 (Migration): Task 4
- ✅ Sektion 1.4 (Tests): Task 3 Step 7
- ✅ Sektion 2.1-2.4 (TafelLayout): Tasks 6, 10
- ✅ Sektion 2.5 (Combine-Sheet): Task 11
- ✅ Sektion 2.6 (Verbindung lösen): Task 10 (`dissolveTafel`)
- ✅ Sektion 2.7 (Tafel-Drag): Task 10 (`applyDrag`)
- ✅ Sektion 2.8 (Tests): Task 6
- ✅ Sektion 3.1-3.3 (Rotation): Tasks 9, 10
- ✅ Sektion 4.1-4.5 (Sitzregeln): Tasks 1, 4, 7, 8, 12, 15
- ✅ Sektion 4.6 (Reaktivität): Task 12 (`onChange`)
- ✅ Sektion 4.7 (Tests): Tasks 1, 3
- ✅ Sektion 5.1-5.4 (Labels): Tasks 2, 13, 14
- ✅ Sektion 5.5 (Edit/Delete): Task 13
- ✅ Sektion 5.6 (Tests): Task 2

**2. Placeholder-Scan:**
- Task 8 Step 8.1 hat einen weichen Punkt: „Funktion finden, in der das vorkommt". Akzeptabel, weil eine konkrete Zeilennummer (283) gegeben ist und der Fix mechanisch ist.
- Task 10 Step 10.4 hat etwas Code, der von der existierenden Implementation abhängt — Plan-Executor muss `Read` zuerst nutzen. Akzeptabel.
- Task 14 Step 14.2 ist wegen unbekannter Toolbar-Position weicher als ideal. Pragmatischer Fallback (Floating-HStack) ist explizit angegeben.

**3. Type-Konsistenz:**
- `SeatingRules.seatWidthCm`/`tableMinDistanceCm`/`aisleWidthCm` durchgängig.
- `combinationOrder: Int?` durchgängig (nicht `combinationOrder: Int`).
- `TafelLayout.geometry(of:rules:)` mit beiden Parametern in Task 6 definiert und in Task 10 entsprechend genutzt.
- `GuestTable.activeRules` (static) in Task 3 definiert, in Tasks 12 und 15 referenziert.
- `event.seatingRules` (computed property) in Task 4 definiert, in Tasks 12 und 15 genutzt.
- `CanvasLabel.event` (Relationship-inverse) in Task 2 und 4 konsistent.

Plan ist konsistent. Bereit für Execution.
