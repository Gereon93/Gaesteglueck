# Gästeglück v2 — Design Spec

## Zusammenfassung

Wedding Seating Planner als macOS SwiftUI App. Importiert Gästelisten aus CSV/Excel, nutzt lokales LLM (LM Studio / Gemma 4) zum Parsen unstrukturierter Daten und für intelligente Tischgruppen-Vorschläge. Multi-Tag Beziehungssystem statt starrer Kategorien. Raumplan-Canvas mit KI-Chat für iteratives Optimieren.

**Plattform:** macOS 15+ (SwiftUI, SwiftData)
**KI:** LM Studio lokal (OpenAI-kompatible API, default `localhost:1234`)
**Zielgruppe:** Hochzeitsplaner (perspektivisch iPad App mit On-Device LLM)

---

## 1. Event-Modell

### Event

| Feld | Typ | Beschreibung |
|------|-----|-------------|
| id | UUID | Primary Key |
| name | String | z.B. "Hochzeit Bob & Alice" |
| date | Date | Hochzeitsdatum |
| location | String | Venue-Name |
| partner1Name | String | Frei wählbar, z.B. "Bob" |
| partner2Name | String | Frei wählbar, z.B. "Alice" |
| partner1PreMarriageName | String | Nachname vor Hochzeit (für Import-Matching) |
| partner2PreMarriageName | String | Nachname vor Hochzeit |
| menuOptions | [String] | Verfügbare Essensoptionen: ["Fleisch", "Vegetarisch", "Vegan"] |
| roomWidth | Double? | Raumbreite in cm |
| roomLength | Double? | Raumlänge in cm |
| roomPlanImage | Data? | Grundriss-Foto |

### Backlog: Multi-Event Support
- Datenstruktur unterstützt mehrere Events von Anfang an (alle Modelle haben Event-Referenz)
- UI zeigt vorerst nur ein Event (kein Event-Switcher)
- Backlog-Task: Event-Liste, Event-Auswahl, Event-Erstellung

---

## 2. Gäste-Modell

### Guest

| Feld | Typ | Beschreibung |
|------|-----|-------------|
| id | UUID | Primary Key |
| event | Event | Zugehöriges Event |
| firstName | String | Vorname |
| lastName | String | Nachname |
| partnerAssignment | PartnerAssignment | `.partner1`, `.partner2`, `.both` |
| ageCategory | AgeCategory | `.adult`, `.child`, `.toddler`, `.baby` |
| age | Int? | Optionales konkretes Alter |
| dietaryChoice | String | Gewähltes Menü ("Fleisch", "Vegetarisch", "Vegan") |
| intolerances | [String] | Unverträglichkeiten: ["Weizen", "Laktose", ...] |
| funFact | String? | Fun Fact für Tischkarten |
| notes | String? | Anmerkungen |
| employer | String? | Arbeitgeber (optional, für KI-Matching) |
| profession | String? | Beruf (optional) |
| hobbies | [String] | Hobby-Tags (optional) |
| languages | [String] | Gesprochene Sprachen (optional) |
| registrationGroup | UUID | Gemeinsame ID für alle Gäste einer Anmeldung |
| tableAssignment | GuestTable? | Zugewiesener Tisch |
| isPinned | Bool | Fixiert am zugewiesenen Tisch |

### PartnerAssignment (Enum)
- `.partner1` — Gast gehört zu Partner 1 (z.B. Bobs Verwandtschaft)
- `.partner2` — Gast gehört zu Partner 2 (z.B. Alices Studienfreunde)
- `.both` — Gast gehört zu beiden (gemeinsame Freunde)

### AgeCategory (Enum)
- `.adult` — Erwachsener (default)
- `.child` — Kind (ca. 4-14)
- `.toddler` — Kleinkind (1-3)
- `.baby` — Baby (0-1, braucht keinen Sitzplatz, aber Eltern brauchen Platz)

---

## 3. Beziehungs- & Tag-System

### Tag

| Feld | Typ | Beschreibung |
|------|-----|-------------|
| id | UUID | Primary Key |
| event | Event | Zugehöriges Event |
| name | String | z.B. "Studienfreunde Alice", "JGA Bob" |
| category | TagCategory | Gruppierungstyp |
| color | String | Hex-Farbe für UI-Darstellung |
| partnerAssignment | PartnerAssignment? | Optional: gehört dieser Tag zu P1/P2/Beide |

