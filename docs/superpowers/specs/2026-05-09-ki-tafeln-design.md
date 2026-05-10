# KI-Vorschläge mit Tafel-Bewusstsein

**Datum:** 2026-05-09
**Status:** Design — bereit für Plan
**Scope:** SaalKonfigurator-Service + View, Apply-Logik

## Problem

Der KI-Vorschlag im Saal-Konfigurator (`SaalKonfigurator.swift:170-194`) listet Inventar als Solo-Tische („Bis zu 20 rechteckige Tafeln à 140×80, je 6 Plätze") und lässt das LLM eine flache `tables`-Liste generieren. Resultat: jede 12er-Großfamilie kriegt einen unmöglich großen Solo-Tisch, oder wird auf zwei separate Tische verteilt — obwohl drei aneinandergeschobene 140×80-Tische geometrisch perfekt 16 Plätze ergäben.

Die App hat jetzt (siehe Tafel-Layout-Spec) das technische Konzept einer Tafel via `combinationGroup`/`combinationOrder`. Die KI weiß davon nichts.

## Ziele

- Die KI darf mehrere rechteckige Tische zu einer Tafel zusammenfügen.
- Output-JSON markiert Tafel-Mitgliedschaft eindeutig.
- Apply-Logik legt die Tische mit korrektem `combinationGroup`/`combinationOrder` an, positioniert sie aneinandergeschoben.
- Bestehender Solo-Tisch-Fall funktioniert weiter (ohne `tafelGroup` im JSON = Solo).
- **Inventar-Konfiguration:** Der User kann pro Tisch-Vorlage angeben, „die Location erlaubt aus diesem Tisch Tafeln bis maximal N Tische". Default: nur Solo (Tafel bis 1 Tisch = aus). Wenn aktiviert, weiß die KI explizit, dass aus dem 140×80-Tisch eine Tafel bis z.B. 5 Tische gebaut werden darf.

## Nicht-Ziele

- Tafeln aus runden oder gemischt-tiefen Tischen.
- Sitz-Zuweisungen pro Tafel-Sitz (das macht weiterhin der zweite Schritt `LLMSeatingPlanner`).
- Freitext-Inventar-Input — separates Feature.

---

## Sektion 1 — JSON-Output-Format

Heute liefert das LLM:
```json
{
  "tables": [
    { "shape": "rectangular", "widthCM": 140, "depthCM": 80, "name": "Tafel 1", ... }
  ]
}
```

**Erweitert um optionales `tafelGroup`/`tafelOrder`:**
```json
{
  "tables": [
    { "shape": "rectangular", "widthCM": 140, "depthCM": 80, "name": "Großfamilie Maier",
      "tafelGroup": "G1", "tafelOrder": 0, ... },
    { "shape": "rectangular", "widthCM": 140, "depthCM": 80, "name": "Großfamilie Maier",
      "tafelGroup": "G1", "tafelOrder": 1, ... },
    { "shape": "round", "diameterCM": 160, "name": "Freundeskreis", ... }
  ]
}
```

Regeln:
- `tafelGroup`: String-ID (z.B. „G1"). Tische mit gleichem `tafelGroup` bilden eine Tafel.
- `tafelOrder`: 0..n-1, eindeutig pro Group, in Reihenfolge der Tafel.
- `name`: Tafel-Mitglieder dürfen denselben Namen haben oder unterschiedlich. Owner (`tafelOrder == 0`) wird im UI als Tafel-Name angezeigt; andere Namen sind nur intern.

Solo-Tische lassen `tafelGroup` weg.

## Sektion 2 — Inventar-Schema-Erweiterung

`SaalInventar` (Sources/Gaesteglueck/Services/SaalKonfigurator.swift:3) bekommt pro Tisch-Vorlage:

```swift
struct SaalInventar: Sendable, Equatable {
    // ... existing ...
    var rectangularMaxTafelLength: Int = 1   // 1 = nur Solo; 3 = Tafeln aus bis zu 3 Tischen
    // (analog für Brauttafel/Kindertisch nicht — die sind Solo per Definition)
}
```

UI: im SaalKonfiguratorView-Wizard unter „Rechteckige Tafeln" ein zweites Stepper-Feld:
„Können kombiniert werden zu Tafel bis: [1] Tische" (1 = aus, 2-8 = an).
Wenn `rectangularMaxTafelLength > 1`: die KI bekommt im Prompt einen Hinweis (siehe Sektion 3).

## Sektion 3 — Prompt-Erweiterung

`buildUserPrompt` ergänzen um:

```
## Sitzregel
Sitzabstand: \(rules.seatWidthCm) cm pro Person.
```

Wenn `inventory.rectangularMaxTafelLength > 1`, zusätzlich:

```
## Tafel-Möglichkeit
Aus den rechteckigen \(width)×\(depth) cm Tischen kannst du Tafeln bauen,
indem du sie aneinanderschiebst. Erlaubte Tafel-Längen: 2 bis \(maxTafelLength) Tische.

Eine Tafel aus N solchen Tischen hat 2*floor(N*\(width)/\(rules.seatWidthCm)) + 2 Plätze.
Beispiel-Tafeln (mit Sitzabstand \(rules.seatWidthCm)cm):
- 2×\(width)×\(depth) → \(capacity_for_2) Plätze
- 3×\(width)×\(depth) → \(capacity_for_3) Plätze
- 4×\(width)×\(depth) → \(capacity_for_4) Plätze

Bevorzuge Tafeln, wenn eine zusammenhängende Gruppe größer ist als ein einzelner
Tisch fasst. Markiere Tafel-Mitglieder mit:
- "tafelGroup": "G1" (oder G2, G3 ...) bei allen Mitgliedern
- "tafelOrder": 0, 1, 2 ... in Reihenfolge der Tafel
- Alle Mitglieder einer Tafel haben gleiche depthCM
```

Wenn `rectangularMaxTafelLength == 1`: kein Tafel-Hinweis (heutiges Verhalten).

## Sektion 3 — Datenstruktur

`ProposedTable` (`SaalKonfigurator.swift:39`) erweitern um:
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

    // NEU
    var tafelGroup: String?     // "G1", "G2" ...
    var tafelOrder: Int?
}
```

`parseTable` liest die zwei optionalen Felder aus dem JSON.

## Sektion 4 — Validation

`enforceInventoryLimits` muss Tafeln richtig zählen:
- Jeder Tisch zählt einzeln gegen `rectangularMaxCount`.
- Tische einer Tafel müssen alle gleiche `depthCM` haben.
- `tafelOrder` pro Group muss von 0 starten und keine Lücken haben — sonst Group reparieren oder verwerfen.
- Tafel-Länge darf `inventory.rectangularMaxTafelLength` nicht überschreiten — überzählige Mitglieder werden zu Solos.

Neuer Helper:
```swift
private func validateAndFixTafelGroups(_ tables: [ProposedTable]) -> [ProposedTable]
```

Zerlegt Tische in:
- Solo (kein `tafelGroup`)
- Tafeln (gruppiert nach `tafelGroup`, sortiert nach `tafelOrder`, Konsistenz geprüft)

Inkonsistente Tafeln (verschiedene Tiefe, fehlende Order) werden zu Solos degradiert.

## Sektion 5 — Apply-Logik

`SaalKonfiguratorView.insertProposedTables` (Zeile 542) erweitern:

1. Nach dem Erstellen aller `GuestTable`s: Tafel-Groups in `combinationGroup` / `combinationOrder` übersetzen.
2. Für jede Tafel-Group: eine echte UUID generieren (statt String „G1"), allen Tischen zuweisen.
3. Positionen: Owner (Order 0) bekommt das nächste Grid-Slot, Folgetische werden direkt rechts daneben gesetzt (X = owner.x + Σ widths/2 + ownWidth/2).
4. Folgetische überspringen das Grid-Layout (sonst zerreißt es die Tafel).

```swift
private func insertProposedTables(_ specs: [ProposedTable]) -> [GuestTable] {
    // 1. Erst alle Tische anlegen
    // 2. Solo-Tische ins Grid platzieren
    // 3. Tafel-Owner ins Grid, Folge-Tische nebenan
}
```

## Sektion 6 — UI-Polish (klein)

Im Vorschlag-Review-Bereich (`reviewStage`) Tafel-Mitglieder visuell zusammen darstellen:
- Eine Zeile pro Tafel mit „Tafel: 3 × 140×80 = 16 Plätze"
- Solo-Tische einzeln wie heute

Falls zu aufwendig: erstmal weglassen, jeder Tisch wird einzeln aufgelistet aber mit „(Tafel G1, Position 0)" Hinweis.

## Sektion 7 — Tests

`SaalKonfiguratorTests` (neu, falls noch nicht da):
- `parseResponse` mit Tafel-JSON liefert `ProposedTable[]` mit `tafelGroup`/`tafelOrder` korrekt.
- `validateAndFixTafelGroups`:
  - 3 Tische mit Group=G1 und Order=0,1,2 → bleiben Tafel.
  - 2 Tische mit Group=G1 und Order=0,2 (Lücke) → werden zu Solos.
  - 2 Tische mit Group=G1 aber unterschiedlicher Tiefe → werden zu Solos.
- `enforceInventoryLimits`: Tafel mit 3 Tischen plus 5 Solo-Rect-Tische passt in `rectangularMaxCount=8`, ein 9. wird gekappt.

## Erfolgs-Kriterien

- Mit Inventar 8 rect (140×80) + 5 round (160) und 24 Gästen mit zwei Großfamilien (12+8) plus Freundeskreis (6) liefert die KI eine Tafel aus 3×140×80 (16 Plätze) plus Tafel aus 2×140×80 (10 Plätze) plus 1 Rundtisch — getestet manuell.
- Apply legt Tafeln korrekt an (gleiche `combinationGroup`, `combinationOrder` 0..n-1, Tische aneinandergeschoben).
- Solo-Tisch-Pfad weiter funktional.
