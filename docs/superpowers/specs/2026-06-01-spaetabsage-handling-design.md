# Spätabsage-Handling (Late Cancellation)

**Datum:** 2026-06-01
**Status:** Genehmigt, in Umsetzung

## Problem

Gäste, die zugesagt **und eingeplant** waren und dann absagen, brauchen eine
Sonderbehandlung. Aktuell sind RSVP-Status und Sitzplan komplett unabhängig:
setzt man jemanden auf *Abgesagt*, bleibt die Person am Tisch sitzen, zählt
weiter in Belegung und Caterer-Übersicht mit, und der frei gewordene Platz ist
unsichtbar. Eine Spätabsage hinterlässt also ein „Loch" im Plan, das die App
nicht bemerkt — und der Caterer bekommt eine falsche Zahl.

## Kernidee — abgeleiteter Zustand, kein neuer Status

Eine **Spätabsage** ist kein eigener `RSVPStatus`, sondern abgeleitet:

> `rsvpStatus == .declined && table != nil`

Eine normale Absage von Anfang an hatte nie einen Sitz (`table == nil`) und ist
damit automatisch unterscheidbar. Setzt man eine **zugesagte, eingeplante**
Person auf *Abgesagt* (`applyRSVP(.declined)`), wird der **Sitz freigegeben**
(`seatIndex = nil`, sofort neu vergebbar), aber die **Tisch-Zuordnung bleibt** als
Vermerk erhalten. Die Person zählt ab sofort nirgends mehr mit; der Wegfall
bleibt für Tisch-Badge und Caterer sichtbar. Eine nie zugesagte Person, die
abgesagt wird, verliert die Tisch-Zuordnung ganz (keine späte Absage). Kein
zusätzliches gespeichertes Feld, keine Status-Historie, kein vierter
Picker-Eintrag.

## Komponenten

### 1. Datenmodell (`Guest`, `GuestTable`)

- `Guest.isLateCancellation: Bool` — abgeleitet (`declined && table != nil`).
- `Guest.countsForSeating: Bool` — `rsvpStatus == .confirmed` (zentrale Regel,
  damit Belegung/Caterer/Optimizer konsistent filtern; Ausstehend/Abgesagt
  zählen nicht).
- `Guest.applyRSVP(_:)` — kapselt die Statuswechsel: Zusage→Absage gibt den Sitz
  frei (Tisch bleibt), Absage→Zusage löst die Zuordnung zurück in die Inbox,
  alles-außer-Zusage hält keinen Sitz.
- `GuestTable.attendingGuests: [Guest]` — Gäste mit `countsForSeating == true`.
- `GuestTable.ghostGuests: [Guest]` — abgesagte, deren Tisch-Vermerk noch hängt.
- `remainingSeats`, `isFull` und Kapazitäts-Checks zählen `attendingGuests`
  statt `guests` (heutiges Verhalten zählt alle inkl. Abgesagte — das ist der
  Bug, der das „Loch" unsichtbar macht).

### 2. Späte Absage am Tisch (nur Bearbeitungsansicht)

- Kein sitzgebundener Geister-Sitz mehr: Der Platz wird mit der Absage frei
  (`seatIndex = nil`) und ist sofort wieder regulär belegbar.
- Stattdessen eine **Tisch-Badge „N abgemeldet"** (`TableCanvasItemView`) neben
  Belegung/Allergie, Tooltip mit Namen — die Spur hängt an `table.ghostGuests`.

### 3. Sammel-Hinweis

- Banner oben im Sitzplan: „N späte Absagen" (abgeleitet aus `ghostGuests` über
  alle Tische). Rein informativ, leer ⇒ unsichtbar; verweist auf den
  Caterer-Export für den Wegfall.

### 4. Caterer-Übersicht (Auto-Korrektur + Änderungs-Notiz)

- Alle Zählungen (Diät, Altersgruppen, Summen, Unverträglichkeiten-Liste)
  filtern Abgesagte aus → Zahlen stimmen automatisch. (Heute: `tables.flatMap(\.guests)`
  zählt alle → muss auf `attendingGuests` umgestellt werden.)
- Neue Sektion **„Änderungen / Absagen"**: pro Geist eine Zeile
  `Name · Tisch · Diät (falls ≠ Fleisch) · Unverträglichkeiten`. Damit kann man
  der Location gezielt melden: „Tisch 3: −1 Vegetarisch, −1 Nuss-Allergie".
- Gilt für PDF-Export **und** die Caterer-Vorschau in `ExportView`.

### 5. Optimizer / Auto-Place

- `SeatingOptimizer` überspringt Abgesagte: sie werden nicht (neu) platziert und
  belegen keine Kapazität. Geister-Sitze blockieren keine Optimierung.

### 6. Finaler Export ohne Geister

- Tischkarten, Bildlicher Sitzplan, PNG, Tischlisten zeigen Abgesagte **nicht**
  (nur die Caterer-Änderungs-Notiz aus 4 listet sie bewusst auf).

## Datenfluss

```
Status → Abgesagt (bei gesetztem table)
   └─→ isLateCancellation == true
        ├─ Belegung/Optimizer/Statistik:  ignoriert (attendingGuests)
        ├─ Sitzplan (Edit):               Geister-Sitz + Banner-Zähler
        ├─ Caterer-Übersicht:             aus Zahlen raus + in Änderungs-Liste
        └─ Finaler Export:                unsichtbar
   ── Aktion „Platz freigeben" → table=nil → normale Absage (kein Geist mehr)
   ── Aktion „nachrücken"       → neuer Gast auf seatIndex, Geist table=nil
   ── Re-Zusage (declined→confirmed): zählt automatisch wieder mit
```

## Fehlerfälle / Edge Cases

- Abgesagter Gast ohne Sitz (`table == nil`): normale Absage, **kein** Geist,
  nicht in der Änderungs-Liste.
- Tisch gelöscht während Geist drauf: Geist-Gast `table = nil` → normale Absage.
- Mehrere Geister an einem Tisch: alle gezeigt, Banner summiert.
- Re-Zusage: kein Reset nötig, Ableitung greift automatisch.

## Tests

- `isLateCancellation` / `countsForSeating` Ableitung.
- `attendingGuests` / Belegung schließt Abgesagte aus; `isFull`/`remainingSeats`.
- Caterer-Zählung ohne Abgesagte; Änderungs-Liste = Geister.
- Optimizer platziert/zählt Abgesagte nicht.
- Finaler Export (Tischkarten/Bildlich) ohne Abgesagte.

## Bewusst draußen (YAGNI)

Kein vierter Status, keine separate Spätabsagen-Liste/Sheet, keine
Status-Historie/Timestamps, keine automatische Caterer-Benachrichtigung.