### TagCategory (Enum)
- `.family` — Familienzugehörigkeit (Eltern, Geschwister, Onkel/Tante, Cousin/e, Großeltern)
- `.friendGroup` — Freundesgruppe (Studienfreunde, Schulfreunde, WG, Nachbarn)
- `.role` — Rolle in der Hochzeit (Trauzeuge, Brautjungfer, Blumenkind)
- `.activity` — Gemeinsame Aktivität (JGA, Stammtisch)
- `.work` — Arbeitskontext (Siemens-Kollegen, Team X)
- `.custom` — Frei definiert

### GuestTag (Zuordnungstabelle)

| Feld | Typ | Beschreibung |
|------|-----|-------------|
| guest | Guest | Referenz |
| tag | Tag | Referenz |

Ein Gast kann beliebig viele Tags haben. Ein Tag kann beliebig viele Gäste haben.

### FamilyRole (Optional pro Guest)

| Feld | Typ | Beschreibung |
|------|-----|-------------|
| guest | Guest | Referenz |
| role | FamilyRoleType | Elternteil, Geschwister, Onkel, Tante, Cousin, Cousine, Großeltern, Neffe, Nichte |
| relativeToPartner | PartnerAssignment | Verwandt mit P1 oder P2 |

### Constraint (Harte Regeln)

| Feld | Typ | Beschreibung |
|------|-----|-------------|
| id | UUID | Primary Key |
| event | Event | Zugehöriges Event |
| type | ConstraintType | `.mustSitTogether`, `.mustNotSitTogether`, `.mustSitNear` |
| guests | [Guest] | Betroffene Gäste |
| reason | String? | Begründung |

Constraints ersetzen die alte `Relationship`-Tabelle für harte Regeln. Tags + KI übernehmen die weichen Präferenzen.

---

## 4. Tisch-Modell

### GuestTable

| Feld | Typ | Beschreibung |
|------|-----|-------------|
| id | UUID | Primary Key |
| event | Event | Zugehöriges Event |
| name | String | "Tisch 1", "Braut-Tafel", "Kindertisch" |
| shape | TableShape | `.round`, `.rectangular`, `.square` |
| width | Double | Breite in cm |
| length | Double | Länge in cm (bei rund = Durchmesser) |
| capacity | Int | Berechnete Sitzplätze (60cm pro Person) |
| positionX | Double | X-Position auf Canvas |
| positionY | Double | Y-Position auf Canvas |
| rotation | Double | Rotation in Grad |
| isChildTable | Bool | Kindertisch-Markierung |
| combinationGroup | UUID? | Gemeinsame ID für kombinierte Tische (Tafel, U-Form) |
| combinationRole | CombinationRole? | `.head`, `.middle`, `.end`, `.corner` — Position in der Kombination |

### TableShape (Enum)
- `.round` — Runder Tisch
- `.rectangular` — Rechteckiger Tisch
- `.square` — Quadratischer Tisch

### TableInventory (Event-Level)

Definiert welche Tische dem Venue zur Verfügung stehen (unabhängig von Platzierung):

| Feld | Typ | Beschreibung |
|------|-----|-------------|
| event | Event | Zugehöriges Event |
| shape | TableShape | Form |
| width | Double | Breite cm |
| length | Double | Länge cm |
| availableCount | Int | Wie viele davon verfügbar |

### Tisch-Konfigurationen

Tische können kombiniert werden:
- **Tafel:** 2+ rechteckige Tische aneinandergereiht (Längsseite)
- **U-Form:** 3+ Tische in U-Aufstellung
- **L-Form:** 2+ Tische im Winkel
- **Schiff:** Rechteckig + Rund als Kombination

Die Kombination wird über `combinedWith`-Referenzen modelliert. Die UI zeigt kombinierte Tische als eine Einheit auf dem Canvas.

---

## 5. Import-System

### Import-Flow

```
CSV/Excel Datei → Rohdaten laden
    → LLM parst jede Zeile → strukturierte Gäste-Vorschläge
        → User bestätigt/korrigiert pro Anmeldung
            → Gäste in Datenbank
```

### Import ist wiederholbar

- Anmeldefrist läuft noch — neue Anmeldungen kommen nach
- Import mergt mit bestehenden Gästen (Duplikat-Erkennung über Vor+Nachname)
- Neue Gäste werden hinzugefügt, bestehende nicht überschrieben
- UI zeigt: "3 neue Anmeldungen, 2 bereits bekannt (übersprungen)"

### LLM-Parsing

Jede Zeile aus der Gäste-Spalte wird dem LLM übergeben mit dem Prompt:

