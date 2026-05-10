# Tafel-Layout, Capacity-Fix, Rotation, Sitzregeln & Canvas-Labels

**Datum:** 2026-05-09
**Status:** Design — bereit für Plan
**Scope:** Saalplan-Canvas; Models (`Event`, `GuestTable`, neuer `CanvasLabel`), Views/Canvas, neue Service-Komponente

## Problem

Drei Effekte greifen ineinander und machen den Tafel-Bau im Canvas heute unbrauchbar, wenn man eine reale Location-Tisch-Konfiguration (z.B. 140×80) abbilden will:

1. **Capacity-Formel falsch.** Ein 140×80-Tisch zeigt 5 Plätze, geometrisch passten 6 (4 lang + 2 kurz). Heutige Formel `floor(perimeter/60) − 2` ist eine Heuristik mit pauschalem Eckenabzug, die bei manchen Größen zufällig stimmt.
2. **Sitzverteilung unsymmetrisch.** Bei ungerader Längsseiten-Sitzanzahl bekommt die Oberkante immer den Rest („oben 2, unten 1"). Optisch unsauber, in `SeatLayout.rectPositions`.
3. **Tafel ≠ ein Tisch.** Verbundene Tische (`combinationGroup` gesetzt) werden weiterhin einzeln gerendert. Folgen: an inneren Stoßkanten erscheinen geisterhafte „Kopfsitze", an den echten Tafel-Außenenden hängt es zufällig davon ab, ob die Capacity gerade `endSeatCount=2` zulässt.

Außerdem fehlt **Rotation**: `GuestTable.rotation` existiert im Modell, wird aber nirgendwo gerendert. User muss heute Width/Depth manuell tauschen, wenn er einen Tisch quer stellen will.

Zwei verwandte Defizite, die im selben Render-Layer liegen und deshalb mit eingezogen werden:

4. **Sitzregeln nicht editierbar.** Das „SITZREGELN"-Panel in `RoomSetupView` zeigt 60/80/120 cm read-only. Werte sind in mehreren Quelldateien hardcoded (`GuestTable.swift:29`, `RoomSetupView.swift:271`, `SaalKonfigurator.swift:283`, `TablePlacer.swift:10-12`). Wenn ein Saal andere Maße braucht (engerer Sitzabstand bei Bestuhlung, breitere Gänge), muss man Code ändern. Dies blockiert auch den Capacity-Fix: dort wird der Sitzabstand zur Konfigurationsgröße.
5. **Canvas-Labels hardcoded.** „BÜHNE ↑" und „EINGANG ↓" stehen fest in `RoomCanvasView.swift:485-514`. User hat in seinem Raum keine Bühne, dafür Eingang/DJ/Tanzfläche/Treppe an unterschiedlichen Stellen — er kann das aktuell nicht abbilden.

## Ziele

- 140×80 ergibt geometrisch korrekt **6 Plätze**, beliebige Größen folgen einer einheitlichen Formel.
- Sitzverteilung am Rechteck ist **symmetrisch** (oder Asymmetrie nur dort, wo sie geometrisch unvermeidbar ist).
- Eine Tafel aus N verbundenen Tischen wird als **ein** durchgehendes Rechteck gerendert: Sitze nur an Außenkanten, je 1 Sitz an den beiden äußeren Kopfenden, keine Sitze an inneren Stoßkanten.
- **Rotation per 90°-Schritten** über Kontext-Menü, visuelle Drehung ohne Modell-Tausch.
- **Sitzregeln editierbar** (Sitzabstand, Mindestabstand Tische, Gangbreite) — eine Quelle, aus der Capacity-Berechnung und Auto-Place lesen.
- **Canvas-Labels** (Eingang, DJ, Tanzfläche, Treppe …) frei platzierbar; das hardcoded „BÜHNE"/„EINGANG" entfällt.

## Nicht-Ziele

- Freie (kontinuierliche) Rotation. Fokus auf 90°-Steps.
- Auto-Kombination per Drag (Tische die sich berühren werden nicht automatisch zur Tafel). Combine bleibt explizit über Sheet/Menü.
- Migration alter `combinationRole`-Daten in Cloud-Sync. Lokal-only, einmaliger Bump beim nächsten Laden.
- Sitz-Reassignment-Heuristik beim Combine („wer wo am ähnlichsten landet"). Wir machen einfache Lösung.
- Sitzregeln pro Tisch / pro Bereich. Eine globale Regel pro Event reicht.
- Label-Versionierung, gestylte Labels, Icons in Labels. Plain Text + Position + Rotation.

---

## Sektion 1 — Capacity & Datenmodell

### 1.1 Capacity-Formel (rectangular)

**Aktuell** (`GuestTable.capacity`):
```swift
let perimeter = 2 * (width + depth)
let rawSeats  = Int(perimeter / 60)
return max(rawSeats - 2, 4)
```
Für 140×80: `Int(440/60) = 7`, `7 − 2 = 5`. Falsch.

**Neu:**
```swift
// seatWidth wird aus SeatingRules gelesen (siehe Sektion 4); Default 60.
case .rectangular:
    let longSeats  = 2 * Int(width / seatWidth)            // Längsseiten
    let shortSeats = 2 * (depth >= seatWidth ? 1 : 0)      // Kopfenden, je 1
    return longSeats + shortSeats
```

**Begründung:** Ein Sitz braucht eine Seite, Ecken sind tot. Der Umfang-Ansatz behandelt den Tisch wie einen abgewickelten Kreis und überzählt deshalb systematisch — der `−2`-Patch ist ein pauschales Korrektiv, das bei manchen Größen passt und bei anderen nicht. Per-Seite-Zählung ist physikalisch und erfordert keine Magic-Constant.

**Hinweis zur Daten-Abhängigkeit:** `capacity` ist heute reine Computed-Property auf `GuestTable`. Mit `seatWidth` aus Event-Kontext braucht sie eine Quelle dafür — Lösung in Sektion 4.4.

**Rechenbeispiele:**

| width × depth | long | short | total |
|---|---|---|---|
| 140 × 80  | 4 | 2 | **6** |
| 200 × 100 | 6 | 2 | 8 |
| 80 × 80   | 2 | 2 | 4 |
| 60 × 60   | 2 | 2 | 4 |
| 140 × 50  | 4 | 0 | 4 |

Die Quadrat-Variante (`case .square`) bekommt analog die neue Formel mit `width = depth`.

### 1.2 Combinations-Modell

`CombinationRole` (head/middle/end/corner) ist semantisch unklar bei Tafeln aus >2 Tischen. Ersetzen durch ordinale Zahl:

```swift
final class GuestTable {
    var combinationGroup: UUID?
    var combinationOrder: Int?     // 0 = Owner, 1, 2, …
    // CombinationRole bleibt im Quellbaum (für Schemas), wird aber nicht gelesen
}
```

- `combinationOrder == 0` → Owner-Tisch der Tafel (rendert Sitze, hält Tafel-Namen).
- `combinationOrder > 0` → Folge-Tisch (rendert nur Form, keine Sitze, keinen Namen).

### 1.3 SwiftData-Migration

`combinationOrder: Int?` als neues Feld. Beim ersten Laden:
- Tische ohne `combinationGroup`: `combinationOrder = nil`.
- Tische mit `combinationGroup`: für jede Group einmal sortieren (z.B. nach `name`), `combinationOrder` 0..n−1 setzen.

`CombinationRole` wird ignoriert. Schema-Bump je nach aktuellem Versioning-Stand.

### 1.4 Tests

`GuestTableCapacityTests`:
- 140×80 → 6
- 200×100 → 8
- 80×80 → 4
- 60×60 → 4
- 140×50 → 4 (Kurzseite zu schmal für Kopfsitz)
- 50×50 → 0 (Edge: zu kleiner Tisch). Die alte `max(…, 4)`-Klemme entfällt; geometrisch korrekt heißt: zu kleine Tische haben 0 Plätze. Validierung gegen unrealistische Tisch-Erstellung erfolgt im `TableFormView`, nicht in `capacity`.

---

## Sektion 2 — Tafel als virtuelles Rechteck

### 2.1 Konzept

Eine Tafel ist eine Gruppe von Tischen mit gleichem `combinationGroup`. Gerendert wird sie als **eine** durchgehende Form mit **einer** durchgehenden Sitzreihe an den Außenkanten. Die einzelnen Tische bleiben Daten-Container für ihre Gäste — die Tafel-Schicht ist rein visuell und für Sitz-Positionierung.

### 2.2 Neuer Service: `TafelLayout`

Datei: `Sources/Gaesteglueck/Services/TafelLayout.swift`.

```swift
enum TafelLayout {
    struct Seat {
        let position: CGPoint        // global, Canvas-Koordinaten
        let tableID: UUID            // welcher Tisch hostet diesen Sitz
        let localSeatIndex: Int      // 0..table.capacity-1
    }

    struct TafelGeometry {
        let totalWidth: CGFloat      // Σ widths
        let depth: CGFloat           // alle gleich (Annahme)
        let center: CGPoint          // geometrischer Mittelpunkt
        let rotation: Double         // = owner.rotation
        let capacity: Int            // 2*floor(totalWidth/60) + 2
        let seats: [Seat]
    }

    /// Berechnet Tafel-Geometrie aus den Tischen einer Group, sortiert nach combinationOrder.
    static func geometry(of tables: [GuestTable], rules: SeatingRules) -> TafelGeometry
}
```

**Algorithmus:**
1. Sortiere `tables` nach `combinationOrder`.
2. `totalWidth = Σ table.width`. `depth = tables[0].depth`. (Falls Tische unterschiedliche Tiefe haben: `depth = max(...)`. Das passiert in der Praxis nicht, weil Combine-Sheet nur kompatible Tische zulässt — siehe 2.5.)
3. `center` = Mittelpunkt aller Tisch-Mittelpunkte (gewichtet nach Breite).
4. Rotation = Owner-Tisch-Rotation.
5. **Längsseiten-Sitze:** `nLong = floor(totalWidth/seatWidth)` pro Seite (`seatWidth` aus `SeatingRules`). Verteilung gleichmäßig über `[-totalWidth/2, +totalWidth/2]`. Top und Bottom je `nLong`.
6. **Kopfsitze:** je 1 links und rechts (außerhalb der Tafel, an Mitte der Kurzseite des äußersten Tisches).
7. Für jeden Sitz: globale Position errechnen (vor Rotation, in Tafel-lokalen Koordinaten), dann Rotation um `center` anwenden.
8. **Sitz → Tisch-Mapping:** Längsseiten-Sitz fällt dem Tisch zu, in dessen X-Bereich er liegt (vor Rotation). Kopfsitze gehören zum jeweiligen äußersten Tisch.
9. **Local-seat-index pro Tisch:** Sitze, die auf einen Tisch fallen, werden 0..k−1 nummeriert. Reihenfolge: oben links→rechts, dann unten links→rechts, dann linker Kopfsitz, dann rechter Kopfsitz (wie heute in `SeatLayout.rectPositions`).

### 2.3 Render-Änderung in `TableCanvasItemView`

Neue Verzweigung am Anfang des `body`:

```swift
if let order = table.combinationOrder, order > 0 {
    // Folge-Tisch: nur Form, keine Sitze, kein Name
    plainRectShape
} else if table.combinationGroup != nil {
    // Owner-Tisch: eigene Form + Tafel-weite Sitze
    ownerShapeWithTafelSeats
} else {
    // Solo-Tisch: heute
    soloRendering
}
```

Owner-Rendering nutzt `TafelLayout.geometry(of: groupTables)` für:
- Sitzpositionen (alle Sitze der Tafel zeichnen, jeder Chip hält `tableID`/`localSeatIndex` aus dem Mapping).
- Namens-Label: `table.name` (= Tafel-Name; Owner trägt den Namen).
- Capacity-Anzeige: `sittingCount / tafelCapacity`, wobei `sittingCount = Σ tables.guests.count(where: seatIndex != nil)`. Gäste ohne `seatIndex` (z.B. nach Combine) zählen nicht in die Anzeige; die Tafel zeigt also nicht „12/10 overfull". Eine separate kleine Hinweis-Badge zeigt unsitzierte Gäste an, wenn vorhanden.

Folge-Tische rendern als nahtloses Rechteck (z.B. Cornerradius 0 an Innenkanten; einfachste Variante: alle Folge-Tische bekommen `cornerRadius = 0` und kein Border, Owner zeichnet einen umfassenden Border über die ganze Tafel).

**Vereinfachung erste Iteration:** Wir zeichnen jeden Tisch weiterhin als eigene Box mit Border. Visuell sieht man die Stoßkanten als dünne Linie — okay für v1. Später (out-of-scope): Owner zeichnet ein einzelnes Tafel-Rechteck und Folge-Tische werden unsichtbar.

### 2.4 Sitz-Zuweisung (Drag & Drop)

In `TableCanvasItemView.assignGuestToSeat` wird bei Tafel-Render der Drop-Handler `TafelLayout.Seat` mitgegeben:

```swift
private func assignGuestToTafelSeat(guestID: UUID, seat: TafelLayout.Seat) -> Bool {
    let targetTable = allTables.first(where: { $0.id == seat.tableID })!
    // ab hier identisch zu heutiger Logik, nur targetTable statt table
}
```

Damit bleibt das Datenmodell unverändert: Gast hängt an dem konkreten Tisch, dessen Segment er physisch belegt. Auflösen einer Tafel verteilt Gäste automatisch korrekt auf die Einzeltische.

### 2.5 Combine-Sheet

`TableCombineSheet` wird erweitert:

- **Mehrfachauswahl** statt Single-Pick. UI: Liste mit Toggles, primary Action „N Tische zur Tafel verbinden".
- **Filter:** nur Tische mit gleicher `depth` werden angeboten (sonst Tafel-Geometrie inkonsistent).
- **Bei OK:**
  1. Group-UUID erzeugen oder vorhandene nehmen.
  2. Reihenfolge: aktueller Tisch ist Owner (`combinationOrder = 0`), ausgewählte werden 1..n in Auswahl-Reihenfolge.
  3. Positionen ausrichten: alle bekommen `positionY = owner.positionY`, X aufsteigend so dass die Tafel um den Owner-Mittelpunkt zentriert ist: `positionX = owner.positionX − totalWidth/2 + Σᵢ<ⱼ widthᵢ + widthⱼ/2`.
  4. Alle übernehmen `owner.rotation`.
  5. **Sitz-Reset:** Alle Gäste **aller** beteiligten Tische (inkl. Owner) bekommen `seatIndex = nil`. Gäste bleiben ihrem ursprünglichen Tisch zugeordnet, sind aber unsitziert bis manuell oder via Auto-Place neu platziert. Begründung: Combine ändert die Sitz-Geometrie der ganzen Tafel; alte Indices verlieren ihre Bedeutung. Einfacher und vorhersehbarer als selektives Reseating.

### 2.6 Verbindung lösen

Heute schon im Kontext-Menü vorhanden. Anpassung:
- Alle Tische der Group: `combinationGroup = nil`, `combinationOrder = nil`.
- Positionen bleiben wie sie sind (Tische stehen weiterhin nebeneinander, sind aber wieder einzeln).
- Gäste behalten `table` und `seatIndex` — das Solo-Layout passt automatisch (jeder Tisch hat wieder eigene Kopfsitze).

### 2.7 Tafel-Drag

Drag auf einem Tafel-Tisch (egal ob Owner oder Folge) verschiebt **alle** Tische der Group um den gleichen Vektor. Implementation: in `DragGesture.onEnded` zusätzlich `for t in groupTables where t.id != table.id { t.positionX += value.translation.width; t.positionY += value.translation.height }`.

### 2.8 Tests

`TafelLayoutTests`:
- 2 × (140×80) ergibt `totalWidth=280`, `capacity = 2·floor(280/60) + 2 = 2·4 + 2 = 10`.
- 3 × (140×80) ergibt `totalWidth=420`, `capacity = 2·7 + 2 = 16`.
- Sitz→Tisch-Mapping: erste 4 Sitze auf der oberen Längsseite einer 2×140-Tafel fallen auf Tisch 0 / Tisch 1 / Tisch 1 / Tisch 1 oder ähnlich (je nach Verteilung) — testen, dass keine Out-of-bounds.
- Kopfsitz links → Owner-Tisch, Kopfsitz rechts → letzter Tisch.
- Drei-Tisch-Tafel mit Rotation 90°: Sitzpositionen rotieren mit, Mapping bleibt stabil.

---

## Sektion 3 — Rotation R1

### 3.1 Rendering

In `TableCanvasItemView`:
```swift
.rotationEffect(.degrees(table.rotation))
```
um die Tisch-Form **und** Sitzchips. Die `.position(...)` bleibt am Mittelpunkt, Rotation ist um den Mittelpunkt. Das funktioniert ohne Bounding-Box-Korrektur.

### 3.2 Bedienung

Kontext-Menü-Eintrag „Drehen 90°" (clockwise):
```swift
table.rotation = (table.rotation + 90).truncatingRemainder(dividingBy: 360)
```
Bei Tafel-Tisch (egal Owner oder Folge): Rotation wird **auf Tafel-Ebene** angewendet:
1. `newRotation = (owner.rotation + 90) mod 360`
2. Alle Tische der Group: `rotation = newRotation`
3. Positionen rotieren um den Tafel-Mittelpunkt mit (sonst „läuft" die Tafel auseinander). Berechnen via `TafelLayout.geometry(...).center`.

### 3.3 Width/Depth bleiben unverändert

Bei 90°-Drehung tauschen wir `width`/`depth` **nicht** im Modell. Capacity wird aus den Modell-Werten berechnet, also bleibt 140×80 nach Drehung weiter 6 Plätze. Saubere Trennung Daten ↔ visuelle Orientierung.

### 3.4 Tests

`TableRotationTests`:
- 4 × +90° = 0 (modulo).
- Capacity stabil über alle Rotationen.
- Tafel-Rotation: alle Tische haben am Ende dieselbe Rotation, Positionen sind gespiegelt um Mittelpunkt.

---

## Sektion 4 — Sitzregeln editierbar

### 4.1 Modell

Neue Struktur, am `Event` als Composite-Wert:

```swift
struct SeatingRules: Codable, Equatable {
    var seatWidthCm: Double          // default 60
    var tableMinDistanceCm: Double   // default 80
    var aisleWidthCm: Double         // default 120

    static let `default` = SeatingRules(
        seatWidthCm: 60, tableMinDistanceCm: 80, aisleWidthCm: 120
    )
}
```

Auf `Event` neu:
```swift
var seatingRulesData: Data?      // codiertes SeatingRules (SwiftData mag keine Structs direkt)
var seatingRules: SeatingRules { get/set über Codable }   // computed Wrapper
```

Default-Werte beim Lesen wenn `seatingRulesData == nil`.

### 4.2 Quellen-Mapping

Die heute hardcoded `60`/`80`/`100`/`120` werden konsolidiert. Mapping aktueller Konstante → neuer Regel-Wert:

| heute (Datei:Zeile) | konstantenname | neuer Bezug |
|---|---|---|
| `GuestTable.swift:29` | `seatWidth: 60` | `rules.seatWidthCm` |
| `RoomSetupView.swift:271` | `seatWidth: 60` | `rules.seatWidthCm` |
| `SaalKonfigurator.swift:283` | `seatWidth: 60` | `rules.seatWidthCm` |
| `TablePlacer.swift:10` | `chairBuffer: 80` | `rules.tableMinDistanceCm` |
| `TablePlacer.swift:11` | `walkwayBuffer: 100` | _bleibt intern_, ggf. ableitbar aus `aisleWidthCm` (siehe 4.3) |
| `TablePlacer.swift:12` | `wallMargin: 120` | `rules.aisleWidthCm` |

Die Sitzregeln-Anzeige (RoomSetupView, ehem. statisch) wird editierbar und zeigt **nur die drei sichtbaren Regeln** (Sitzabstand, Mindestabstand Tische, Gangbreite). `walkwayBuffer` ist eine Implementierungs-Konstante und bleibt nicht-editierbar bei 100 (oder wir entfernen sie und nutzen `aisleWidthCm − tableMinDistanceCm` als Ableitung — siehe 4.3).

### 4.3 `walkwayBuffer` — bleibt oder weg?

Heute existiert sowohl `chairBuffer` (= um Tisch herum für Stühle) als auch `walkwayBuffer` (= zusätzlicher Puffer zwischen Tischen darüber hinaus). Beide werden in `TablePlacer.findNonOverlappingPosition` addiert. Aus User-Sicht ist „Mindestabstand zwischen Tischen" eine Größe — die Trennung ist intern.

Vorschlag: `walkwayBuffer` als Konstante `40` belassen (= zusätzlicher Komfort-Puffer beyond chair-space), dokumentieren. So bleibt das Verhalten von Auto-Place stabil und User editiert nur die drei Werte, die er auch versteht. Falls sich später herausstellt, dass die Defaults nicht passen, kann man `walkwayBuffer = 0` setzen und ist wieder bei „nur User-Werte zählen".

### 4.4 Capacity & Event-Zugriff

`GuestTable.capacity` braucht jetzt eine `SeatingRules`-Quelle. Drei Optionen:

- **(a) Über `Event`-Reference:** `GuestTable` bekommt `var event: Event?` (SwiftData-Relation). Nachteil: alle `GuestTable` müssen ein Event haben, neue Relation, Migrations-Aufwand.
- **(b) Static + globaler Default:** `static var globalRules: SeatingRules = .default` — gesetzt vom App-Lifecycle beim Event-Load. Einfach, aber Globaler Zustand.
- **(c) Capacity wird von Capacity-Aufrufer mitgegeben:** Aus reinem Property wird `func capacity(rules: SeatingRules) -> Int`. Sauber, kein globaler Zustand. Aufrufer muss Rules kennen.

**Empfehlung: (c)** plus eine Convenience-Property `var capacity: Int { capacity(rules: .default) }` für Code, der den Wert ohne Kontext braucht (z.B. Debug-Log). Alle UI-Pfade reichen explizit die Event-Rules durch — die kennt der Canvas eh, weil er für ein konkretes Event rendert.

Konkret heißt das:
- `GuestTable.capacity(rules:)` neue Methode mit der Formel aus Sektion 1.1.
- `GuestTable.capacity` als deprecated computed property (default rules) — bleibt für Tests und Inkrementalität, wird in v2 entfernt.
- `TableCanvasItemView`, `TafelLayout`, `SeatingOptimizer`, `TablePlacer` etc. nehmen Rules als Parameter.

### 4.5 UI: Sitzregeln editieren

In `RoomSetupView` ersetzen: `ruleRow("Sitz-Abstand", "60 cm/Pers.")` → editierbares Feld. Vorschlag pro Zeile: `Stepper` mit Schritt 5 cm, Bereich 40…200, gebunden an `event.seatingRules.seatWidthCm` (etc.). Direktes Edit ohne Modal — Save-on-Change (SwiftData persistiert automatisch).

Zwei kleine Validierungen:
- `seatWidthCm >= 40` (sonst Sitze überlappen physisch).
- `aisleWidthCm >= tableMinDistanceCm` (Gangbreite mindestens so groß wie Tisch-Mindestabstand — sonst inkonsistent). Bei Verletzung: kein Save, rote Hinweis-Zeile.

### 4.6 Capacity-Reaktivität

Wenn der User die Sitzregeln ändert, müssen Capacity-Anzeigen am Canvas sich aktualisieren. Da `seatingRules` ein `@Model`-Feld auf `Event` ist und SwiftData beobachtet, reicht es wenn die Views, die Capacity rendern, den Event als `@Bindable`/`@Query` halten. Konkret: `RoomCanvasView`/`TableCanvasItemView` bekommen Zugriff auf das aktive Event (heute schon vorhanden über `@Query`) und nutzen `event.seatingRules` in den Capacity-Calls. Tests prüfen: Sitz-Regel ändern → Capacity ändert sich → Sitzlayout passt sich an.

**Achtung Datenkonsistenz:** Wenn der User den Sitzabstand erhöht und dadurch Capacity sinkt, kann `guests.count > capacity` werden. Das System lässt das zu (über-besetzte Tische zeigen rot), aber **`seatIndex` bleibt erhalten** — Sitze, die im neuen Layout nicht mehr existieren (Index ≥ neuer Capacity), werden im Render einfach nicht gezeigt. Hinweis-Badge „X überzählige Gäste" am Tisch.

### 4.7 Tests

`SeatingRulesTests`:
- Default-Werte korrekt.
- Codable Roundtrip.
- Validierung: `seatWidthCm < 40` wird abgelehnt.
- Validierung: `aisleWidthCm < tableMinDistanceCm` wird abgelehnt.

`GuestTableCapacityTests` (erweitert):
- 140×80 mit `seatWidth=60` → 6 (wie 1.4).
- 140×80 mit `seatWidth=70` → `2*Int(140/70) + 2 = 6` (knapp).
- 140×80 mit `seatWidth=80` → `2*1 + 2 = 4`.
- 140×80 mit `seatWidth=50` → `2*2 + 2 = 6` (Längsseiten 2 Sitze, weil floor(140/50)=2).

`TablePlacerRulesTests`:
- Auto-Place mit veränderten Rules → andere Footprints, andere Positionen.

---

## Sektion 5 — Canvas-Labels

### 5.1 Modell

Neues SwiftData-Modell:

```swift
@Model
final class CanvasLabel {
    var id: UUID
    var text: String
    var positionX: Double
    var positionY: Double
    var rotation: Double      // 0/90/180/270 für v1, free für später
    var event: Event?         // SwiftData-Relation, optional damit cascade einfach bleibt

    init(text: String, positionX: Double = 0, positionY: Double = 0) { ... }
}
```

Auf `Event` neu: `var labels: [CanvasLabel]` (oder per `@Relationship`-Inverse, je nach SwiftData-Konvention im Projekt; bestehende Relationen prüfen).

### 5.2 Hardcoded-Labels entfernen

`RoomCanvasView.swift:483-514`: die Block-Statements für „BÜHNE ↑" und „EINGANG ↓" werden entfernt. Stattdessen rendert ein neuer `CanvasLabelsLayer` alle `event.labels`.

**Migration:** Beim ersten Laden in einem Event ohne Labels → keine seed-Labels einfügen. User startet mit leerem Canvas und legt selbst an, was er braucht. (Alternative wäre einen Default-Eingang an unten links zu seeden — wir verzichten darauf, weil der Eingang in jedem Saal woanders liegt.)

### 5.3 Render

Neuer SubView `CanvasLabelView`:
- Zeigt `text` als Label (Font wie heute: `system 10.5pt semibold rounded`, `tracking 0.5`, Farbe `Tokens.Colors.ink3`).
- Drag-Gesture verschiebt `positionX`/`positionY` (analog `TableCanvasItemView`).
- Tap selektiert (Visual: leichte Border-Box).
- Doppel-Tap öffnet kleines Inline-Edit (TextField overlay).
- Kontext-Menü: „Bearbeiten…", „Drehen 90°", „Löschen".

### 5.4 UI: Label hinzufügen

In der Canvas-Toolbar neuer Button „+ Label" mit Symbol `text.badge.plus`. On Tap:
1. `CanvasLabel(text: "Neues Label", positionX: roomCenter.x, positionY: roomCenter.y)` erstellen, dem Event anhängen.
2. Sofort selektiert, Edit-Mode aktiv (Inline-TextField).
3. User tippt Text und drückt Enter, oder positioniert per Drag.

Schneller-Pfad ohne Modal — drei Klicks weniger als Sheet-basiert.

### 5.5 Edit & Delete

- Edit-Text: Doppel-Tap öffnet TextField-Overlay direkt am Label-Position. Enter speichert, Escape verwirft.
- Drehen 90°: `label.rotation = (label.rotation + 90).truncatingRemainder(dividingBy: 360)` — Render mit `.rotationEffect`.
- Löschen: Kontext-Menü „Löschen" → modelContext.delete(label).

### 5.6 Tests

`CanvasLabelTests`:
- Label erstellen → erscheint in `event.labels`.
- Position-Update persistiert.
- Rotation +90° viermal = 0 (mod).
- Löschen entfernt aus Event.

UI-Smoke-Test: hardcoded „BÜHNE"/„EINGANG" sind nicht mehr im Canvas vorhanden.

---

## Architektur-Übersicht

```
Models/
  GuestTable.swift           ← capacity(rules:) neu, combinationOrder ergänzen
  Event.swift                ← seatingRulesData + labels-Relation
  SeatingRules.swift         ← NEU: Codable-Struct
  CanvasLabel.swift          ← NEU: SwiftData-Model
Services/
  TafelLayout.swift          ← NEU: Geometrie + Sitz-Mapping (rules-aware)
  TablePlacer.swift          ← liest Konstanten aus SeatingRules
  SaalKonfigurator.swift     ← seatWidth aus Rules
Views/Canvas/
  SeatLayout.swift           ← rectPositions: Symmetrie-Fix für Solo-Tische, rules-aware
  TableCanvasItemView.swift  ← Render-Switch Solo/Owner/Folge, Rotation, Tafel-Drag
  TableCombineSheet.swift    ← Mehrfachauswahl, Depth-Filter, Sitz-Reset
  CanvasLabelView.swift      ← NEU: Label-Render + Drag + Edit
  CanvasLabelsLayer.swift    ← NEU: rendert event.labels
Views/
  RoomCanvasView.swift       ← BÜHNE/EINGANG entfernt, Labels-Layer eingebunden, "+ Label" Button
  RoomSetupView.swift        ← Sitzregeln editierbar (Stepper statt ruleRow)
Tests/
  GuestTableCapacityTests.swift   ← NEU (rules-parametrisiert)
  TafelLayoutTests.swift          ← NEU
  TableRotationTests.swift        ← NEU
  SeatLayoutTests.swift           ← Symmetrie-Erweiterung
  SeatingRulesTests.swift         ← NEU
  TablePlacerRulesTests.swift     ← NEU
  CanvasLabelTests.swift          ← NEU
```

## Risiken & offene Punkte

- **SwiftData-Migration:** Existierender Schema-Versioning-Stand muss vor Implementierung geprüft werden — Schema-Bump für `combinationOrder`, `seatingRulesData`, `CanvasLabel` und `Event.labels`-Relation.
- **Visuelle Naht zwischen Tafel-Tischen:** Erste Iteration zeigt einzelne Borders. Wenn störend, in Folge-Plan optisch verschmelzen.
- **Drag-Konflikte:** Tafel-Drag darf nicht versehentlich einzelne Tische lösen. Falls User Tische wirklich einzeln bewegen will, muss er erst „Verbindung lösen".
- **Auto-Place / SeatingOptimizer:** Diese Services arbeiten heute pro `GuestTable`. Funktioniert weiter — eine Tafel ist aus deren Sicht N Tische mit je eigenen Capacities. Tafel-Render ist nur visuell. Dürfte keine Änderung erfordern, sollte aber im Plan validiert werden.
- **Capacity-API-Änderung:** `capacity` wird von computed property auf `capacity(rules:)` umgestellt. Alle Aufrufer im Quellbaum müssen migriert werden. Ein `default`-Wrapper bleibt für Inkrementalität, sollte aber im Plan vor Abschluss entfernt werden, damit es keine versehentlich-falschen Defaults gibt.
- **Label-Persistenz vs. Plan-Versionen:** `CanvasLabel` ist eine eigene Entity am Event. Im Folge-Spec (Plan-Versionen) müssen Labels mit-snapshotted werden — strukturell genau wie Tische.

## Erfolgs-Kriterien

- 140×80 Solo zeigt 6 Sitze, davon 2 oben + 2 unten + 2 Kopfenden.
- 2 × (140×80) als Tafel zeigt 10 Sitze: 4 oben + 4 unten + 2 außen.
- Kontext-Menü „Drehen 90°" auf Solo-Tisch dreht ihn samt Sitzen, Width/Depth im Modell unverändert.
- Kontext-Menü „Drehen 90°" auf Tafel-Tisch dreht die ganze Tafel.
- „Verbindung lösen" zerlegt die Tafel ohne Datenverlust an Gästen (Sitzplätze ggf. neu zugewiesen).
- Sitzregeln im Inspector editierbar; Werte-Änderung aktualisiert Capacity-Anzeigen und Sitzlayout live.
- Validierung: Sitzabstand <40cm und Gangbreite < Tisch-Mindestabstand werden abgelehnt.
- Auto-Place berücksichtigt geänderte Tisch-Mindestabstand- und Gangbreite-Werte.
- „BÜHNE ↑" und „EINGANG ↓" sind im Canvas nicht mehr sichtbar (außer als User-eigene Labels).
- „+ Label"-Button erstellt ein platzierbares Text-Label, das per Drag verschoben, per Doppel-Tap editiert, per Kontext-Menü gedreht/gelöscht werden kann.
- Tests grün: Capacity, TafelLayout, Rotation, SeatLayout-Symmetrie, SeatingRules, TablePlacerRules, CanvasLabel.
