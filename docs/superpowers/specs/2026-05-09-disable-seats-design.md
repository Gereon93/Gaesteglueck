# Sitze deaktivieren

**Datum:** 2026-05-09
**Status:** Design — bereit für Plan
**Scope:** GuestTable-Modell, SeatChipView, Capacity-Logik

## Problem

User will auf bestimmten Tischen einzelne Sitze sperren — Beispiel: an der Brauttafel die 2 Sitze direkt gegenüber vom Brautpaar sollen frei bleiben (für Bewegungsraum / Reden). Aktuell gibt's keine Möglichkeit, das ist alles oder nichts.

## Ziele

- Pro Tisch eine Menge gesperrter `seatIndex` speichern.
- Gesperrter Sitz: visuell durchgestrichen/leer, kein Drop-Target, nicht in `effectiveCapacity` mitgezählt.
- Toggle per Rechtsklick auf den Sitzchip („Sitz sperren" / „Sitz freigeben").
- Funktioniert für Solo und Tafel (über die Owner-Logik).

## Nicht-Ziele

- Globale Sperr-Regeln („immer Sitz 0" o.ä.).
- Sperr-Gründe (Notiz, Symbol).

---

## Sektion 1 — Datenmodell

`GuestTable` bekommt:
```swift
var disabledSeatIndicesData: Data?    // Codable-Set<Int>
```

Computed Property:
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
```

Schema V5 (gemeinsam mit C) inkludiert das Feld als optional `Data?` → lightweight migration.

## Sektion 2 — Capacity & Logik

`GuestTable` bekommt zusätzlich:
```swift
func effectiveCapacity(rules: SeatingRules) -> Int {
    capacity(rules: rules) - disabledSeatIndices.count
}

var effectiveCapacity: Int {
    effectiveCapacity(rules: GuestTable.activeRules)
}
```

`isFull` aktualisiert: `guests.count >= effectiveCapacity`.

Capacity-Anzeige in TableCanvasItemView nutzt `effectiveCapacity` statt `capacity`. Tafel-Capacity in `capacityLabel`: `Tafel-Capacity − Σ disabledSeatIndices.count` über alle Group-Tische.

## Sektion 3 — UI: Sperren via Sitzchip

`SeatChipView` bekommt zusätzlich:
- `isDisabled: Bool` (von außen reingegeben)
- `onToggleDisabled: () -> Void`

Render-Anpassung:
- `isDisabled`: stark gedämpft (~30% Opacity), durchgestrichener Kreis (Linie diagonal durch), kein Drop-Target (`.dropDestination` skip wenn disabled), kein Drag-Source.

Kontext-Menü-Eintrag:
```swift
Button {
    onToggleDisabled()
} label: {
    Label(isDisabled ? "Sitz aktivieren" : "Sitz sperren", systemImage: isDisabled ? "checkmark.circle" : "xmark.circle")
}
```

Aufrufer in `TableCanvasItemView.seatChipsLayer`:
- Solo: nutzt `table.disabledSeatIndices.contains(idx)`.
- Tafel: `targetTable.disabledSeatIndices.contains(localSeatIndex)` (über Owner-Mapping).

Der Toggle-Handler:
- Solo: `table.disabledSeatIndices.toggle(idx)`.
- Tafel: gleiche Logik auf den Member-Tisch.

## Sektion 4 — Tests

`SeatDisableTests`:
- `disabledSeatIndices` Roundtrip: setzen, neu laden, Wert da.
- `effectiveCapacity`: 6 Sitze, 2 disabled → 4.
- `isFull`: 6 Sitze, 2 disabled, 4 Gäste → full.
- Tafel: 16 Sitze, 2 disabled auf Owner → tafel-effectiveCapacity 14.

## Erfolgs-Kriterien

- Rechtsklick auf Sitzchip → „Sitz sperren" → Sitz wird grau/durchgestrichen, kein Drop möglich.
- Capacity-Anzeige zeigt 4/6 statt 4/6 für deaktivierte (z.B. „0/4" wenn 6-Sitz-Tisch mit 2 deaktivierten Sitzen).
- Tafel-Capacity berücksichtigt deaktivierte Sitze über alle Member.
- Änderung persistent über App-Restart.