```
Extrahiere aus dieser Anmeldung alle einzelnen Gäste.
Pro Gast: Vorname, Nachname (falls vorhanden), Essenswahl, Unverträglichkeiten, ob Kind oder Erwachsener.

Familienname der Anmeldung: "{familienname}"
Anzahl Gäste: {anzahl}
Gäste-Details: "{freitext}"
Fun Facts: "{funfacts}"

Antworte als JSON-Array.
```

Beispiel-Input: `"Peter, Fleisch, Marlene, Fleisch, Johannes, Fleisch, Lorenz, Fleisch, Kind, Rebecca, Fleisch oder nur Beilage, Kind"`
Familienname: "Sommer", Anzahl: 5

Erwarteter LLM-Output:
```json
[
  {"firstName": "Peter", "lastName": "Sommer", "dietary": "Fleisch", "isChild": false},
  {"firstName": "Marlene", "lastName": "Sommer", "dietary": "Fleisch", "isChild": false},
  {"firstName": "Johannes", "lastName": "Sommer", "dietary": "Fleisch", "isChild": true},
  {"firstName": "Lorenz", "lastName": "Sommer", "dietary": "Fleisch", "isChild": true},
  {"firstName": "Rebecca", "lastName": "Sommer", "dietary": "Fleisch/Beilage", "isChild": true}
]
```

### Import-Preview UI

Pro Anmeldungszeile zeigt die App:
- Original-Freitext (oben, ausgegraut)
- LLM-Vorschlag als editierbare Gäste-Karten (unten)
- Buttons: "Übernehmen", "Korrigieren", "Überspringen"
- Batch-Actions: "Alle übernehmen" (wenn alles passt)

### Fallback ohne KI

Wenn LM Studio nicht verfügbar: Regex-basierter Parser als Fallback (wie im bestehenden Code). Weniger genau, aber funktioniert für einfache Fälle. User korrigiert den Rest manuell.

---

## 6. Gäste-Anreicherung & Gruppierung

### Flow: Wizard-artig

Nach dem Import führt ein Wizard durch die Anreicherung:

**Schritt 1: Partner-Zuordnung**
- Pro Anmeldungsgruppe: "Gehört zu {Partner1}, {Partner2} oder beiden?"
- KI kann vorschlagen basierend auf Nachname-Matching mit Partner-Nachnamen

**Schritt 2: Familienrollen**
- "Ist das Familie? Welche Rolle?"
- Onkel/Tante, Cousin/Cousine, Eltern, Geschwister, Großeltern, Neffe/Nichte
- Automatisch: Familienrolle impliziert `partnerAssignment`

**Schritt 3: Tags vergeben**
- Freie Tags erstellen oder bestehende zuweisen
- Mehrere Tags pro Gast möglich
- Vorgeschlagene Starter-Tags: Studienfreunde, Schulfreunde, Arbeitskollegen, JGA, Nachbarn
- On-the-fly neue Tags tippen

**Schritt 4: Optionale Details**
- Altersgruppe, Arbeitgeber, Hobbys
- Nicht als Pflichtfelder — wird nur abgefragt wenn User will
- "Möchtest du weitere Details ergänzen für bessere KI-Vorschläge?"

### Gruppen-View

Neben dem Wizard gibt es eine Tag-basierte Gruppenansicht:
- Links: Liste aller Tags mit Gästeanzahl
- Rechts: Gäste in der ausgewählten Gruppe
- Drag & Drop: Gäste zwischen Gruppen verschieben
- Inline-Editing: Tag direkt umbenennen, Farbe ändern

---

## 7. KI-gestützte Tischplanung

### Zwei-Phasen-Ansatz

#### Phase A: Wizard — Cluster-Erkennung & Vorschläge

Strukturierter Dialog, KI führt:

1. **Cluster-Erkennung:**
   KI analysiert alle Tags und Beziehungen, präsentiert gefundene Gruppen:
   > "Ich sehe folgende natürliche Gruppen:
   > - Alices Studienfreunde (12 Personen)
   > - Familie Falkenberg (8 Personen, 3 Anmeldungen)
   > - Bobs WG-Mitbewohner (4 Personen)
   > - ..."

2. **Harmonie-Vorschläge:**
   KI schlägt vor welche Gruppen zusammen passen könnten:
   > "Alices Studienfreunde + Chef von Siemens: gemeinsamer Arbeitskontext.
   > Bobs WG + Alices Studienfreunde: ähnliches Alter, könnten passen.
   > Was meint ihr — kennen sich die?"

3. **User bestätigt/korrigiert:**
   - "Ja, passt"
   - "Nein, lieber getrennt"
   - "Die kennen sich flüchtig, ist okay"

4. **Kindertisch-Vorschlag:**
   > "14 Kinder: Vorschlag Kindertisch mit 10 Plätzen + 2 Elternpaare als Aufsicht.
   > Familie Sommer hat 3 Kinder, Familie Schubert 3 — die könnten den Kern bilden.
   > 4 weitere Kinder sind unter 3 → besser bei Eltern lassen."

5. **Tisch-Konfiguration:**
   > "Bei 76 Erwachsenen + 10 Kindern am Kindertisch empfehle ich:
   > - 1 Braut-Tafel (2x Rechteckig = 16 Plätze): Trauzeugen, engste Familie
   > - 6 Runde Tische (je 10): Hauptgruppen
   > - 1 Kindertisch (Rechteckig, 12 Plätze)
   > Das ergibt 88 Plätze für 86 Sitzgäste."

6. **Erster Tischplan:**
   Nach Bestätigung aller Cluster → KI erstellt konkreten Vorschlag wer an welchem Tisch sitzt.

#### Phase B: Raumplan + Chat — Iteratives Optimieren

Nach dem Wizard-Durchlauf wechselt die UI zum Raumplan-Canvas mit Chat-Panel:

- **Canvas:** Tische mit zugewiesenen Gästen visuell auf dem Raumplan
- **Chat:** Freier Dialog mit KI für Anpassungen
  - "Tausch Tisch 3 und 5"
  - "Onkel Karl muss weg von Tante Helga"
  - "Gibt es noch jemanden der zu Tisch 7 passen könnte?"
  - KI antwortet mit Begründung und Konsequenzen des Tausches

### LLM-Kontext

Für jeden KI-Aufruf wird ein strukturierter Kontext mitgegeben:
- Alle Gäste mit Tags, Beziehungen, Dietary, Alter
- Alle Constraints (mustSitTogether, mustNotSitTogether)
- Tisch-Inventar und Raumgröße
- Bisherige Entscheidungen aus dem Wizard
- Chat-Historie (für Kontext in Phase B)

### Prompt-Strategie

Das LLM bekommt eine System-Prompt als Hochzeitsplaner-Berater:

```
Du bist ein erfahrener Hochzeitsplaner-Assistent. Du analysierst Gästelisten 
und schlägst optimale Sitzordnungen vor.

Deine Aufgabe:
- Erkenne soziale Gruppen und Verbindungen
- Schlage Tischkombinationen vor mit Begründung
- Identifiziere Brücken-Personen zwischen Gruppen
- Warne vor potenziellen Konflikten
- Berücksichtige Unverträglichkeiten/Allergien bei der Tischplanung
- Schlage Kindertisch-Konfiguration vor

Antworte auf Deutsch. Sei konkret und nenne Namen.
```

---

## 8. Raumplan & Canvas

### Drei-Panel Layout

**Links:** Gäste-Inbox
- Unzugewiesene Gäste, gruppiert nach Tags
- Kollabierbare Gruppen mit Gästeanzahl
- Drag & Drop auf Canvas-Tische

**Mitte:** Canvas
- Raumplan-Hintergrund (Foto oder leeres Raster mit Maßen)
- Tische als interaktive Objekte (Drag, Rotate, Resize)
- Tisch-Kombination: zwei Tische aufeinander ziehen → Tafel/U-Form Menü
- Gäste an Tischen als kleine Avatare/Punkte
- Farbkodierung: Dietary (grün=Vegan, orange=Vegetarisch), Allergien (rot blinkend)
- Kapazitätsanzeige pro Tisch: "8/10"
- Collision-Detection: Warnung wenn Tische zu eng stehen

**Rechts:** KI-Chat Panel (Phase B)
- Chat-Verlauf mit KI
- Input-Feld
- Verbindungsstatus zu LM Studio
- Quick-Actions: "Optimieren", "Probleme prüfen", "Zusammenfassung"

### Allergien & Unverträglichkeiten

Unverträglichkeiten sind **immer sichtbar** auf dem Canvas:
- Roter Punkt/Badge am Gast-Avatar
- Tooltip zeigt Details
- Tisch mit Allergikern hat orangenen Rand
- Separater "Allergien-Report" exportierbar

---

## 9. Export

### PDF-Export für Caterer
- Tischliste mit allen Gästen pro Tisch
- Essenswahl pro Gast
- **Allergien/Unverträglichkeiten prominent** (eigene Spalte, farbig hervorgehoben)
- Zusammenfassung: X Fleisch, Y Vegetarisch, Z Vegan, Sonderwünsche

### Tischkarten-Export
- Pro Gast: Name + Fun Fact
- Formatiert zum Ausdrucken

### Backlog: Weitere Exports
- Gesamt-Übersicht als Poster/Plakat
- Digitale Tischkarten mit QR-Code

---

## 10. KI-Anbindung (LM Studio)

### Architektur

```
App → LMStudioClient → HTTP POST localhost:1234/v1/chat/completions
                         (OpenAI-kompatible API)
```

### LMStudioClient

| Methode | Beschreibung |
|---------|-------------|
| `checkConnection()` | Prüft ob LM Studio erreichbar ist |
| `listModels()` | Zeigt verfügbare Modelle |
| `parseGuestRow(context:)` | Parst eine Anmeldungszeile → strukturierte Gäste |
| `analyzeGroups(guests:tags:)` | Cluster-Erkennung und Harmonie-Check |
| `suggestSeating(context:)` | Tischgruppen-Vorschlag mit Begründung |
| `chat(messages:context:)` | Freier Chat mit Kontext (Phase B) |

### Konfiguration

| Setting | Default | Beschreibung |
|---------|---------|-------------|
| endpoint | `http://localhost:1234` | LM Studio URL |
| model | Auto-detect | Erstes verfügbares Modell |
| temperature | 0.3 | Niedrig für konsistente Ergebnisse |
| maxTokens | 4096 | Ausreichend für Antworten |

### Empfohlenes Modell
- **Gemma 4 12B** — läuft gut auf 32GB RAM Mac Mini
- Alternativ: jedes Modell das LM Studio laden kann

### Fallback ohne KI
- Import: Regex-basierter Parser (weniger genau)
- Tischplanung: Algorithmischer Optimierer (Simulated Annealing, wie in v1)
- Kein Chat, aber manuelle Drag & Drop Zuweisung funktioniert

---

## 11. UI-Architektur

### Navigation (macOS Sidebar)

1. **Dashboard** — Event-Übersicht, Statistiken, Workflow-Fortschritt
2. **Gäste** — Gästeliste, Import, Detail-Bearbeitung
3. **Tische & Raum** — Tisch-Inventar, Raumplan-Canvas
4. **Beziehungen** — Tags, Gruppen, Constraints
5. **KI-Assistent** — Wizard + Chat
6. **Einstellungen** — LM Studio Verbindung, Event-Daten, Export-Optionen

### Screen-Flow

```
App Start
  → Dashboard (Übersicht, nächster Schritt)
  
Event Setup (Einstellungen)
  → Partner-Namen, Datum, Menü, Raum, Tisch-Inventar

Import (Gäste)
  → Datei wählen → LLM parst → Preview → Bestätigen
  → Wiederholbar (neue Anmeldungen)

Anreichern (Beziehungen)  
  → Wizard: Partner-Zuordnung → Familienrollen → Tags → Details
  → Gruppen-View für Überblick und Korrekturen

KI-Planung (KI-Assistent)
  → Wizard Phase A: Cluster → Harmonie → Kindertisch → Konfiguration → Erster Plan
  → Übergang zu Phase B

Raumplan (Tische & Raum)
  → Canvas + Chat Panel (Phase B)
  → Iteratives Optimieren bis zufrieden

Export (Dashboard oder Einstellungen)
  → PDF für Caterer, Tischkarten
```

---

## 12. Tech-Stack

| Komponente | Technologie |
|-----------|-------------|
| UI | SwiftUI (macOS 15+) |
| Persistenz | SwiftData |
| File-Import | CoreXLSX (Excel), eigener CSV-Parser |
| LLM | LM Studio REST API (OpenAI-kompatibel) |
| PDF | PDFKit |
| Canvas | SwiftUI Canvas + Drag & Drop |

### Backlog: iPad/iOS

| Feature | Notiz |
|---------|-------|
| iOS Target | Braucht Apple Developer Account (100 EUR) |
| On-Device LLM | CoreML/MLX auf M-Chip iPads |
| Multi-Event UI | Event-Liste, Event-Switcher |
| iCloud Sync | SwiftData + CloudKit |
| Landscape/Portrait | Adaptive Layouts |
| LM Studio über Netzwerk | iPad → Mac Mini LM Studio als Zwischenlösung |

---

## 13. Abgrenzung (Was wir NICHT bauen)

- Kein Cloud-Backend, kein Account-System
- Keine Google Sheets API-Integration (CSV/Excel Export reicht)
- Kein Real-Time Collaboration
- Keine automatische Namenserkennung aus Fotos
- Kein Einladungs-Management (nur Sitzplanung)
